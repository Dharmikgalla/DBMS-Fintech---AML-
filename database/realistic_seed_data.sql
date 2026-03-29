-- ============================================================
--  FinGuard National Bank — FULL REALISTIC SEED DATA
--  Indian banking context | 6 months of history
--  15 customers, 22 accounts, 120+ transactions
--  AML patterns: structuring, layering, large txns, velocity spikes
--  Run AFTER bank_oltp_schema_fixed.sql
-- ============================================================

USE finguard_bank;

SET FOREIGN_KEY_CHECKS = 0;

DROP TRIGGER IF EXISTS trg_prevent_overdraft;

-- ============================================================
-- TRUNCATE ALL TABLES (clean slate)
-- ============================================================
TRUNCATE TABLE Alert;
TRUNCATE TABLE Audit_Log;
TRUNCATE TABLE AML_Blacklist;
TRUNCATE TABLE Daily_Transaction_Summary;
TRUNCATE TABLE Customer_Behavior_Profile;
TRUNCATE TABLE Transaction;
TRUNCATE TABLE Account;
TRUNCATE TABLE Customer;
TRUNCATE TABLE Employee;
TRUNCATE TABLE Branch;

-- ============================================================
-- STEP 1: BRANCHES
-- ============================================================
INSERT INTO Branch (branch_id, bank_id, branch_name, IFSC_code, city, state) VALUES
(1, 1, 'T. Nagar Branch',        'FGNB0001001', 'Chennai',   'Tamil Nadu'),
(2, 1, 'Andheri West Branch',    'FGNB0002001', 'Mumbai',    'Maharashtra'),
(3, 1, 'Koramangala Branch',     'FGNB0003001', 'Bangalore', 'Karnataka'),
(4, 1, 'Connaught Place Branch', 'FGNB0004001', 'New Delhi', 'Delhi'),
(5, 1, 'Salt Lake Branch',       'FGNB0005001', 'Kolkata',   'West Bengal');

-- ============================================================
-- STEP 2: EMPLOYEES
-- employee_id: alphanumeric (letters + numbers)
-- Password: manager123 → bcrypt hash
-- ============================================================
INSERT INTO Employee (employee_id, branch_id, name, role, salary, joining_date, email, password_hash) VALUES
('arjun01',   1, 'Arjun Mehta',     'BRANCH_MANAGER',     125000, '2018-04-01', 'arjun.mehta@fgnb.in',       '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('sunita02',  2, 'Sunita Patel',    'BRANCH_MANAGER',     118000, '2017-08-15', 'sunita.patel@fgnb.in',      '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('priya03',   1, 'Priya Rajan',     'COMPLIANCE_OFFICER',  95000, '2019-07-15', 'priya.rajan@fgnb.in',       '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('karthik04', 2, 'Karthik Sundar',  'AML_ANALYST',         88000, '2021-01-10', 'karthik.sundar@fgnb.in',    '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('deepa05',   3, 'Deepa Nair',      'BRANCH_MANAGER',     115000, '2020-03-20', 'deepa.nair@fgnb.in',        '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('vikram06',  4, 'Vikram Singh',    'BRANCH_MANAGER',     122000, '2016-11-01', 'vikram.singh@fgnb.in',      '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe'),
('ritika07',  5, 'Ritika Banerjee', 'AML_ANALYST',         91000, '2022-06-05', 'ritika.banerjee@fgnb.in',   '$2b$12$lHCbwI05S6yTFcJb4DWd/OLOxWj.8keEWVX9v2GtyGmSIzPGgfyYe');

-- ============================================================
-- STEP 3: CUSTOMERS
-- customer_id: alphanumeric (name-based + birth year digits)
-- password_hash = bcrypt('password123')
-- ============================================================
INSERT INTO Customer (customer_id, branch_id, full_name, email, phone, address, city, DOB, PAN_number, risk_score, is_flagged, password_hash, created_at) VALUES

-- NORMAL CUSTOMERS
('ananya92',  1, 'Ananya Krishnamurthy', 'ananya.k@gmail.com',    '9841234567', '14, 3rd Cross, T Nagar',         'Chennai',   '1992-05-14', 'ABCPK1234H',  8,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2021-03-10 10:00:00'),
('suresh85',  1, 'Suresh Babu',          'suresh.babu@yahoo.com', '9841987654', '22, Gandhi Nagar, Adyar',         'Chennai',   '1985-09-22', 'ABCPS5678D',  5,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2020-07-15 09:30:00'),
('meera90',   2, 'Meera Desai',          'meera.desai@gmail.com', '9920345678', '8B, Lokhandwala Complex, Andheri','Mumbai',    '1990-03-30', 'BCDQM2345F', 12,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2021-01-20 11:00:00'),
('rohit88',   3, 'Rohit Sharma',         'rohit.s@hotmail.com',   '9845678901', '45, Koramangala 5th Block',       'Bangalore', '1988-12-05', 'CDERS3456G',  7,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2019-11-05 14:00:00'),
('pooja95',   4, 'Pooja Verma',          'pooja.v@gmail.com',     '9811223344', '12, Lajpat Nagar II',             'New Delhi', '1995-07-18', 'DEFPV4567H',  4,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2022-02-14 10:30:00'),
('arnab83',   5, 'Arnab Chatterjee',     'arnab.c@gmail.com',     '9830112233', '3, Bidhan Nagar, Salt Lake',      'Kolkata',   '1983-11-28', 'EFGAC5678J',  6,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2020-05-01 09:00:00'),

-- MEDIUM RISK
('vikash79',  2, 'Vikash Agarwal',       'vikash.a@business.com', '9833445566', '501, Nariman Point Office',       'Mumbai',    '1979-04-10', 'FGHVA6789K', 28,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2019-08-20 10:00:00'),
('kavitha87', 3, 'Kavitha Reddy',        'kavitha.r@techcorp.in', '9845901234', '22, Whitefield Main Road',        'Bangalore', '1987-06-15', 'GHIKR7890L', 22,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2020-01-10 11:30:00'),
('muthu75',   1, 'Muthukrishnan Pillai', 'muthu.p@export.com',    '9841456789', '7, Nungambakkam High Road',       'Chennai',   '1975-02-20', 'HIJKM8901M', 35,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2018-06-15 09:00:00'),

-- HIGH RISK / FLAGGED
('rajesh80',  2, 'Rajesh Venkataraman',  'rajesh.v@trade.com',    '9820567890', '45, Linking Road, Bandra',        'Mumbai',    '1980-08-15', 'IJKLR9012N', 78,  1, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2021-09-01 10:00:00'),
('sanjay77',  4, 'Sanjay Malhotra',      'sanjay.m@trade.net',    '9810678901', '88, Connaught Place',             'New Delhi', '1977-03-12', 'JKLSM0123P', 82,  1, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2021-05-10 10:00:00'),
('pradeep82', 5, 'Pradeep Ghosh',        'pradeep.g@shell.com',   '9831789012', '14, Park Street',                 'Kolkata',   '1982-07-25', 'KLMPG1234Q', 91,  1, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2022-01-15 10:00:00'),

-- NEW / RECENT CUSTOMERS
('divya98',   3, 'Divya Menon',          'divya.m@gmail.com',     '9845234567', '18, Indiranagar 100ft Road',      'Bangalore', '1998-01-10', 'LMNDI2345R',  3,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2023-04-01 10:00:00'),
('senthil93', 1, 'Senthil Kumar',        'senthil.k@startup.io',  '9841345678', '31, Anna Salai',                  'Chennai',   '1993-09-05', 'MNOSE3456S', 15,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2023-06-15 10:00:00'),
('harpreet91',2, 'Harpreet Kaur',        'harpreet.k@ngo.org',    '9820456789', '9, Juhu Scheme Road',             'Mumbai',    '1991-12-20', 'NOPHK4567T', 10,  0, '$2b$12$zz4ouVrs8vAIz3dZfCN7N.xPGMVPn2xdNHUA0Fc5Pq8dIqCvmP102', '2023-08-20 10:00:00');

-- ============================================================
-- STEP 4: ACCOUNTS
-- account_no: 12-digit BIGINT, unique per account
-- ============================================================
INSERT INTO Account (account_no, customer_id, branch_id, account_type, balance, daily_limit, status, created_at) VALUES
-- Ananya
(432156780001, 'ananya92',  1, 'SAVINGS',       142500.00, 100000, 'ACTIVE',    '2021-03-10 10:00:00'),
(432156780002, 'ananya92',  1, 'FIXED_DEPOSIT', 500000.00,  50000, 'ACTIVE',    '2022-01-01 10:00:00'),
-- Suresh
(432156780003, 'suresh85',  1, 'SAVINGS',        67800.50, 100000, 'ACTIVE',    '2020-07-15 09:30:00'),
-- Meera
(432156780004, 'meera90',   2, 'SAVINGS',       215000.00, 200000, 'ACTIVE',    '2021-01-20 11:00:00'),
(432156780005, 'meera90',   2, 'CURRENT',       380000.00, 500000, 'ACTIVE',    '2021-06-01 11:00:00'),
-- Rohit
(432156780006, 'rohit88',   3, 'SAVINGS',       128400.75, 200000, 'ACTIVE',    '2019-11-05 14:00:00'),
-- Pooja
(432156780007, 'pooja95',   4, 'SAVINGS',        54200.00, 100000, 'ACTIVE',    '2022-02-14 10:30:00'),
-- Arnab
(432156780008, 'arnab83',   5, 'SAVINGS',        93600.00, 150000, 'ACTIVE',    '2020-05-01 09:00:00'),
-- Vikash
(432156780009, 'vikash79',  2, 'CURRENT',      1250000.00,1000000, 'ACTIVE',    '2019-08-20 10:00:00'),
(432156780010, 'vikash79',  2, 'SAVINGS',       340000.00, 500000, 'ACTIVE',    '2020-03-15 10:00:00'),
-- Kavitha
(432156780011, 'kavitha87', 3, 'SAVINGS',       287500.00, 300000, 'ACTIVE',    '2020-01-10 11:30:00'),
(432156780012, 'kavitha87', 3, 'CURRENT',       620000.00, 700000, 'ACTIVE',    '2021-07-01 11:00:00'),
-- Muthukrishnan
(432156780013, 'muthu75',   1, 'CURRENT',      2100000.00,2000000, 'ACTIVE',    '2018-06-15 09:00:00'),
(432156780014, 'muthu75',   1, 'SAVINGS',       175000.00, 200000, 'ACTIVE',    '2019-01-01 09:00:00'),
-- Rajesh (HIGH RISK)
(432156780015, 'rajesh80',  2, 'SAVINGS',        22000.00, 200000, 'SUSPENDED', '2021-09-01 10:00:00'),
(432156780016, 'rajesh80',  2, 'CURRENT',            0.00, 500000, 'FROZEN',    '2021-11-01 10:00:00'),
-- Sanjay (HIGH RISK)
(432156780017, 'sanjay77',  4, 'SAVINGS',        18500.00, 200000, 'SUSPENDED', '2021-05-10 10:00:00'),
(432156780018, 'sanjay77',  4, 'CURRENT',            0.00, 500000, 'FROZEN',    '2021-08-01 10:00:00'),
-- Pradeep (CRITICAL RISK)
(432156780019, 'pradeep82', 5, 'SAVINGS',            0.00, 200000, 'SUSPENDED', '2022-01-15 10:00:00'),
-- Divya
(432156780020, 'divya98',   3, 'SAVINGS',        38900.00, 100000, 'ACTIVE',    '2023-04-01 10:00:00'),
-- Senthil
(432156780021, 'senthil93', 1, 'CURRENT',       450000.00, 500000, 'ACTIVE',    '2023-06-15 10:00:00'),
-- Harpreet
(432156780022, 'harpreet91',2, 'SAVINGS',       125000.00, 200000, 'ACTIVE',    '2023-08-20 10:00:00');

-- ============================================================
-- STEP 5: TRANSACTIONS (6 months of realistic data)
-- All account_id references → account_no (12-digit)
-- ============================================================

-- ── ANANYA: monthly salary + routine payments ─────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Sept 2024',        '2024-09-01 09:15:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',           '2024-09-03 18:30:00'),
(432156780001,  NULL,           3000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',              '2024-09-07 11:00:00'),
(432156780001,  432156780007,  12000.00, 'IMPS',       'COMPLETED', 'Friends trip contribution',        '2024-09-14 20:15:00'),
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Oct 2024',         '2024-10-01 09:10:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',           '2024-10-03 18:45:00'),
(432156780001,  NULL,           5000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',              '2024-10-10 12:00:00'),
(432156780001,  432156780006,  25000.00, 'NEFT',       'COMPLETED', 'Loan repayment to Rohit',          '2024-10-20 14:00:00'),
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Nov 2024',         '2024-11-01 09:05:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',           '2024-11-03 19:00:00'),
(432156780001,  NULL,           4000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',              '2024-11-12 10:30:00'),
(432156780001,  432156780004,   8500.00, 'UPI',        'COMPLETED', 'Split bill - Meera',               '2024-11-22 21:00:00');

-- ── SURESH: rent income + expenses ───────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',        '2024-09-03 18:31:00'),
(432156780003,  NULL,           8000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                   '2024-09-08 10:00:00'),
(432156780003,  432156780007,   5000.00, 'UPI',        'COMPLETED', 'Transferred to Pooja',             '2024-09-20 16:00:00'),
(NULL,          432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',        '2024-10-03 18:46:00'),
(432156780003,  NULL,           6000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                   '2024-10-09 11:00:00'),
(NULL,          432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',        '2024-11-03 19:01:00');

-- ── MEERA: IT salary + home loan EMI ─────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary credit TechCorp Sep',       '2024-09-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'Home loan EMI - HDFC',             '2024-09-05 08:00:00'),
(432156780004,  NULL,           8000.00, 'WITHDRAWAL', 'COMPLETED', 'Cash withdrawal',                  '2024-09-15 12:00:00'),
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary credit TechCorp Oct',       '2024-10-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'Home loan EMI - HDFC',             '2024-10-05 08:00:00'),
(432156780004,  432156780005,  50000.00, 'TRANSFER',   'COMPLETED', 'Transfer to current account',      '2024-10-18 14:00:00'),
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary credit TechCorp Nov',       '2024-11-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'Home loan EMI - HDFC',             '2024-11-05 08:00:00');

-- ── ROHIT: software engineer ──────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Sep',        '2024-09-01 11:00:00'),
(432156780006,  NULL,          30000.00, 'NEFT',       'COMPLETED', 'House rent paid',                  '2024-09-04 09:00:00'),
(432156780006,  NULL,          10000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                   '2024-09-12 14:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Oct',        '2024-10-01 11:00:00'),
(432156780006,  NULL,          30000.00, 'NEFT',       'COMPLETED', 'House rent paid',                  '2024-10-04 09:00:00'),
(432156780006,  432156780011,  20000.00, 'IMPS',       'COMPLETED', 'Payment to Kavitha',               '2024-10-25 17:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Nov',        '2024-11-01 11:00:00'),
(432156780006,  NULL,          30000.00, 'NEFT',       'COMPLETED', 'House rent paid',                  '2024-11-04 09:00:00');

-- ── VIKASH: business transactions ────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780009, 450000.00, 'RTGS',       'COMPLETED', 'Client payment - Sharma Co',       '2024-09-05 10:00:00'),
(432156780009,  NULL,         250000.00, 'RTGS',       'COMPLETED', 'Vendor payment - Raw materials',   '2024-09-06 11:00:00'),
(432156780009,  432156780010,  80000.00, 'TRANSFER',   'COMPLETED', 'Transfer to savings',              '2024-09-10 14:00:00'),
(NULL,          432156780009, 380000.00, 'RTGS',       'COMPLETED', 'Client payment - Verma Ltd',       '2024-10-08 10:00:00'),
(432156780009,  NULL,         200000.00, 'RTGS',       'COMPLETED', 'Vendor payment - supplies',        '2024-10-09 11:00:00'),
(432156780009,  NULL,         150000.00, 'NEFT',       'COMPLETED', 'GST payment to government',        '2024-10-20 09:00:00'),
(NULL,          432156780009, 520000.00, 'RTGS',       'COMPLETED', 'Client payment - Nov project',     '2024-11-07 10:00:00'),
(432156780009,  NULL,         280000.00, 'RTGS',       'COMPLETED', 'Vendor payment - Nov supplies',    '2024-11-08 11:00:00');

-- ── KAVITHA: senior developer ─────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780011, 140000.00, 'NEFT',       'COMPLETED', 'Salary credit Wipro Sep',          '2024-09-01 10:30:00'),
(432156780011,  NULL,          45000.00, 'NEFT',       'COMPLETED', 'Apartment EMI payment',            '2024-09-05 08:30:00'),
(432156780011,  NULL,          12000.00, 'WITHDRAWAL', 'COMPLETED', 'Cash withdrawal',                  '2024-09-18 13:00:00'),
(NULL,          432156780011, 140000.00, 'NEFT',       'COMPLETED', 'Salary credit Wipro Oct',          '2024-10-01 10:30:00'),
(432156780011,  NULL,          45000.00, 'NEFT',       'COMPLETED', 'Apartment EMI payment',            '2024-10-05 08:30:00'),
(432156780012,  432156780009,  75000.00, 'RTGS',       'COMPLETED', 'Business consulting payment',      '2024-10-15 15:00:00');

-- ── MUTHUKRISHNAN: exporter ───────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780013, 850000.00, 'RTGS',       'COMPLETED', 'Export proceeds - Singapore buyer','2024-09-10 09:00:00'),
(432156780013,  NULL,         400000.00, 'RTGS',       'COMPLETED', 'Raw material import payment',      '2024-09-11 10:00:00'),
(432156780013,  NULL,         200000.00, 'NEFT',       'COMPLETED', 'Customs duty payment',             '2024-09-12 11:00:00'),
(NULL,          432156780013, 720000.00, 'RTGS',       'COMPLETED', 'Export proceeds - Dubai buyer',    '2024-10-14 09:00:00'),
(432156780013,  NULL,         350000.00, 'RTGS',       'COMPLETED', 'Supplier payment',                 '2024-10-15 10:00:00'),
(432156780013,  432156780014,  75000.00, 'TRANSFER',   'COMPLETED', 'Personal transfer',                '2024-10-30 14:00:00'),
(NULL,          432156780013, 960000.00, 'RTGS',       'COMPLETED', 'Export proceeds - UK buyer',       '2024-11-18 09:00:00'),
(432156780013,  NULL,         480000.00, 'RTGS',       'COMPLETED', 'Manufacturing cost payment',       '2024-11-19 10:00:00');

-- ── ARNAB ────────────────────────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780008,  72000.00, 'NEFT',       'COMPLETED', 'Salary credit - Sep',              '2024-09-01 10:00:00'),
(432156780008,  NULL,          22000.00, 'NEFT',       'COMPLETED', 'Rent payment',                     '2024-09-05 09:00:00'),
(432156780008,  NULL,           5000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash',                         '2024-09-20 14:00:00'),
(NULL,          432156780008,  72000.00, 'NEFT',       'COMPLETED', 'Salary credit - Oct',              '2024-10-01 10:00:00'),
(432156780008,  NULL,          22000.00, 'NEFT',       'COMPLETED', 'Rent payment',                     '2024-10-05 09:00:00'),
(NULL,          432156780008,  72000.00, 'NEFT',       'COMPLETED', 'Salary credit - Nov',              '2024-11-01 10:00:00');

-- ── DECEMBER 2024 ─────────────────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Dec 2024',         '2024-12-01 09:05:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent - Dec',                       '2024-12-03 18:30:00'),
(432156780001,  432156780007,  50000.00, 'NEFT',       'COMPLETED', 'Year-end bonus transfer',          '2024-12-20 15:00:00'),
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary Dec - Meera',               '2024-12-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'Home loan EMI - Dec',              '2024-12-05 08:00:00'),
(432156780004,  432156780005,  80000.00, 'TRANSFER',   'COMPLETED', 'Year end transfer to current',     '2024-12-22 12:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary Dec - Rohit',               '2024-12-01 11:00:00'),
(NULL,          432156780011, 140000.00, 'NEFT',       'COMPLETED', 'Salary Dec - Kavitha',             '2024-12-01 10:30:00'),
(NULL,          432156780008,  72000.00, 'NEFT',       'COMPLETED', 'Salary Dec - Arnab',               '2024-12-01 10:00:00'),
(NULL,          432156780009, 610000.00, 'RTGS',       'COMPLETED', 'Client payment Dec - Vikash',      '2024-12-10 10:00:00'),
(NULL,          432156780013, 780000.00, 'RTGS',       'COMPLETED', 'Export proceeds Dec - Muthu',      '2024-12-12 09:00:00');

-- ── JAN–FEB 2025 ──────────────────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary Jan 2025',                  '2025-01-01 09:05:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent Jan',                         '2025-01-03 18:30:00'),
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary Jan - Meera',               '2025-01-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'EMI Jan',                          '2025-01-05 08:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary Jan - Rohit',               '2025-01-01 11:00:00'),
(NULL,          432156780011, 140000.00, 'NEFT',       'COMPLETED', 'Salary Jan - Kavitha',             '2025-01-01 10:30:00'),
(NULL,          432156780001,  85000.00, 'NEFT',       'COMPLETED', 'Salary Feb 2025',                  '2025-02-01 09:05:00'),
(432156780001,  432156780003,  15000.00, 'UPI',        'COMPLETED', 'Rent Feb',                         '2025-02-03 18:30:00'),
(NULL,          432156780004, 120000.00, 'NEFT',       'COMPLETED', 'Salary Feb - Meera',               '2025-02-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT',       'COMPLETED', 'EMI Feb',                          '2025-02-05 08:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT',       'COMPLETED', 'Salary Feb - Rohit',               '2025-02-01 11:00:00'),
(NULL,          432156780011, 140000.00, 'NEFT',       'COMPLETED', 'Salary Feb - Kavitha',             '2025-02-01 10:30:00'),
(NULL,          432156780009, 490000.00, 'RTGS',       'COMPLETED', 'Client payment Jan - Vikash',      '2025-01-08 10:00:00'),
(432156780009,  NULL,         240000.00, 'RTGS',       'COMPLETED', 'Vendor payment Jan',               '2025-01-09 11:00:00'),
(NULL,          432156780013, 820000.00, 'RTGS',       'COMPLETED', 'Export proceeds Jan - Muthu',      '2025-01-14 09:00:00'),
(432156780013,  NULL,         410000.00, 'RTGS',       'COMPLETED', 'Supplier payment Jan',             '2025-01-15 10:00:00');

-- ── NEW CUSTOMERS ─────────────────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780020,  52000.00, 'NEFT',       'COMPLETED', 'First salary - Divya',             '2023-05-01 10:00:00'),
(432156780020,  NULL,           8000.00, 'UPI',        'COMPLETED', 'PG rent payment',                  '2023-05-05 18:00:00'),
(NULL,          432156780020,  52000.00, 'NEFT',       'COMPLETED', 'Salary Jun - Divya',               '2023-06-01 10:00:00'),
(NULL,          432156780020,  56000.00, 'NEFT',       'COMPLETED', 'Salary with increment - Divya',    '2024-01-01 10:00:00'),
(432156780020,  432156780006,  10000.00, 'IMPS',       'COMPLETED', 'Split trip expenses with Rohit',   '2024-09-15 19:00:00'),
(NULL,          432156780021, 200000.00, 'RTGS',       'COMPLETED', 'Investor seed funding',            '2023-07-01 10:00:00'),
(432156780021,  NULL,          80000.00, 'NEFT',       'COMPLETED', 'Office rent payment',              '2023-07-05 09:00:00'),
(NULL,          432156780021, 350000.00, 'RTGS',       'COMPLETED', 'Series A funding tranche 1',       '2024-03-15 10:00:00'),
(432156780021,  NULL,         120000.00, 'RTGS',       'COMPLETED', 'Developer salaries',               '2024-03-20 11:00:00'),
(NULL,          432156780022,  25000.00, 'NEFT',       'COMPLETED', 'NGO donation - anonymous',         '2023-09-10 10:00:00'),
(NULL,          432156780022,  40000.00, 'NEFT',       'COMPLETED', 'NGO donation - Tata Trust',        '2023-12-01 10:00:00'),
(NULL,          432156780022,  30000.00, 'NEFT',       'COMPLETED', 'NGO donation - anonymous',         '2024-06-15 10:00:00'),
(432156780022,  NULL,          15000.00, 'NEFT',       'COMPLETED', 'Field worker salaries',            '2024-06-20 11:00:00');

-- ============================================================
-- AML PATTERN 1: STRUCTURING — Rajesh (rajesh80)
-- 5 transactions on same day, each below ₹2 lakh, total ₹9 lakh
-- ============================================================
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(432156780015, 432156780003, 180000.00, 'IMPS', 'COMPLETED', 'Business payment 1', '2024-10-15 09:10:00'),
(432156780015, 432156780006, 190000.00, 'IMPS', 'COMPLETED', 'Business payment 2', '2024-10-15 10:25:00'),
(432156780015, 432156780008, 175000.00, 'IMPS', 'COMPLETED', 'Business payment 3', '2024-10-15 11:40:00'),
(432156780015, 432156780007, 185000.00, 'IMPS', 'COMPLETED', 'Business payment 4', '2024-10-15 13:15:00'),
(432156780015, 432156780004, 170000.00, 'IMPS', 'COMPLETED', 'Business payment 5', '2024-10-15 14:50:00');

-- AML PATTERN 2: LARGE TRANSACTION — Rajesh (BLOCKED)
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(432156780016, 432156780009, 1200000.00, 'RTGS', 'BLOCKED', 'BLOCKED by FinGuard AML - large txn', '2024-11-02 10:00:00');

-- AML PATTERN 3: RAPID MOVEMENT / LAYERING — Sanjay (sanjay77)
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780017, 500000.00, 'RTGS', 'COMPLETED', 'Incoming wire - unknown source',  '2024-10-20 09:00:00'),
(432156780017,  432156780015, 200000.00, 'IMPS', 'COMPLETED', 'Immediate transfer out 1',        '2024-10-20 10:30:00'),
(432156780017,  432156780019, 180000.00, 'IMPS', 'COMPLETED', 'Immediate transfer out 2',        '2024-10-20 11:00:00'),
(432156780017,  432156780016,  90000.00, 'IMPS', 'COMPLETED', 'Immediate transfer out 3',        '2024-10-20 11:45:00');

-- AML PATTERN 4: STRUCTURING — Sanjay (November)
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780017, 600000.00, 'RTGS', 'COMPLETED', 'Incoming wire - November',        '2024-11-10 09:00:00'),
(432156780017,  432156780003,  95000.00, 'IMPS', 'COMPLETED', 'Split transfer 1',                '2024-11-10 10:00:00'),
(432156780017,  432156780004,  98000.00, 'IMPS', 'COMPLETED', 'Split transfer 2',                '2024-11-10 10:45:00'),
(432156780017,  432156780006,  97000.00, 'IMPS', 'COMPLETED', 'Split transfer 3',                '2024-11-10 11:30:00'),
(432156780017,  432156780008,  96000.00, 'IMPS', 'COMPLETED', 'Split transfer 4',                '2024-11-10 12:15:00'),
(432156780017,  432156780020,  94000.00, 'IMPS', 'COMPLETED', 'Split transfer 5',                '2024-11-10 13:00:00'),
(432156780017,  432156780007,  99000.00, 'IMPS', 'COMPLETED', 'Split transfer 6',                '2024-11-10 14:00:00');

-- AML PATTERN 5: ROUND TRIPPING — Pradeep (pradeep82)
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780019, 800000.00, 'RTGS', 'COMPLETED', 'Incoming transfer - shell company','2024-10-05 09:00:00'),
(432156780019,  432156780016, 400000.00, 'RTGS', 'COMPLETED', 'Transfer to associate',           '2024-10-05 09:30:00'),
(432156780019,  432156780018, 380000.00, 'RTGS', 'COMPLETED', 'Transfer to partner',             '2024-10-05 10:00:00'),
(432156780016,  432156780019, 395000.00, 'RTGS', 'COMPLETED', 'Transfer back - round trip',      '2024-10-06 09:00:00'),
(432156780018,  432156780019, 375000.00, 'RTGS', 'COMPLETED', 'Transfer back - round trip',      '2024-10-06 10:00:00');

-- AML PATTERN 6: VELOCITY SPIKE — Pooja (pooja95)
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(432156780007, 432156780004, 350000.00, 'NEFT', 'COMPLETED', 'Unusual large payment to Meera',  '2025-02-15 14:00:00');

-- ── MARCH 2025 ────────────────────────────────────────────────
INSERT INTO Transaction (from_account_no, to_account_no, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL,          432156780001,  85000.00, 'NEFT', 'COMPLETED', 'Salary Mar 2025 - Ananya',        '2025-03-01 09:05:00'),
(432156780001,  432156780003,  15000.00, 'UPI',  'COMPLETED', 'Rent Mar - Ananya to Suresh',     '2025-03-03 18:30:00'),
(NULL,          432156780004, 120000.00, 'NEFT', 'COMPLETED', 'Salary Mar - Meera',              '2025-03-01 10:00:00'),
(432156780004,  NULL,          42500.00, 'NEFT', 'COMPLETED', 'Home loan EMI Mar',               '2025-03-05 08:00:00'),
(NULL,          432156780006,  95000.00, 'NEFT', 'COMPLETED', 'Salary Mar - Rohit',              '2025-03-01 11:00:00'),
(432156780006,  432156780020,  20000.00, 'UPI',  'COMPLETED', 'Payment to Divya',                '2025-03-08 17:00:00'),
(NULL,          432156780011, 140000.00, 'NEFT', 'COMPLETED', 'Salary Mar - Kavitha',            '2025-03-01 10:30:00'),
(432156780011,  NULL,          45000.00, 'NEFT', 'COMPLETED', 'Apartment EMI Mar',               '2025-03-05 08:30:00'),
(NULL,          432156780008,  72000.00, 'NEFT', 'COMPLETED', 'Salary Mar - Arnab',              '2025-03-01 10:00:00'),
(NULL,          432156780009, 560000.00, 'RTGS', 'COMPLETED', 'Client payment Mar - Vikash',     '2025-03-05 10:00:00'),
(432156780009,  NULL,         300000.00, 'RTGS', 'COMPLETED', 'Vendor payment Mar - Vikash',     '2025-03-06 11:00:00'),
(NULL,          432156780013, 890000.00, 'RTGS', 'COMPLETED', 'Export proceeds Mar - Muthu',     '2025-03-10 09:00:00'),
(432156780013,  NULL,         445000.00, 'RTGS', 'COMPLETED', 'Supplier payment Mar',            '2025-03-11 10:00:00'),
(NULL,          432156780021, 180000.00, 'NEFT', 'COMPLETED', 'Revenue - Senthil startup Mar',   '2025-03-07 10:00:00'),
(432156780021,  NULL,          90000.00, 'NEFT', 'COMPLETED', 'Team salaries Mar - Senthil',     '2025-03-10 11:00:00');

-- ============================================================
-- STEP 6: AML ALERTS — short, simple descriptions
-- ============================================================
INSERT INTO Alert (alert_no, transaction_id, customer_id, alert_type, severity, description, status, alert_timestamp) VALUES

(1, NULL, 'rajesh80', 'STRUCTURING', 'CRITICAL',
 'On 15 Oct 2024, account 432156780015 made 5 transactions totaling ₹9,00,000, each below ₹2,00,000 to avoid detection. Classic structuring/smurfing pattern.',
 'OPEN', '2024-10-15 15:05:00'),

(2, NULL, 'rajesh80', 'LARGE_TRANSACTION', 'CRITICAL',
 'On 02 Nov 2024, account 432156780016 attempted a ₹12,00,000 RTGS transfer — above the ₹10,00,000 limit. Transaction was BLOCKED and account suspended.',
 'OPEN', '2024-11-02 10:01:00'),

(3, NULL, 'sanjay77', 'RAPID_MOVEMENT', 'CRITICAL',
 'On 20 Oct 2024, account 432156780017 received ₹5,00,000 and moved out 94% (₹4,70,000) to 3 accounts within 3 hours. Possible money laundering (layering).',
 'UNDER_REVIEW', '2024-10-20 12:00:00'),

(4, NULL, 'sanjay77', 'STRUCTURING', 'CRITICAL',
 'On 10 Nov 2024, account 432156780017 made 6 transfers totaling ₹5,79,000, each kept between ₹94,000–₹99,000 to stay below ₹1,00,000. Structuring confirmed.',
 'OPEN', '2024-11-10 14:15:00'),

(5, NULL, 'pradeep82', 'RAPID_MOVEMENT', 'CRITICAL',
 'On 05–06 Oct 2024, ₹8,00,000 was received in account 432156780019, split to two accounts, then returned within 24 hours. Round-trip detected.',
 'OPEN', '2024-10-06 11:00:00'),

(6, NULL, 'pradeep82', 'DORMANT_ACTIVATED', 'HIGH',
 'Account 432156780019 had no activity for 60+ days before receiving ₹8,00,000 on 05 Oct 2024. Sudden large inflow on a dormant account — possible mule.',
 'UNDER_REVIEW', '2024-10-05 09:05:00'),

(7, NULL, 'pooja95', 'VELOCITY_SPIKE', 'MEDIUM',
 'On 15 Feb 2025, customer pooja95 transferred ₹3,50,000 — 42x their usual average of ₹8,200. Possible account compromise or unusual activity.',
 'OPEN', '2025-02-15 14:05:00'),

(8, NULL, 'rajesh80', 'DORMANT_ACTIVATED', 'HIGH',
 'Account 432156780016 was inactive for 90+ days before the ₹12,00,000 blocked transfer on 02 Nov 2024. Consistent with a sleeper mule account.',
 'OPEN', '2024-11-02 10:02:00');

-- ============================================================
-- STEP 7: BEHAVIOR PROFILES
-- ============================================================
INSERT INTO Customer_Behavior_Profile
  (customer_id, window_start, window_end, avg_txn_amount, avg_daily_txn_count, avg_monthly_outflow, stddev_txn_amount, total_unique_payees, updated_at) VALUES
('ananya92',   DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  18500.00, 0.5,  25000.00,  8200.00,  4, NOW()),
('suresh85',   DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  10200.00, 0.3,  15000.00,  4500.00,  2, NOW()),
('meera90',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  42000.00, 0.8,  85000.00, 12000.00,  3, NOW()),
('rohit88',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  28000.00, 0.6,  40000.00,  9500.00,  3, NOW()),
('pooja95',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),   8200.00, 0.2,  12000.00,  3800.00,  2, NOW()),
('arnab83',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  16000.00, 0.4,  22000.00,  6200.00,  2, NOW()),
('vikash79',   DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 245000.00, 1.2, 480000.00, 95000.00,  6, NOW()),
('kavitha87',  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  52000.00, 0.7,  90000.00, 18000.00,  4, NOW()),
('muthu75',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 380000.00, 0.9, 760000.00,120000.00,  5, NOW()),
('rajesh80',   DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 195000.00, 2.1, 410000.00, 62000.00,  8, NOW()),
('sanjay77',   DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 168000.00, 1.8, 350000.00, 58000.00,  7, NOW()),
('pradeep82',  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 420000.00, 1.5, 850000.00,145000.00,  5, NOW()),
('divya98',    DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  16000.00, 0.3,  18000.00,  6500.00,  2, NOW()),
('senthil93',  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 120000.00, 0.6, 200000.00, 42000.00,  4, NOW()),
('harpreet91', DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  22000.00, 0.4,  30000.00,  9000.00,  3, NOW());

-- ============================================================
-- STEP 8: DAILY TRANSACTION SUMMARY
-- ============================================================
INSERT INTO Daily_Transaction_Summary (account_no, summary_date, total_debit, total_credit, txn_count, max_single_txn, distinct_payees) VALUES
(432156780001, DATE_SUB(CURDATE(),INTERVAL 10 DAY),  15000.00,  85000.00, 2,  85000.00, 2),
(432156780004, DATE_SUB(CURDATE(),INTERVAL 10 DAY),  42500.00, 120000.00, 2, 120000.00, 1),
(432156780006, DATE_SUB(CURDATE(),INTERVAL 10 DAY),  30000.00,  95000.00, 2,  95000.00, 1),
(432156780009, DATE_SUB(CURDATE(),INTERVAL  8 DAY), 300000.00, 560000.00, 2, 560000.00, 1),
(432156780013, DATE_SUB(CURDATE(),INTERVAL  3 DAY), 445000.00, 890000.00, 2, 890000.00, 1),
(432156780015, '2024-10-15',                        900000.00,       0.00, 5, 190000.00, 5),
(432156780017, '2024-10-20',                        470000.00, 500000.00,  4, 500000.00, 3),
(432156780017, '2024-11-10',                        579000.00, 600000.00,  7, 600000.00, 6),
(432156780019, '2024-10-05',                        780000.00, 800000.00,  3, 800000.00, 2);

-- ============================================================
-- STEP 9: AML BLACKLIST (PAN and NAME only — IP/DEVICE removed)
-- ============================================================
INSERT INTO AML_Blacklist (entity_type, entity_value, reason, added_by, added_at) VALUES
('PAN',    'XYZRJ9999Z', 'Linked to hawala network - RBI watchlist 2023',  'priya03',   '2023-06-01 10:00:00'),
('PAN',    'ABCFK0000X', 'Shell company director under ED investigation',   'priya03',   '2024-08-10 10:00:00'),
('NAME',   'Shell Corp India Ltd', 'Known front company for money laundering', 'karthik04','2024-03-20 10:00:00');

-- ============================================================
-- STEP 10: AUDIT LOG
-- ============================================================
INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, old_values, new_values, logged_at) VALUES
('Account', 'UPDATE', '432156780015', 'priya03',   '{"status":"ACTIVE"}', '{"status":"SUSPENDED","reason":"AML structuring alert 1","actioned_by":"Priya Rajan"}',  '2024-10-15 16:00:00'),
('Account', 'UPDATE', '432156780016', 'priya03',   '{"status":"ACTIVE"}', '{"status":"FROZEN","reason":"AML large transaction block alert 2","actioned_by":"Priya Rajan"}', '2024-11-02 11:00:00'),
('Account', 'UPDATE', '432156780017', 'karthik04', '{"status":"ACTIVE"}', '{"status":"SUSPENDED","reason":"AML layering alert 3","actioned_by":"Karthik Sundar"}',  '2024-10-20 13:00:00'),
('Account', 'UPDATE', '432156780018', 'karthik04', '{"status":"ACTIVE"}', '{"status":"FROZEN","reason":"AML structuring alert 4","actioned_by":"Karthik Sundar"}',  '2024-11-10 15:00:00'),
('Account', 'UPDATE', '432156780019', 'priya03',   '{"status":"ACTIVE"}', '{"status":"SUSPENDED","reason":"AML round-trip alert 5","actioned_by":"Priya Rajan"}',   '2024-10-06 12:00:00'),
('Customer','UPDATE', 'rajesh80',     'priya03',   '{"risk_score":20,"is_flagged":0}', '{"risk_score":78,"is_flagged":1,"reason":"Multiple AML alerts","actioned_by":"Priya Rajan"}',      '2024-11-02 11:30:00'),
('Customer','UPDATE', 'sanjay77',     'karthik04', '{"risk_score":15,"is_flagged":0}', '{"risk_score":82,"is_flagged":1,"reason":"Structuring + layering","actioned_by":"Karthik Sundar"}','2024-11-10 15:30:00'),
('Customer','UPDATE', 'pradeep82',    'priya03',   '{"risk_score":10,"is_flagged":0}', '{"risk_score":91,"is_flagged":1,"reason":"Round-tripping detected","actioned_by":"Priya Rajan"}',  '2024-10-06 12:30:00'),
('Alert',   'UPDATE', '3',            'karthik04', '{"status":"OPEN"}', '{"status":"UNDER_REVIEW","assigned_to":"karthik04"}', '2024-10-22 09:00:00'),
('Alert',   'UPDATE', '6',            'priya03',   '{"status":"OPEN"}', '{"status":"UNDER_REVIEW","assigned_to":"priya03"}',   '2024-10-07 10:00:00');

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STEP 11: RECREATE overdraft trigger (fixed version)
-- ============================================================
DELIMITER $$
CREATE TRIGGER trg_prevent_overdraft
BEFORE INSERT ON Transaction
FOR EACH ROW
BEGIN
    DECLARE v_balance   DECIMAL(15,2);
    DECLARE v_status    ENUM('ACTIVE','FROZEN','CLOSED','SUSPENDED');
    DECLARE v_daily_out DECIMAL(15,2);
    DECLARE v_limit     DECIMAL(15,2);

    IF NEW.transaction_status NOT IN ('BLOCKED','FAILED') AND NEW.from_account_no IS NOT NULL THEN
        SELECT balance, status, daily_limit
        INTO   v_balance, v_status, v_limit
        FROM Account WHERE account_no = NEW.from_account_no;

        IF v_status != 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account is not active. Transaction rejected.';
        END IF;

        IF v_balance < NEW.amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient balance. Transaction rejected.';
        END IF;

        SELECT COALESCE(SUM(amount),0) INTO v_daily_out
        FROM Transaction
        WHERE from_account_no = NEW.from_account_no
          AND DATE(transaction_timestamp) = CURDATE()
          AND transaction_status IN ('COMPLETED','PENDING');

        IF (v_daily_out + NEW.amount) > v_limit THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Daily transaction limit exceeded. Transaction rejected.';
        END IF;
    END IF;
END$$
DELIMITER ;

SELECT CONCAT(
  '✅ FinGuard seed complete! ',
  (SELECT COUNT(*) FROM Customer),    ' customers | ',
  (SELECT COUNT(*) FROM Account),     ' accounts | ',
  (SELECT COUNT(*) FROM Transaction), ' transactions | ',
  (SELECT COUNT(*) FROM Alert),       ' AML alerts | ',
  (SELECT COUNT(*) FROM Employee),    ' employees'
) AS status;