require("dotenv").config();

const http    = require('http');
const path    = require('path');
const express = require('express');
const mysql   = require('mysql2/promise');
const bcrypt  = require('bcrypt');
const jwt     = require('jsonwebtoken');
const cors    = require('cors');

const app = express();
app.use(express.json());
app.use(cors());
app.use('/api', (req, res, next) => {
  res.set('Cache-Control', 'no-store, no-cache, must-revalidate');
  res.set('Pragma', 'no-cache');
  next();
});
app.use(express.static(path.join(__dirname, '../frontend/public')));

const JWT_SECRET = process.env.JWT_SECRET || 'finguard_secret_2024';

const pool = mysql.createPool({
  host:             process.env.DB_HOST || 'localhost',
  user:             process.env.DB_USER || 'root',
  password:         process.env.DB_PASS || '',
  database:         process.env.DB_NAME || 'finguard_bank',
  port:             parseInt(process.env.DB_PORT) || 3306,
  waitForConnections: true,
  connectionLimit:  10,
  decimalNumbers:   true,
});

function auth(req, res, next) {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try { req.user = jwt.verify(token, JWT_SECRET); next(); }
  catch { res.status(401).json({ error: 'Invalid or expired token' }); }
}

function managerOnly(req, res, next) {
  const allowed = ['BRANCH_MANAGER','COMPLIANCE_OFFICER','AML_ANALYST'];
  if (!allowed.includes(req.user.role))
    return res.status(403).json({ error: 'Manager access required' });
  next();
}

// ── LOGIN ─────────────────────────────────────────────────────────
// customer_id and employee_id are now alphanumeric strings (e.g. 'ananya92', 'arjun01')
app.post('/api/login', async (req, res) => {
  const { password, role } = req.body;
  const rawId = req.body.id;
  if (!rawId || !password || !role)
    return res.status(400).json({ error: 'id, password and role are required' });

  // Keep id as a plain string — IDs are now alphanumeric
  const id = String(rawId).trim();
  if (!id)
    return res.status(400).json({ error: 'id, password and role are required' });

  const conn = await pool.getConnection();
  try {
    if (role === 'customer') {
      const [rows] = await conn.execute(
        `SELECT c.customer_id AS id, c.full_name AS name, c.password_hash, c.branch_id, c.risk_score, c.is_flagged,
                c.PAN_number, b.branch_name
         FROM Customer c LEFT JOIN Branch b ON c.branch_id = b.branch_id
         WHERE c.customer_id = ?`, [id]
      );
      const row = rows[0];
      if (!row || !(await bcrypt.compare(password, row.password_hash)))
        return res.status(401).json({ error: 'Invalid credentials' });
      const token = jwt.sign({ id: row.id, name: row.name, role: 'CUSTOMER', type: 'customer' }, JWT_SECRET, { expiresIn: '8h' });
      return res.json({ token, user: { id: row.id, name: row.name, role: 'CUSTOMER', type: 'customer', risk_score: row.risk_score, is_flagged: row.is_flagged, PAN_number: row.PAN_number, branch_name: row.branch_name } });
    } else {
      const [rows] = await conn.execute(
        'SELECT employee_id AS id, name, password_hash, role, branch_id FROM Employee WHERE employee_id = ?', [id]
      );
      const row = rows[0];
      if (!row || !(await bcrypt.compare(password, row.password_hash)))
        return res.status(401).json({ error: 'Invalid credentials' });
      const token = jwt.sign({ id: row.id, name: row.name, role: row.role, type: 'employee', branch_id: row.branch_id }, JWT_SECRET, { expiresIn: '8h' });
      return res.json({ token, user: { id: row.id, name: row.name, role: row.role, type: 'employee', branch_id: row.branch_id } });
    }
  } finally { conn.release(); }
});

// ── CUSTOMER: ACCOUNTS ────────────────────────────────────────────
app.get('/api/customer/accounts', auth, async (req, res) => {
  const customerId = req.user.id; // string, e.g. 'ananya92'
  const [rows] = await pool.execute(
    `SELECT a.account_no, a.account_type, a.balance, a.status, a.daily_limit, a.created_at,
            b.branch_name, b.IFSC_code
     FROM Account a JOIN Branch b ON a.branch_id = b.branch_id
     WHERE a.customer_id = ? ORDER BY a.created_at DESC`, [customerId]
  );
  res.json(rows);
});

// ── CUSTOMER: TRANSACTIONS ────────────────────────────────────────
app.get('/api/customer/transactions', auth, async (req, res) => {
  const customerId = req.user.id; // string
  const [rows] = await pool.execute(
    `SELECT t.transaction_id, t.from_account_no, t.to_account_no,
            t.amount, t.transaction_type, t.transaction_status,
            t.transaction_timestamp, t.remarks
     FROM Transaction t
     WHERE EXISTS (
       SELECT 1 FROM Account a
       WHERE a.customer_id = ?
         AND (
           (t.from_account_no IS NOT NULL AND a.account_no = t.from_account_no)
           OR (t.to_account_no IS NOT NULL AND a.account_no = t.to_account_no)
         )
     )
     ORDER BY t.transaction_timestamp DESC LIMIT 100`,
    [customerId]
  );
  res.json(rows.map((r) => normalizeTxnRow(r)));
});

function normalizeTxnStatus(v) {
  if (v == null) return '';
  if (Buffer.isBuffer(v)) return v.toString('utf8').trim();
  return String(v).trim();
}

function normalizeTxnRow(row) {
  if (!row) return null;
  const ts = row.transaction_timestamp;
  return {
    transaction_id:    Number(row.transaction_id),
    from_account_no:   row.from_account_no != null ? Number(row.from_account_no) : null,
    to_account_no:     row.to_account_no   != null ? Number(row.to_account_no)   : null,
    amount:            Number(row.amount),
    transaction_type:  String(row.transaction_type || 'TRANSFER'),
    transaction_status: normalizeTxnStatus(row.transaction_status),
    transaction_timestamp: ts instanceof Date ? ts.toISOString() : ts,
    remarks: row.remarks || '',
  };
}

async function selectTransactionRow(poolOrConn, transactionId) {
  const [rows] = await poolOrConn.execute(
    `SELECT transaction_id, from_account_no, to_account_no, amount, transaction_type, transaction_status,
            transaction_timestamp, remarks
     FROM Transaction WHERE transaction_id = ?`,
    [transactionId]
  );
  return normalizeTxnRow(rows[0]) || null;
}

// ── CUSTOMER: TRANSFER ────────────────────────────────────────────
app.post('/api/customer/transfer', auth, async (req, res) => {
  const { from_account_no, to_account_no, amount, transaction_type, remarks } = req.body;
  if (!from_account_no || !to_account_no || !amount || amount <= 0)
    return res.status(400).json({ error: 'from_account_no, to_account_no and amount are required' });
  if (String(from_account_no) === String(to_account_no))
    return res.status(400).json({ error: 'Cannot transfer to the same account' });

  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    const customerId = req.user.id; // string

    // Verify ownership + get balance
    const [ownRows] = await conn.execute(
      'SELECT account_no, balance, status, daily_limit FROM Account WHERE account_no = ? AND customer_id = ?',
      [from_account_no, customerId]
    );
    const own = ownRows[0];
    if (!own) return (await conn.rollback(), res.status(403).json({ error: 'Account not found or does not belong to you' }));
    if (own.status !== 'ACTIVE') return (await conn.rollback(), res.status(400).json({ error: `Your account is ${own.status}` }));
    if (parseFloat(own.balance) < parseFloat(amount)) return (await conn.rollback(), res.status(400).json({ error: `Insufficient balance. Available: ₹${own.balance}` }));

    // Verify destination exists
    const [destRows] = await conn.execute('SELECT account_no, status FROM Account WHERE account_no = ?', [to_account_no]);
    const dest = destRows[0];
    if (!dest) return (await conn.rollback(), res.status(404).json({ error: `Destination account ${to_account_no} not found` }));
    if (dest.status === 'CLOSED') return (await conn.rollback(), res.status(400).json({ error: 'Destination account is closed' }));

    // Daily limit check
    const [dailyRows] = await conn.execute(
      `SELECT COALESCE(SUM(amount),0) AS daily_total FROM Transaction
       WHERE from_account_no = ? AND DATE(transaction_timestamp) = CURDATE()
       AND transaction_status IN ('COMPLETED','PENDING')`, [from_account_no]
    );
    if ((parseFloat(dailyRows[0].daily_total) + parseFloat(amount)) > parseFloat(own.daily_limit)) {
      // Record blocked attempt so customer sees it in dashboard
      const [ins] = await conn.execute(
        `INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp)
         VALUES (?, ?, ?, ?, 'BLOCKED', ?, NOW())`,
        [from_account_no, to_account_no, amount, transaction_type || 'TRANSFER',
         remarks || 'Fund transfer (blocked: daily limit exceeded)']
      );
      const txnId = ins.insertId;
      await conn.commit();
      const txRow = await selectTransactionRow(pool, txnId);
      return res.json({
        transaction_id: txnId,
        status: 'BLOCKED',
        blocked: true,
        amount: parseFloat(amount),
        alerts: [],
        block_reason: 'DAILY_LIMIT',
        message: `Transaction BLOCKED: daily limit of ₹${own.daily_limit} exceeded`,
        transaction: txRow,
      });
    }

    // Insert transaction as PENDING
    let ins;
    try {
      [ins] = await conn.execute(
        `INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp)
         VALUES (?, ?, ?, ?, 'PENDING', ?, NOW())`,
        [from_account_no, to_account_no, amount, transaction_type || 'TRANSFER', remarks || 'Fund transfer']
      );
    } catch (insertErr) {
      // Trigger rejected the insert — save as BLOCKED so customer sees it
      await conn.rollback();
      await conn.beginTransaction();
      try {
        const [ins2] = await conn.execute(
          `INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp)
           VALUES (?, ?, ?, ?, 'BLOCKED', ?, NOW())`,
          [from_account_no, to_account_no, amount, transaction_type || 'TRANSFER',
           (remarks || 'Fund transfer') + ' (blocked: ' + (insertErr.sqlMessage || insertErr.message) + ')']
        );
        const blockedId = ins2.insertId;
        await conn.commit();
        const txRow = await selectTransactionRow(pool, blockedId);
        const errMsg = insertErr.sqlMessage || insertErr.message || '';
        const isDailyLimit = errMsg.includes('Daily transaction limit') || errMsg.includes('daily limit');
        return res.json({
          transaction_id: blockedId,
          status: 'BLOCKED',
          blocked: true,
          amount: parseFloat(amount),
          alerts: [],
          block_reason: isDailyLimit ? 'DAILY_LIMIT' : 'TRIGGER',
          message: isDailyLimit
            ? `Transaction BLOCKED: daily limit of ₹${own.daily_limit} exceeded`
            : `Transaction BLOCKED: ${errMsg}`,
          transaction: txRow,
        });
      } catch (e2) {
        await conn.rollback();
        console.error('Blocked-insert fallback failed:', e2);
        return res.status(500).json({ error: e2.sqlMessage || e2.message || 'Transfer failed' });
      }
    }
    const txnId = ins.insertId;

    // Mark transaction COMPLETED — the trg_update_balances trigger fires here
    // and handles the balance deduction automatically. Do NOT update balances
    // manually here or they will be deducted twice.
    await conn.execute("UPDATE Transaction SET transaction_status = 'COMPLETED' WHERE transaction_id = ?", [txnId]);

    // Run AML checks
    try {
      await conn.query('CALL sp_run_aml_checks(?)', [txnId]);
    } catch (amlErr) {
      console.error('AML error (non-fatal):', amlErr.message);
    }

    // Check final status after AML
    const [statusRows] = await conn.execute('SELECT transaction_status FROM Transaction WHERE transaction_id = ?', [txnId]);
    const finalStatus = normalizeTxnStatus(statusRows[0]?.transaction_status) || 'COMPLETED';

    // If AML blocked it, reverse the balances that the trigger already applied
    if (finalStatus === 'BLOCKED') {
      await conn.execute('UPDATE Account SET balance = balance + ? WHERE account_no = ?', [amount, from_account_no]);
      await conn.execute('UPDATE Account SET balance = balance - ? WHERE account_no = ?', [amount, to_account_no]);
    }

    // Fetch any AML alerts raised
    const [alerts] = await conn.execute(
      'SELECT alert_type, severity, description FROM Alert WHERE transaction_id = ? ORDER BY alert_no DESC LIMIT 5', [txnId]
    );

    await conn.commit();
    const txRow = await selectTransactionRow(pool, txnId);
    res.json({
      transaction_id: txnId,
      status: finalStatus,
      blocked: finalStatus === 'BLOCKED',
      block_reason: finalStatus === 'BLOCKED' ? 'AML' : undefined,
      amount: parseFloat(amount),
      alerts,
      message: finalStatus === 'BLOCKED' ? 'Transaction BLOCKED by FinGuard AML' : `₹${amount} transferred successfully`,
      transaction: txRow,
    });

  } catch (err) {
    await conn.rollback();
    console.error('Transfer error:', err);
    res.status(500).json({ error: err.sqlMessage || err.message });
  } finally { conn.release(); }
});

// ── MANAGER: STATS ────────────────────────────────────────────────
app.get('/api/manager/stats', auth, managerOnly, async (req, res) => {
  const [[a]] = await pool.execute("SELECT COUNT(*) AS c FROM Alert WHERE status='OPEN'");
  const [[b]] = await pool.execute("SELECT COUNT(*) AS c FROM Alert WHERE status='OPEN' AND severity='CRITICAL'");
  const [[c]] = await pool.execute("SELECT COUNT(*) AS c FROM Customer WHERE is_flagged=1");
  const [[d]] = await pool.execute("SELECT COUNT(*) AS c FROM Transaction WHERE transaction_status='BLOCKED'");
  const [[e]] = await pool.execute("SELECT COUNT(*) AS c FROM Transaction");
  const [[f]] = await pool.execute("SELECT COUNT(*) AS c FROM Customer");
  const [[g]] = await pool.execute("SELECT COUNT(*) AS c FROM Account");
  const [[h]] = await pool.execute("SELECT COUNT(*) AS c FROM Account WHERE status='ACTIVE'");
  res.json({ open_alerts:a.c, crit_alerts:b.c, flagged_custs:c.c, blocked_txns:d.c, total_txns:e.c, total_customers:f.c, total_accounts:g.c, active_accounts:h.c });
});

// ── MANAGER: ALERTS ───────────────────────────────────────────────
app.get('/api/manager/alerts', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT al.alert_no, al.transaction_id, al.customer_id, al.alert_type, al.severity,
            al.description, al.status, al.alert_timestamp,
            c.full_name AS customer_name, c.PAN_number, c.risk_score,
            t.amount, t.transaction_type
     FROM Alert al
     JOIN Customer c ON al.customer_id = c.customer_id
     LEFT JOIN Transaction t ON al.transaction_id = t.transaction_id
     ORDER BY FIELD(al.severity,'CRITICAL','HIGH','MEDIUM','LOW'), al.alert_timestamp DESC LIMIT 100`
  );
  res.json(rows);
});

app.patch('/api/manager/alerts/:id', auth, managerOnly, async (req, res) => {
  const { status } = req.body;
  await pool.execute('UPDATE Alert SET status=?, assigned_to=? WHERE alert_no=?', [status, req.user.id, req.params.id]);
  res.json({ success: true });
});

// ── MANAGER: CUSTOMERS ────────────────────────────────────────────
app.get('/api/manager/customers', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT c.customer_id, c.full_name, c.email, c.phone, c.city, c.PAN_number,
            c.risk_score, c.is_flagged, c.created_at, b.branch_name,
            COUNT(DISTINCT a.account_no) AS account_count,
            COUNT(DISTINCT al.alert_no)  AS alert_count
     FROM Customer c
     LEFT JOIN Branch b  ON c.branch_id = b.branch_id
     LEFT JOIN Account a ON a.customer_id = c.customer_id
     LEFT JOIN Alert al  ON al.customer_id = c.customer_id
     GROUP BY c.customer_id ORDER BY c.risk_score DESC, c.created_at DESC`
  );
  res.json(rows);
});

app.get('/api/manager/customers/:id', auth, managerOnly, async (req, res) => {
  const [[cust]] = await pool.execute(
    `SELECT c.*, b.branch_name, b.IFSC_code FROM Customer c JOIN Branch b ON c.branch_id=b.branch_id WHERE c.customer_id=?`, [req.params.id]
  );
  if (!cust) return res.status(404).json({ error: 'Customer not found' });
  const [accounts] = await pool.execute(
    `SELECT a.*, b.branch_name, b.IFSC_code FROM Account a JOIN Branch b ON a.branch_id=b.branch_id WHERE a.customer_id=? ORDER BY a.created_at DESC`, [req.params.id]
  );
  const [alerts] = await pool.execute('SELECT * FROM Alert WHERE customer_id=? ORDER BY alert_timestamp DESC LIMIT 20', [req.params.id]);
  const [transactions] = await pool.execute(
    `SELECT DISTINCT t.* FROM Transaction t JOIN Account a ON (t.from_account_no=a.account_no OR t.to_account_no=a.account_no)
     WHERE a.customer_id=? ORDER BY t.transaction_timestamp DESC LIMIT 30`, [req.params.id]
  );
  res.json({ customer: cust, accounts, alerts, transactions });
});

app.post('/api/manager/customers', auth, managerOnly, async (req, res) => {
  const { customer_id, full_name, email, phone, address, city, DOB, PAN_number, password, branch_id } = req.body;
  if (!customer_id || !full_name || !email || !PAN_number || !password)
    return res.status(400).json({ error: 'customer_id, full_name, email, PAN_number and password are required' });
  const password_hash = await bcrypt.hash(password, 12);
  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    await conn.execute(
      `INSERT INTO Customer (customer_id, branch_id, full_name, email, phone, address, city, DOB, PAN_number, password_hash)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [customer_id, branch_id || req.user.branch_id || 1, full_name, email, phone||'', address||'', city||'', DOB||'1990-01-01', PAN_number.toUpperCase(), password_hash]
    );
    await conn.execute(
      `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, new_values, logged_at) VALUES ('Customer','INSERT',?,?,?,NOW())`,
      [customer_id, req.user.id, JSON.stringify({ customer_id, full_name, email, PAN_number })]
    );
    await conn.commit();
    res.json({ success: true, customer_id });
  } catch (err) {
    await conn.rollback();
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Customer ID, Email or PAN already registered' });
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ── MANAGER: ALL ACCOUNTS ─────────────────────────────────────────
app.get('/api/manager/accounts', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT a.account_no, a.account_type, a.balance, a.status, a.daily_limit, a.created_at,
            a.customer_id, c.full_name AS customer_name, c.PAN_number AS customer_pan, b.branch_name
     FROM Account a
     JOIN Customer c ON a.customer_id = c.customer_id
     JOIN Branch   b ON a.branch_id   = b.branch_id
     ORDER BY a.created_at DESC`
  );
  res.json(rows);
});

// ── MANAGER: CREATE ACCOUNT ───────────────────────────────────────
app.post('/api/manager/accounts', auth, managerOnly, async (req, res) => {
  const { customer_id, account_type, initial_deposit, daily_limit, branch_id, account_no } = req.body;
  if (!customer_id || !account_type || !account_no)
    return res.status(400).json({ error: 'customer_id, account_no and account_type are required' });

  // Validate 12-digit account number
  if (!/^\d{12}$/.test(String(account_no)))
    return res.status(400).json({ error: 'account_no must be exactly 12 digits' });

  const deposit = parseFloat(initial_deposit) || 0;
  const limit   = parseFloat(daily_limit) || 200000;

  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    const [[cust]] = await conn.execute('SELECT customer_id, branch_id, full_name FROM Customer WHERE customer_id=?', [customer_id]);
    if (!cust) return (await conn.rollback(), res.status(404).json({ error: `Customer ${customer_id} not found` }));

    const useBranch = branch_id || cust.branch_id;

    await conn.execute(
      `INSERT INTO Account (account_no, customer_id, branch_id, account_type, balance, daily_limit, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE', NOW())`,
      [account_no, customer_id, useBranch, account_type, deposit, limit]
    );

    if (deposit > 0) {
      await conn.execute(
        `INSERT INTO Transaction (to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp)
         VALUES (?, ?, 'DEPOSIT', 'COMPLETED', 'Account opening deposit', NOW())`,
        [account_no, deposit]
      );
    }

    await conn.execute(
      `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, new_values, logged_at) VALUES ('Account','INSERT',?,?,?,NOW())`,
      [String(account_no), req.user.id, JSON.stringify({ account_no, customer_id, account_type, balance: deposit, daily_limit: limit, created_by: req.user.name })]
    );

    await conn.commit();
    console.log(`✅ Account ${account_no} created for customer ${customer_id} (${cust.full_name})`);
    res.json({
      success: true, account_no,
      message: `Account ${account_no} created for ${cust.full_name}`,
      account: { account_no, customer_id, account_type, balance: deposit, daily_limit: limit, status: 'ACTIVE' }
    });

  } catch (err) {
    await conn.rollback();
    console.error('Create account error:', err);
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'Account number already exists' });
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ── MANAGER: CLOSE ACCOUNT ────────────────────────────────────────
app.delete('/api/manager/accounts/:id', auth, managerOnly, async (req, res) => {
  const conn = await pool.getConnection();
  await conn.beginTransaction();
  try {
    const [[acc]] = await conn.execute(
      `SELECT a.*, c.full_name AS customer_name FROM Account a JOIN Customer c ON a.customer_id=c.customer_id WHERE a.account_no=?`,
      [req.params.id]
    );
    if (!acc) return (await conn.rollback(), res.status(404).json({ error: `Account ${req.params.id} not found` }));
    if (acc.status === 'CLOSED') return (await conn.rollback(), res.status(400).json({ error: 'Account is already closed' }));
    if (parseFloat(acc.balance) > 0) return (await conn.rollback(), res.status(400).json({ error: `Cannot close: balance ₹${acc.balance} must be withdrawn first` }));

    await conn.execute("UPDATE Account SET status='CLOSED' WHERE account_no=?", [req.params.id]);
    await conn.execute(
      `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, old_values, new_values, logged_at) VALUES ('Account','UPDATE',?,?,?,?,NOW())`,
      [String(req.params.id), req.user.id, JSON.stringify({ status: acc.status }), JSON.stringify({ status: 'CLOSED', closed_by: req.user.name, closed_at: new Date().toISOString() })]
    );
    await conn.commit();
    console.log(`✅ Account ${req.params.id} closed by manager ${req.user.id}`);
    res.json({ success: true, message: `Account ${req.params.id} (${acc.customer_name}) closed successfully` });

  } catch (err) {
    await conn.rollback();
    console.error('Close account error:', err);
    res.status(500).json({ error: err.message });
  } finally { conn.release(); }
});

// ── MANAGER: FREEZE / UNFREEZE ────────────────────────────────────
app.patch('/api/manager/accounts/:id/freeze', auth, managerOnly, async (req, res) => {
  const { action } = req.body;
  const newStatus = action === 'FREEZE' ? 'FROZEN' : 'ACTIVE';
  const [[acc]] = await pool.execute('SELECT account_no, status FROM Account WHERE account_no=?', [req.params.id]);
  if (!acc) return res.status(404).json({ error: 'Account not found' });
  await pool.execute('UPDATE Account SET status=? WHERE account_no=?', [newStatus, req.params.id]);
  await pool.execute(
    `INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, old_values, new_values, logged_at) VALUES ('Account','UPDATE',?,?,?,?,NOW())`,
    [String(req.params.id), req.user.id, JSON.stringify({ status: acc.status }), JSON.stringify({ status: newStatus, action_by: req.user.name })]
  );
  res.json({ success: true, status: newStatus });
});

// ── MANAGER: TRANSACTIONS ─────────────────────────────────────────
app.get('/api/manager/transactions', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT t.transaction_id, t.from_account_no, t.to_account_no, t.amount,
            t.transaction_type, t.transaction_status, t.transaction_timestamp, t.remarks,
            cf.full_name AS from_customer, ct.full_name AS to_customer
     FROM Transaction t
     LEFT JOIN Account  af ON t.from_account_no = af.account_no
     LEFT JOIN Account  at ON t.to_account_no   = at.account_no
     LEFT JOIN Customer cf ON af.customer_id     = cf.customer_id
     LEFT JOIN Customer ct ON at.customer_id     = ct.customer_id
     ORDER BY t.transaction_timestamp DESC LIMIT 100`
  );
  res.json(rows);
});

// ── MANAGER: BRANCHES ─────────────────────────────────────────────
app.get('/api/manager/branches', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute('SELECT branch_id, branch_name, IFSC_code, city, state FROM Branch ORDER BY branch_name');
  res.json(rows);
});

// ── MANAGER: AUDIT LOG ────────────────────────────────────────────
app.get('/api/manager/audit-log', auth, managerOnly, async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT l.log_id, l.table_name, l.operation, l.record_id, l.old_values, l.new_values, l.logged_at, e.name AS employee_name
     FROM Audit_Log l LEFT JOIN Employee e ON l.changed_by = e.employee_id
     ORDER BY l.logged_at DESC LIMIT 100`
  );
  res.json(rows);
});

// ── CATCH-ALL: serve frontend ────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/public', 'index.html'));
});

// ── START ─────────────────────────────────────────────────────────
const preferredPort = parseInt(process.env.PORT || '3000', 10);

function startServer(port, attemptsLeft = 12) {
  const server = http.createServer(app);
  server.once('error', (err) => {
    if (err.code === 'EADDRINUSE' && attemptsLeft > 0) {
      console.warn(`⚠️  Port ${port} is in use — trying ${port + 1}…`);
      startServer(port + 1, attemptsLeft - 1);
    } else {
      console.error(`\n❌  Could not bind: ${err.message}`);
      if (err.code === 'EADDRINUSE') {
        console.error(`   Set PORT in .env or stop the other process (e.g. lsof -i :${port})\n`);
      }
      process.exit(1);
    }
  });
  server.listen(port, () => {
    if (port !== preferredPort) {
      console.warn(`   (Another app was using ${preferredPort}; you are on ${port}. Consider updating PORT in .env.)\n`);
    }
    console.log(`\n🏦  FinGuard National Bank`);
    console.log(`✅  Server: http://localhost:${port}`);
    console.log(`🛡   AML Engine active`);
    console.log(`📦  DB: ${process.env.DB_NAME || 'finguard_bank'} @ ${process.env.DB_HOST || 'localhost'}\n`);
  });
}

startServer(preferredPort);