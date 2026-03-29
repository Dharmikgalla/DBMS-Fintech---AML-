# FinGuard National Bank — Full Stack Setup

## Project Structure
```
DBMS-Fintech---AML-/
├── backend/
│   ├── server.js      ← Express API + serves the UI
│   ├── package.json
│   └── .env           ← Create from your MySQL credentials (not committed)
├── frontend/
│   └── public/
│       └── index.html ← Customer & staff UI (static files served by Express)
├── database/
│   ├── bank_oltp_schema_fixed.sql
│   ├── realistic_seed_data.sql
│   ├── bank_warehouse_schema_fixed2.sql
│   └── warehouse_seed_data.sql
└── README.md
```

## Quick Start (Demo Mode — No Backend Needed)
Open `frontend/public/index.html` in a browser only if you use a standalone demo build.
For the full app, run the backend and use **http://localhost:3000** (see below).

**Demo Credentials:**
| Role              | ID      | Password    |
|-------------------|---------|-------------|
| Customer          | CUST001 | password123 |
| Customer (Flagged)| CUST002 | password123 |
| Branch Manager    | MGR001  | password123 |
| Compliance Officer| EMP001  | password123 |

---

## Full Stack Setup (Express + MySQL)

### Prerequisites
- Node.js 18+
- MySQL 8.0+
- npm

### Step 1 — Database Setup
```sql
-- In MySQL Workbench or CLI (from the `database/` folder):
SOURCE bank_oltp_schema_fixed.sql;
SOURCE realistic_seed_data.sql;
SOURCE bank_warehouse_schema_fixed2.sql;
SOURCE warehouse_seed_data.sql;
```

### Step 2 — Backend Setup
```bash
cd backend
npm install
```

### Step 3 — Configure DB Connection
Create `backend/.env` or set environment variables:
```bash
export DB_HOST=localhost
export DB_USER=root
export DB_PASS=your_mysql_password
export DB_NAME=finguard_bank
export JWT_SECRET=change_this_in_production
```

### Step 4 — Start Backend
```bash
npm start
# or for development with auto-reload:
npm run dev
```

### Step 5 — Open the app
The Express server serves `frontend/public/index.html` at the root URL.

Open: **http://localhost:3000**

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
