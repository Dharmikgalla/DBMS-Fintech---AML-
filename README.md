# FinGuard National Bank — Full Stack Setup

## Project Structure
```
DBMS-Fintech---AML-/
├── backend/
│   ├── server.js      ← Express API + serves the UI
│   ├── package.json
│   └── .env           ← You create this (not in Git; holds DB credentials)
├── frontend/
│   └── public/
│       └── index.html ← Customer & staff UI (served by Express)
├── database/
│   ├── bank_oltp_schema_fixed.sql
│   ├── realistic_seed_data.sql
│   ├── bank_warehouse_schema_fixed2.sql
│   └── warehouse_seed_data.sql
└── README.md
```

---

## Run on a new laptop (exact steps)

Follow these in order on **macOS**, **Windows**, or **Linux**.

### 1. Install prerequisites

| Software | Notes |
|----------|--------|
| **Git** | [https://git-scm.com/downloads](https://git-scm.com/downloads) |
| **Node.js** | **v18+** (LTS recommended): [https://nodejs.org](https://nodejs.org) — includes `npm` |
| **MySQL** | **8.0+** Server: [https://dev.mysql.com/downloads/mysql/](https://dev.mysql.com/downloads/mysql/) |

Verify in a terminal:

```bash
git --version
node -v
npm -v
mysql --version
```

Start the **MySQL** service (name varies by OS: e.g. Windows Services, `brew services start mysql` on Mac, `sudo systemctl start mysql` on Linux).

---

### 2. Clone the repository

```bash
git clone https://github.com/Dharmikgalla/DBMS-Fintech---AML-.git
cd DBMS-Fintech---AML-
```

---

### 3. Create the databases (MySQL)

Load scripts **in this order** (OLTP → seed → warehouse schema → warehouse seed).

**Option A — MySQL command line** (replace `root` / password with your MySQL user):

```bash
cd database

mysql -h 127.0.0.1 -P 3306 -u root -p < bank_oltp_schema_fixed.sql
mysql -h 127.0.0.1 -P 3306 -u root -p < realistic_seed_data.sql
mysql -h 127.0.0.1 -P 3306 -u root -p < bank_warehouse_schema_fixed2.sql
mysql -h 127.0.0.1 -P 3306 -u root -p < warehouse_seed_data.sql

cd ..
```

**Option B — MySQL Workbench**  
Open each file in order and execute: `bank_oltp_schema_fixed.sql` → `realistic_seed_data.sql` → `bank_warehouse_schema_fixed2.sql` → `warehouse_seed_data.sql`.

**If you already had old databases and imports fail** (duplicate objects), drop OLTP once and re-run from `bank_oltp_schema_fixed.sql`:

```sql
DROP DATABASE IF EXISTS finguard_bank;
```

Then run the four files again in order. The warehouse script already contains `DROP DATABASE IF EXISTS finguard_warehouse` where needed.

---

### 4. Configure the backend

In the project root, create **`backend/.env`** (copy the block below and edit values):

```env
DB_HOST=127.0.0.1
DB_USER=root
DB_PASS=your_mysql_password_here
DB_NAME=finguard_bank
DB_PORT=3306
JWT_SECRET=use_a_long_random_string_in_production
PORT=3000
```

- Use **`127.0.0.1`** instead of `localhost` if you see socket or connection errors.
- **`DB_PASS`** must match the MySQL user you used in step 3.

---

### 5. Install dependencies and start the server

```bash
cd backend
npm install
npm start
```

For development with auto-restart:

```bash
npm run dev
```

You should see a message with **Server: http://localhost:3000** (or the next free port if 3000 is busy).

---

### 6. Open the application

In a browser go to:

**http://localhost:3000**

The UI is **`frontend/public/index.html`**, served by Express from the backend.

---

### 7. Demo login (from seed data)

Passwords are defined in `database/realistic_seed_data.sql`.

| Role | ID (example) | Password |
|------|----------------|----------|
| Customer | `ananya92` | `password123` |
| Bank staff | `arjun01` | `manager123` |

Use **Customer** or **Bank Staff** on the login screen and enter the ID and password exactly as in the table.

---

### 8. Troubleshooting

| Problem | What to try |
|---------|-------------|
| **Port already in use** | Set `PORT=3001` (or another port) in `backend/.env`, or stop the other app using port 3000. |
| **Cannot connect to MySQL** | Confirm MySQL is running; check `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_PORT` in `backend/.env`. |
| **Access denied for user** | Fix MySQL user/password; ensure the user can connect from `127.0.0.1`. |
| **Invalid credentials** | Re-run `realistic_seed_data.sql` against `finguard_bank`; use IDs above with correct passwords. |
| **Duplicate key / schema errors** | Drop `finguard_bank` (and re-import), or use a fresh MySQL instance. |

---

## Quick reference (already covered above)

- **Backend folder:** `backend/`  
- **Frontend static files:** `frontend/public/`  
- **API + UI URL:** `http://localhost:<PORT>` (default **3000**)

---

## API Endpoints

### Auth
| Method | Endpoint   | Body                          | Description       |
|--------|------------|-------------------------------|-------------------|
| POST   | /api/login | `{id, password, role}`        | Login             |

### Customer (Bearer token required)
| Method | Endpoint                     | Description               |
|--------|------------------------------|---------------------------|
| GET    | /api/customer/accounts       | My accounts               |
| GET    | /api/customer/transactions   | My transactions           |
| POST   | /api/customer/transfer       | Send money (AML runs here)|

### Manager / Employee (Bearer token, manager role)
| Method | Endpoint                          | Description                      |
|--------|-----------------------------------|----------------------------------|
| GET    | /api/manager/stats                | Dashboard metrics                |
| GET    | /api/manager/alerts               | All AML alerts                   |
| PATCH  | /api/manager/alerts/:id           | Update alert status              |
| GET    | /api/manager/customers            | All customers + risk scores      |
| POST   | /api/manager/customers            | Create new customer              |
| GET    | /api/manager/customers/:id        | Customer detail + accounts + txns|
| POST   | /api/manager/accounts             | **Create new account**           |
| DELETE | /api/manager/accounts/:id         | **Close account** (balance=0)    |
| PATCH  | /api/manager/accounts/:id/freeze  | Freeze / Unfreeze account        |
| GET    | /api/manager/transactions         | All transactions                 |
| GET    | /api/manager/branches             | All branches                     |
| GET    | /api/manager/audit-log            | Audit log                        |

---

## AML Rules (FinGuard Engine)
All rules run automatically via MySQL stored procedure `sp_run_aml_checks()` 
called by the AFTER INSERT trigger on the Transaction table.

| Rule                   | Trigger                                    | Action                      |
|------------------------|--------------------------------------------|-----------------------------|
| Large Transaction      | Single txn ≥ ₹10,00,000                   | BLOCK + CRITICAL alert      |
| Large Transaction      | Single txn ≥ ₹5,00,000                    | HIGH alert                  |
| Structuring / Smurfing | 3+ txns summing ≥ ₹10L in 24h             | CRITICAL alert, risk +30    |
| Velocity Spike (3σ)    | Amount > 3 std devs above 60-day avg       | HIGH alert                  |
| Rapid Movement         | 80%+ of received funds out within 2h       | CRITICAL layering alert     |
| Dormant Activation     | No activity 90+ days then large txn        | HIGH alert                  |
| Geo Anomaly            | Implied travel > 900 km/h                  | HIGH alert                  |
| Blacklist Match        | PAN / IP / device in AML_Blacklist table   | BLOCK + CRITICAL alert      |

---

## Manager Features
- **Create Account**: Open new Savings/Current/FD account for any customer
- **Close Account**: Close accounts with ₹0 balance (soft delete, audit-logged)
- **Freeze/Unfreeze**: Temporarily block transactions during AML investigation
- **Register Customer**: Full KYC form, optionally open first account
- **AML Alert Queue**: Review, resolve, mark false positive
- **Customer Risk Monitor**: Risk scores, flagged status, alert count
- **Audit Log**: Every account management action logged with who/when/what
