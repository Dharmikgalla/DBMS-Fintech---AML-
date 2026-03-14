/**
 * FinGuard National Bank — Express Backend
 * Connects to MySQL finguard_bank database.
 * Run: npm install && node server.js
 * MySQL must be running with schema from bank_oltp_schema.sql
 */

const express = require('express');
const mysql   = require('mysql2/promise');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const cors    = require('cors');

const app = express();
app.use(express.json());
app.use(cors());
app.use(express.static('public'));  // serves the frontend HTML

const JWT_SECRET = process.env.JWT_SECRET || 'finguard_secret_2024_change_in_prod';

// ─── DB POOL ───────────────────────────────────────────────────
const pool = mysql.createPool({
  host:     process.env.DB_HOST     || 'localhost',
  user:     process.env.DB_USER     || 'root',
  password: process.env.DB_PASS     || '',
  database: process.env.DB_NAME     || 'finguard_bank',
  waitForConnections: true,
  connectionLimit: 10,
});

// ─── AUTH MIDDLEWARE ────────────────────────────────────────────
function auth(req, res, next) {
  const token = (req.headers.authorization||'').replace('Bearer ','');
  if (!token) return res.status(401).json({ error: 'No token' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch { res.status(401).json({ error: 'Invalid token' }); }
}

function managerOnly(req, res, next) {
  if (!['BRANCH_MANAGER','COMPLIANCE_OFFICER','AML_ANALYST'].includes(req.user.role))
    return res.status(403).json({ error: 'Manager access required' });
  next();
}

// ─── AUTH ROUTES ────────────────────────────────────────────────

// POST /api/login  { id, password, role: 'customer'|'employee' }
app.post('/api/login', async (req, res) => {
  const { id, password, role } = req.body;
  const conn = await pool.getConnection();
  try {
    let row;
    if (role === 'customer') {
      const [rows] = await conn.execute(
        'SELECT customer_id AS id, full_name AS name, password_hash, branch_id, risk_score, is_flagged FROM Customer WHERE customer_id = ?',
        [id]
      );
      row = rows[0];
      if (!row || !(await bcrypt.compare(password, row.password_hash)))
        return res.status(401).json({ error: 'Invalid credentials' });
      const token = jwt.sign({ id: row.id, name: row.name, role: 'CUSTOMER', type: 'customer' }, JWT_SECRET, { expiresIn: '8h' });
      return res.json({ token, user: { id: row.id, name: row.name, role: 'CUSTOMER', type: 'customer', risk_score: row.risk_score, is_flagged: row.is_flagged } });
    } else {
      const [rows] = await conn.execute(
        'SELECT employee_id AS id, name, password_hash, role, branch_id FROM Employee WHERE employee_id = ?',
        [id]
      );
      row = rows[0];
      if (!row || !(await bcrypt.compare(password, row.password_hash)))
        return res.status(401).json({ error: 'Invalid credentials' });
      const token = jwt.sign({ id: row.id, name: row.name, role: row.role, type: 'employee', branch_id: row.branch_id }, JWT_SECRET, { expiresIn: '8h' });
      return res.json({ token, user: { id: row.id, name: row.name, role: row.role, type: 'employee', branch_id: row.branch_id } });
    }
  } finally { conn.release(); }
});

// ─── CUSTOMER ROUTES ────────────────────────────────────────────

// GET /api/customer/accounts
app.get('/api/customer/accounts', auth, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT a.account_id, a.account_type, a.balance, a.status, a.daily_limit, a.created_at,
            b.branch_name, b.IFSC_code
     FROM Account a JOIN Branch b ON a.branch_id = b.branch_id
     WHERE a.customer_id = ?`, [req.user.id]
  );
  res.json(rows);
});

// GET /api/customer/transactions
app.get('/api/customer/transactions', auth, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT t.transaction_id, t.from_account_id, t.to_account_id, t.amount,
            t.transaction_type, t.transaction_status, t.transaction_timestamp, t.remarks
     FROM Transaction t
     JOIN Account a ON (t.from_account_id = a.account_id OR t.to_account_id = a.account_id)
     WHERE a.customer_id = ?
     ORDER BY t.transaction_timestamp DESC LIMIT 50`, [req.user.id]
  );
  res.json(rows);
});

// POST /api/customer/transfer  { from_account_id, to_account_id, amount, type, remarks }
app.post('/api/customer/transfer', auth, async (req, res) => {
  const { from_account_id, to_account_id, amount, type, remarks } = req.body;
  if (!from_account_id || !to_account_id || !amount || amount <= 0)
    return res.status(400).json({ error: 'Invalid transfer parameters' });

  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    // Verify ownership
    const [own] = await conn.execute(
      'SELECT account_id, balance, status, daily_limit FROM Account WHERE account_id = ? AND customer_id = ?',
      [from_account_id, req.user.id]
    );
    if (!own[0]) { await conn.rollback(); return res.status(403).json({ error: 'Account not found or unauthorized' }); }
    if (own[0].status !== 'ACTIVE') { await conn.rollback(); return res.status(400).json({ error: `Account is ${own[0].status}` }); }
    if (own[0].balance < amount) { await conn.rollback(); return res.status(400).json({ error: 'Insufficient balance' }); }

    // Daily limit check
    const [dailyRows] = await conn.execute(
      `SELECT COALESCE(SUM(amount),0) AS daily_total FROM Transaction
       WHERE from_account_id = ? AND DATE(transaction_timestamp) = CURDATE()
       AND transaction_status IN ('COMPLETED','PENDING')`, [from_account_id]
    );
    if ((parseFloat(dailyRows[0].daily_total) + parseFloat(amount)) > own[0].daily_limit) {
      await conn.rollback();
      return res.status(400).json({ error: 'Daily transaction limit exceeded' });
    }

    // Insert transaction (PENDING — trigger will handle AML + balance)
    const [result] = await conn.execute(
      `INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type,
        transaction_status, remarks, ip_address)
       VALUES (?, ?, ?, ?, 'PENDING', ?, ?)`,
      [from_account_id, to_account_id, amount, type || 'TRANSFER', remarks || 'Fund transfer',
       req.connection?.remoteAddress || '127.0.0.1']
    );
    const txnId = result.insertId;

    // Update balances & complete
    await conn.execute('UPDATE Account SET balance = balance - ? WHERE account_id = ?', [amount, from_account_id]);
    await conn.execute('UPDATE Account SET balance = balance + ? WHERE account_id = ?', [amount, to_account_id]);
    await conn.execute("UPDATE Transaction SET transaction_status = 'COMPLETED' WHERE transaction_id = ?", [txnId]);

    // Run AML checks (stored procedure)
    await conn.execute('CALL sp_run_aml_checks(?)', [txnId]);

    // Check if blocked by AML
    const [txnCheck] = await conn.execute('SELECT transaction_status FROM Transaction WHERE transaction_id = ?', [txnId]);
    const finalStatus = txnCheck[0]?.transaction_status;

    if (finalStatus === 'BLOCKED') {
      // Reverse balances
      await conn.execute('UPDATE Account SET balance = balance + ? WHERE account_id = ?', [amount, from_account_id]);
      await conn.execute('UPDATE Account SET balance = balance - ? WHERE account_id = ?', [amount, to_account_id]);
    }

    // Check for new alerts
    const [alerts] = await conn.execute(
      'SELECT alert_type, severity, description FROM Alert WHERE transaction_id = ? ORDER BY alert_no DESC LIMIT 5', [txnId]
    );

    await conn.commit();
    res.json({ transaction_id: txnId, status: finalStatus, alerts, amount, blocked: finalStatus === 'BLOCKED' });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ─── MANAGER / EMPLOYEE ROUTES ──────────────────────────────────

// GET /api/manager/stats
app.get('/api/manager/stats', auth, managerOnly, async (req, res) => {
  const [[openAlerts]]    = await pool.execute("SELECT COUNT(*) AS c FROM Alert WHERE status='OPEN'");
  const [[critAlerts]]    = await pool.execute("SELECT COUNT(*) AS c FROM Alert WHERE status='OPEN' AND severity='CRITICAL'");
  const [[flaggedCusts]]  = await pool.execute("SELECT COUNT(*) AS c FROM Customer WHERE is_flagged=1");
  const [[blockedTxns]]   = await pool.execute("SELECT COUNT(*) AS c FROM Transaction WHERE transaction_status='BLOCKED'");
  const [[totalTxns]]     = await pool.execute("SELECT COUNT(*) AS c FROM Transaction");
  const [[totalCusts]]    = await pool.execute("SELECT COUNT(*) AS c FROM Customer");
  const [[totalAccs]]     = await pool.execute("SELECT COUNT(*) AS c FROM Account");
  res.json({
    open_alerts:   openAlerts.c,
    crit_alerts:   critAlerts.c,
    flagged_custs: flaggedCusts.c,
    blocked_txns:  blockedTxns.c,
    total_txns:    totalTxns.c,
    total_customers: totalCusts.c,
    total_accounts:  totalAccs.c,
  });
});

// GET /api/manager/alerts
app.get('/api/manager/alerts', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT al.*, c.full_name AS customer_name, c.PAN_number, c.risk_score,
            t.amount, t.transaction_type, t.transaction_timestamp
     FROM Alert al
     JOIN Customer c ON al.customer_id = c.customer_id
     LEFT JOIN Transaction t ON al.transaction_id = t.transaction_id
     ORDER BY FIELD(al.severity,'CRITICAL','HIGH','MEDIUM','LOW'), al.alert_timestamp DESC
     LIMIT 100`
  );
  res.json(rows);
});

// PATCH /api/manager/alerts/:id  { status }
app.patch('/api/manager/alerts/:id', auth, managerOnly, async (req, res) => {
  const { status } = req.body;
  await pool.execute(
    'UPDATE Alert SET status=?, assigned_to=? WHERE alert_no=?',
    [status, req.user.id, req.params.id]
  );
  res.json({ success: true });
});

// GET /api/manager/customers
app.get('/api/manager/customers', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT c.customer_id, c.full_name, c.email, c.phone, c.city, c.PAN_number,
            c.risk_score, c.is_flagged, c.created_at, b.branch_name,
            COUNT(DISTINCT a.account_id) AS account_count,
            COUNT(DISTINCT al.alert_no)  AS alert_count
     FROM Customer c
     LEFT JOIN Branch b  ON c.branch_id = b.branch_id
     LEFT JOIN Account a ON a.customer_id = c.customer_id
     LEFT JOIN Alert al  ON al.customer_id = c.customer_id
     GROUP BY c.customer_id ORDER BY c.risk_score DESC`
  );
  res.json(rows);
});

// GET /api/manager/customers/:id — full customer detail
app.get('/api/manager/customers/:id', auth, managerOnly, async (req, res) => {
  const [[cust]] = await pool.execute(
    `SELECT c.*, b.branch_name, b.IFSC_code FROM Customer c
     JOIN Branch b ON c.branch_id = b.branch_id WHERE c.customer_id=?`, [req.params.id]
  );
  if (!cust) return res.status(404).json({ error: 'Not found' });
  const [accounts] = await pool.execute('SELECT * FROM Account WHERE customer_id=?', [req.params.id]);
  const [alerts]   = await pool.execute('SELECT * FROM Alert WHERE customer_id=? ORDER BY alert_timestamp DESC LIMIT 20', [req.params.id]);
  const [txns]     = await pool.execute(
    `SELECT t.* FROM Transaction t JOIN Account a ON (t.from_account_id=a.account_id OR t.to_account_id=a.account_id)
     WHERE a.customer_id=? ORDER BY t.transaction_timestamp DESC LIMIT 30`, [req.params.id]
  );
  res.json({ customer: cust, accounts, alerts, transactions: txns });
});

// POST /api/manager/accounts  — CREATE new account for existing customer
app.post('/api/manager/accounts', auth, managerOnly, async (req, res) => {
  const { customer_id, account_type, initial_deposit, daily_limit } = req.body;
  if (!customer_id || !account_type)
    return res.status(400).json({ error: 'customer_id and account_type required' });

  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    // Verify customer exists
    const [[cust]] = await conn.execute('SELECT customer_id, branch_id FROM Customer WHERE customer_id=?', [customer_id]);
    if (!cust) { await conn.rollback(); return res.status(404).json({ error: 'Customer not found' }); }

    const [result] = await conn.execute(
      `INSERT INTO Account (customer_id, branch_id, account_type, balance, daily_limit, status)
       VALUES (?, ?, ?, ?, ?, 'ACTIVE')`,
      [customer_id, cust.branch_id, account_type, initial_deposit || 0, daily_limit || 200000]
    );
    const accId = result.insertId;

    // Log initial deposit as a transaction if > 0
    if (initial_deposit > 0) {
      await conn.execute(
        `INSERT INTO Transaction (to_account_id, amount, transaction_type, transaction_status, remarks)
         VALUES (?, ?, 'DEPOSIT', 'COMPLETED', 'Account opening deposit')`,
        [accId, initial_deposit]
      );
      // Log in audit
      await conn.execute(
        `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, new_values)
         VALUES ('Account','INSERT',?,?,?)`,
        [accId, req.user.id, JSON.stringify({ account_id: accId, customer_id, account_type, balance: initial_deposit })]
      );
    }

    await conn.commit();
    res.json({ success: true, account_id: accId, message: `Account ${accId} created successfully` });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// DELETE /api/manager/accounts/:id  — CLOSE / DELETE account
app.delete('/api/manager/accounts/:id', auth, managerOnly, async (req, res) => {
  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    const [[acc]] = await conn.execute(
      'SELECT * FROM Account WHERE account_id=?', [req.params.id]
    );
    if (!acc) { await conn.rollback(); return res.status(404).json({ error: 'Account not found' }); }
    if (acc.balance > 0) { await conn.rollback(); return res.status(400).json({ error: `Cannot close: balance of ₹${acc.balance} must be withdrawn first` }); }

    // Soft delete: mark as CLOSED
    await conn.execute("UPDATE Account SET status='CLOSED' WHERE account_id=?", [req.params.id]);

    // Audit log
    await conn.execute(
      `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, old_values, new_values)
       VALUES ('Account','UPDATE',?,?,?,?)`,
      [req.params.id, req.user.id,
       JSON.stringify({ status: acc.status }),
       JSON.stringify({ status: 'CLOSED', closed_by: req.user.id, closed_at: new Date().toISOString() })]
    );

    await conn.commit();
    res.json({ success: true, message: `Account ${req.params.id} closed successfully` });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// PATCH /api/manager/accounts/:id/freeze  — Freeze / Unfreeze
app.patch('/api/manager/accounts/:id/freeze', auth, managerOnly, async (req, res) => {
  const { action } = req.body;  // 'FREEZE' | 'UNFREEZE'
  const newStatus = action === 'FREEZE' ? 'FROZEN' : 'ACTIVE';
  await pool.execute('UPDATE Account SET status=? WHERE account_id=?', [newStatus, req.params.id]);
  res.json({ success: true, status: newStatus });
});

// POST /api/manager/customers  — CREATE new customer
app.post('/api/manager/customers', auth, managerOnly, async (req, res) => {
  const { full_name, email, phone, address, city, DOB, PAN_number, password, branch_id } = req.body;
  if (!full_name || !email || !PAN_number || !password)
    return res.status(400).json({ error: 'Required: full_name, email, PAN_number, password' });

  const password_hash = await bcrypt.hash(password, 12);
  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    const [result] = await conn.execute(
      `INSERT INTO Customer (branch_id, full_name, email, phone, address, city, DOB, PAN_number, password_hash)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [branch_id || req.user.branch_id, full_name, email, phone || '', address || '', city || '', DOB || '1990-01-01', PAN_number, password_hash]
    );
    await conn.commit();
    res.json({ success: true, customer_id: result.insertId });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Email or PAN already registered' });
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// GET /api/manager/transactions
app.get('/api/manager/transactions', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT t.*, af.account_type AS from_type, at.account_type AS to_type,
            cf.full_name AS from_customer, ct.full_name AS to_customer
     FROM Transaction t
     LEFT JOIN Account af ON t.from_account_id = af.account_id
     LEFT JOIN Account at ON t.to_account_id   = at.account_id
     LEFT JOIN Customer cf ON af.customer_id   = cf.customer_id
     LEFT JOIN Customer ct ON at.customer_id   = ct.customer_id
     ORDER BY t.transaction_timestamp DESC LIMIT 100`
  );
  res.json(rows);
});

// GET /api/manager/branches
app.get('/api/manager/branches', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute('SELECT branch_id, branch_name, IFSC_code, city, state FROM Branch ORDER BY branch_name');
  res.json(rows);
});

// GET /api/manager/audit-log
app.get('/api/manager/audit-log', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT l.*, e.name AS employee_name FROM Audit_Log l
     LEFT JOIN Employee e ON l.changed_by = e.employee_id
     ORDER BY l.logged_at DESC LIMIT 50`
  );
  res.json(rows);
});

// ─── START ──────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`FinGuard backend running on http://localhost:${PORT}`));
