-- ============================================================
--  FinGuard National Bank — FULL REALISTIC SEED DATA
--  Indian banking context | 6 months of history
--  Includes: 15 customers, 22 accounts, 120+ transactions
--  AML patterns: structuring, layering, large txns, velocity spikes
--  Run AFTER bank_oltp_schema_fixed.sql
-- ============================================================

USE finguard_bank;

-- Disable FK checks so we can delete in any order
SET FOREIGN_KEY_CHECKS = 0;

-- Temporarily disable overdraft trigger for historical data loading
DROP TRIGGER IF EXISTS trg_prevent_overdraft;

-- ============================================================
-- STEP 1: BRANCHES (3 cities)
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
INSERT INTO Branch (branch_id, bank_id, branch_name, IFSC_code, city, state) VALUES
(1, 1, 'T. Nagar Branch',        'FGNB0001001', 'Chennai',   'Tamil Nadu'),
(2, 1, 'Andheri West Branch',    'FGNB0002001', 'Mumbai',    'Maharashtra'),
(3, 1, 'Koramangala Branch',     'FGNB0003001', 'Bangalore', 'Karnataka'),
(4, 1, 'Connaught Place Branch', 'FGNB0004001', 'New Delhi', 'Delhi'),
(5, 1, 'Salt Lake Branch',       'FGNB0005001', 'Kolkata',   'West Bengal');

-- ============================================================
-- STEP 2: EMPLOYEES (managers, analysts per branch)
-- ============================================================
-- employees cleared above
-- Password: manager123 → bcrypt hash (pre-computed)
INSERT INTO Employee (employee_id, branch_id, name, role, salary, joining_date, email, password_hash) VALUES
(1, 1, 'Arjun Mehta',       'BRANCH_MANAGER',     125000, '2018-04-01', 'arjun.mehta@fgnb.in',       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(2, 2, 'Sunita Patel',      'BRANCH_MANAGER',     118000, '2017-08-15', 'sunita.patel@fgnb.in',      '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(3, 1, 'Priya Rajan',       'COMPLIANCE_OFFICER',  95000, '2019-07-15', 'priya.rajan@fgnb.in',       '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(4, 2, 'Karthik Sundar',    'AML_ANALYST',         88000, '2021-01-10', 'karthik.sundar@fgnb.in',    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(5, 3, 'Deepa Nair',        'BRANCH_MANAGER',     115000, '2020-03-20', 'deepa.nair@fgnb.in',        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(6, 4, 'Vikram Singh',      'BRANCH_MANAGER',     122000, '2016-11-01', 'vikram.singh@fgnb.in',      '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa'),
(7, 5, 'Ritika Banerjee',   'AML_ANALYST',         91000, '2022-06-05', 'ritika.banerjee@fgnb.in',   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa');

-- ============================================================
-- STEP 3: CUSTOMERS (15 customers — mix of normal + suspicious)
-- password_hash = bcrypt('password123')
-- ============================================================
-- customers cleared above
INSERT INTO Customer (customer_id, branch_id, full_name, email, phone, address, city, DOB, PAN_number, risk_score, is_flagged, password_hash, created_at) VALUES

-- NORMAL CUSTOMERS (low risk, regular salary + household transactions)
(1,  1, 'Ananya Krishnamurthy', 'ananya.k@gmail.com',    '9841234567', '14, 3rd Cross, T Nagar',        'Chennai',   '1992-05-14', 'ABCPK1234H', 8,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2021-03-10 10:00:00'),
(2,  1, 'Suresh Babu',          'suresh.babu@yahoo.com', '9841987654', '22, Gandhi Nagar, Adyar',        'Chennai',   '1985-09-22', 'ABCPS5678D', 5,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2020-07-15 09:30:00'),
(3,  2, 'Meera Desai',          'meera.desai@gmail.com', '9920345678', '8B, Lokhandwala Complex, Andheri','Mumbai',   '1990-03-30', 'BCDQM2345F', 12, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2021-01-20 11:00:00'),
(4,  3, 'Rohit Sharma',         'rohit.s@hotmail.com',   '9845678901', '45, Koramangala 5th Block',      'Bangalore', '1988-12-05', 'CDERS3456G', 7,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2019-11-05 14:00:00'),
(5,  4, 'Pooja Verma',          'pooja.v@gmail.com',     '9811223344', '12, Lajpat Nagar II',            'New Delhi', '1995-07-18', 'DEFPV4567H', 4,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2022-02-14 10:30:00'),
(6,  5, 'Arnab Chatterjee',     'arnab.c@gmail.com',     '9830112233', '3, Bidhan Nagar, Salt Lake',     'Kolkata',   '1983-11-28', 'EFGAC5678J', 6,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2020-05-01 09:00:00'),

-- MEDIUM RISK (business owners, high-value but legitimate)
(7,  2, 'Vikash Agarwal',       'vikash.a@business.com', '9833445566', '501, Nariman Point Office',      'Mumbai',    '1979-04-10', 'FGHVA6789K', 28, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2019-08-20 10:00:00'),
(8,  3, 'Kavitha Reddy',        'kavitha.r@techcorp.in', '9845901234', '22, Whitefield Main Road',       'Bangalore', '1987-06-15', 'GHIKR7890L', 22, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2020-01-10 11:30:00'),
(9,  1, 'Muthukrishnan Pillai', 'muthu.p@export.com',    '9841456789', '7, Nungambakkam High Road',      'Chennai',   '1975-02-20', 'HIJKM8901M', 35, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2018-06-15 09:00:00'),

-- HIGH RISK / FLAGGED (AML patterns)
(10, 2, 'Rajesh Venkataraman',  'rajesh.v@trade.com',    '9820567890', '45, Linking Road, Bandra',       'Mumbai',    '1980-08-15', 'IJKLR9012N', 78, 1, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2021-09-01 10:00:00'),
(11, 4, 'Sanjay Malhotra',      'sanjay.m@trade.net',    '9810678901', '88, Connaught Place',            'New Delhi', '1977-03-12', 'JKLSM0123P', 82, 1, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2021-05-10 10:00:00'),
(12, 5, 'Pradeep Ghosh',        'pradeep.g@shell.com',   '9831789012', '14, Park Street',                'Kolkata',   '1982-07-25', 'KLMPG1234Q', 91, 1, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2022-01-15 10:00:00'),

-- NEW / RECENT CUSTOMERS
(13, 3, 'Divya Menon',          'divya.m@gmail.com',     '9845234567', '18, Indiranagar 100ft Road',     'Bangalore', '1998-01-10', 'LMNDI2345R', 3,  0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2023-04-01 10:00:00'),
(14, 1, 'Senthil Kumar',        'senthil.k@startup.io',  '9841345678', '31, Anna Salai',                 'Chennai',   '1993-09-05', 'MNOSE3456S', 15, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2023-06-15 10:00:00'),
(15, 2, 'Harpreet Kaur',        'harpreet.k@ngo.org',    '9820456789', '9, Juhu Scheme Road',            'Mumbai',    '1991-12-20', 'NOPHK4567T', 10, 0, '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', '2023-08-20 10:00:00');

-- ============================================================
-- STEP 4: ACCOUNTS (22 accounts across all customers)
-- ============================================================
-- accounts cleared above
INSERT INTO Account (account_id, customer_id, branch_id, account_type, balance, daily_limit, status, created_at) VALUES
-- Ananya (customer 1) — salary account + savings
(101, 1,  1, 'SAVINGS',       142500.00, 100000, 'ACTIVE',    '2021-03-10 10:00:00'),
(102, 1,  1, 'FIXED_DEPOSIT', 500000.00, 50000,  'ACTIVE',    '2022-01-01 10:00:00'),

-- Suresh (customer 2)
(103, 2,  1, 'SAVINGS',        67800.50, 100000, 'ACTIVE',    '2020-07-15 09:30:00'),

-- Meera (customer 3)
(104, 3,  2, 'SAVINGS',       215000.00, 200000, 'ACTIVE',    '2021-01-20 11:00:00'),
(105, 3,  2, 'CURRENT',       380000.00, 500000, 'ACTIVE',    '2021-06-01 11:00:00'),

-- Rohit (customer 4)
(106, 4,  3, 'SAVINGS',       128400.75, 200000, 'ACTIVE',    '2019-11-05 14:00:00'),

-- Pooja (customer 5)
(107, 5,  4, 'SAVINGS',        54200.00, 100000, 'ACTIVE',    '2022-02-14 10:30:00'),

-- Arnab (customer 6)
(108, 6,  5, 'SAVINGS',        93600.00, 150000, 'ACTIVE',    '2020-05-01 09:00:00'),

-- Vikash — business (customer 7)
(109, 7,  2, 'CURRENT',      1250000.00, 1000000,'ACTIVE',    '2019-08-20 10:00:00'),
(110, 7,  2, 'SAVINGS',       340000.00, 500000, 'ACTIVE',    '2020-03-15 10:00:00'),

-- Kavitha (customer 8)
(111, 8,  3, 'SAVINGS',       287500.00, 300000, 'ACTIVE',    '2020-01-10 11:30:00'),
(112, 8,  3, 'CURRENT',       620000.00, 700000, 'ACTIVE',    '2021-07-01 11:00:00'),

-- Muthukrishnan — exporter (customer 9)
(113, 9,  1, 'CURRENT',      2100000.00, 2000000,'ACTIVE',    '2018-06-15 09:00:00'),
(114, 9,  1, 'SAVINGS',       175000.00, 200000, 'ACTIVE',    '2019-01-01 09:00:00'),

-- Rajesh — HIGH RISK (customer 10)
(115, 10, 2, 'SAVINGS',        22000.00, 200000, 'SUSPENDED', '2021-09-01 10:00:00'),
(116, 10, 2, 'CURRENT',             0.00,500000, 'FROZEN',    '2021-11-01 10:00:00'),

-- Sanjay — HIGH RISK (customer 11)
(117, 11, 4, 'SAVINGS',        18500.00, 200000, 'SUSPENDED', '2021-05-10 10:00:00'),
(118, 11, 4, 'CURRENT',             0.00,500000, 'FROZEN',    '2021-08-01 10:00:00'),

-- Pradeep — CRITICAL RISK (customer 12)
(119, 12, 5, 'SAVINGS',             0.00,200000, 'SUSPENDED', '2022-01-15 10:00:00'),

-- Divya (customer 13) — young professional
(120, 13, 3, 'SAVINGS',        38900.00, 100000, 'ACTIVE',    '2023-04-01 10:00:00'),

-- Senthil (customer 14) — startup founder
(121, 14, 1, 'CURRENT',       450000.00, 500000, 'ACTIVE',    '2023-06-15 10:00:00'),

-- Harpreet (customer 15) — NGO
(122, 15, 2, 'SAVINGS',       125000.00, 200000, 'ACTIVE',    '2023-08-20 10:00:00');

-- ============================================================
-- STEP 5: TRANSACTIONS — 6 months of realistic data
-- Normal daily banking + suspicious AML patterns
-- ============================================================
-- transactions cleared above

-- ── NORMAL TRANSACTIONS (Sep–Nov 2024) ──────────────────────────

-- Ananya: monthly salary credits + routine payments
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Sept 2024',          '2024-09-01 09:15:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',             '2024-09-03 18:30:00'),
(101,  NULL, 3000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',                '2024-09-07 11:00:00'),
(101,  107, 12000.00, 'IMPS',       'COMPLETED', 'Friends trip contribution',          '2024-09-14 20:15:00'),
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Oct 2024',           '2024-10-01 09:10:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',             '2024-10-03 18:45:00'),
(101,  NULL, 5000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',                '2024-10-10 12:00:00'),
(101,  106, 25000.00, 'NEFT',       'COMPLETED', 'Loan repayment to Rohit',            '2024-10-20 14:00:00'),
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Nov 2024',           '2024-11-01 09:05:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent payment to Suresh',             '2024-11-03 19:00:00'),
(101,  NULL, 4000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM cash withdrawal',                '2024-11-12 10:30:00'),
(101,  104,  8500.00, 'UPI',        'COMPLETED', 'Split bill - Meera',                 '2024-11-22 21:00:00');

-- Suresh: rent income + expenses
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 103, 15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',          '2024-09-03 18:31:00'),
(103,  NULL, 8000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                     '2024-09-08 10:00:00'),
(103,  107, 5000.00,  'UPI',        'COMPLETED', 'Transferred to Pooja',               '2024-09-20 16:00:00'),
(NULL, 103, 15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',          '2024-10-03 18:46:00'),
(103,  NULL, 6000.00, 'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                     '2024-10-09 11:00:00'),
(NULL, 103, 15000.00, 'UPI',        'COMPLETED', 'Rent received from Ananya',          '2024-11-03 19:01:00');

-- Meera (Mumbai): IT salary + home loan EMI
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 104, 120000.00, 'NEFT',      'COMPLETED', 'Salary credit TechCorp Sep',         '2024-09-01 10:00:00'),
(104,  NULL, 42500.00, 'NEFT',      'COMPLETED', 'Home loan EMI - HDFC',               '2024-09-05 08:00:00'),
(104,  NULL,  8000.00, 'WITHDRAWAL','COMPLETED', 'Cash withdrawal',                    '2024-09-15 12:00:00'),
(NULL, 104, 120000.00, 'NEFT',      'COMPLETED', 'Salary credit TechCorp Oct',         '2024-10-01 10:00:00'),
(104,  NULL, 42500.00, 'NEFT',      'COMPLETED', 'Home loan EMI - HDFC',               '2024-10-05 08:00:00'),
(104,  105,  50000.00, 'TRANSFER',  'COMPLETED', 'Transfer to current account',        '2024-10-18 14:00:00'),
(NULL, 104, 120000.00, 'NEFT',      'COMPLETED', 'Salary credit TechCorp Nov',         '2024-11-01 10:00:00'),
(104,  NULL, 42500.00, 'NEFT',      'COMPLETED', 'Home loan EMI - HDFC',               '2024-11-05 08:00:00');

-- Rohit (Bangalore): software engineer
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Sep',          '2024-09-01 11:00:00'),
(106,  NULL, 30000.00,'NEFT',       'COMPLETED', 'House rent paid',                    '2024-09-04 09:00:00'),
(106,  NULL, 10000.00,'WITHDRAWAL', 'COMPLETED', 'ATM withdrawal',                     '2024-09-12 14:00:00'),
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Oct',          '2024-10-01 11:00:00'),
(106,  NULL, 30000.00,'NEFT',       'COMPLETED', 'House rent paid',                    '2024-10-04 09:00:00'),
(106,  111,  20000.00,'IMPS',       'COMPLETED', 'Payment to Kavitha',                 '2024-10-25 17:00:00'),
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary credit Infosys Nov',          '2024-11-01 11:00:00'),
(106,  NULL, 30000.00,'NEFT',       'COMPLETED', 'House rent paid',                    '2024-11-04 09:00:00');

-- Vikash (Mumbai) — business transactions, larger amounts
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 109, 450000.00,'RTGS',       'COMPLETED', 'Client payment received - Sharma Co','2024-09-05 10:00:00'),
(109,  NULL,250000.00,'RTGS',       'COMPLETED', 'Vendor payment - Raw materials',     '2024-09-06 11:00:00'),
(109,  110,  80000.00,'TRANSFER',   'COMPLETED', 'Transfer to savings',                '2024-09-10 14:00:00'),
(NULL, 109, 380000.00,'RTGS',       'COMPLETED', 'Client payment received - Verma Ltd','2024-10-08 10:00:00'),
(109,  NULL,200000.00,'RTGS',       'COMPLETED', 'Vendor payment - supplies',          '2024-10-09 11:00:00'),
(109,  NULL,150000.00,'NEFT',       'COMPLETED', 'GST payment to government',          '2024-10-20 09:00:00'),
(NULL, 109, 520000.00,'RTGS',       'COMPLETED', 'Client payment - Nov project',       '2024-11-07 10:00:00'),
(109,  NULL,280000.00,'RTGS',       'COMPLETED', 'Vendor payment - Nov supplies',      '2024-11-08 11:00:00');

-- Kavitha (Bangalore) — senior developer
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 111, 140000.00,'NEFT',       'COMPLETED', 'Salary credit Wipro Sep',            '2024-09-01 10:30:00'),
(111,  NULL, 45000.00,'NEFT',       'COMPLETED', 'Apartment EMI payment',              '2024-09-05 08:30:00'),
(111,  NULL, 12000.00,'WITHDRAWAL', 'COMPLETED', 'Cash withdrawal',                    '2024-09-18 13:00:00'),
(NULL, 111, 140000.00,'NEFT',       'COMPLETED', 'Salary credit Wipro Oct',            '2024-10-01 10:30:00'),
(111,  NULL, 45000.00,'NEFT',       'COMPLETED', 'Apartment EMI payment',              '2024-10-05 08:30:00'),
(112,  109,  75000.00,'RTGS',       'COMPLETED', 'Business consulting payment',        '2024-10-15 15:00:00');

-- Muthukrishnan (Chennai) — exporter, large but legitimate
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 113, 850000.00,'RTGS',       'COMPLETED', 'Export proceeds - Singapore buyer',  '2024-09-10 09:00:00'),
(113,  NULL,400000.00,'RTGS',       'COMPLETED', 'Raw material import payment',        '2024-09-11 10:00:00'),
(113,  NULL,200000.00,'NEFT',       'COMPLETED', 'Customs duty payment',               '2024-09-12 11:00:00'),
(NULL, 113, 720000.00,'RTGS',       'COMPLETED', 'Export proceeds - Dubai buyer',      '2024-10-14 09:00:00'),
(113,  NULL,350000.00,'RTGS',       'COMPLETED', 'Supplier payment',                   '2024-10-15 10:00:00'),
(113,  114,  75000.00,'TRANSFER',   'COMPLETED', 'Personal transfer',                  '2024-10-30 14:00:00'),
(NULL, 113, 960000.00,'RTGS',       'COMPLETED', 'Export proceeds - UK buyer',         '2024-11-18 09:00:00'),
(113,  NULL,480000.00,'RTGS',       'COMPLETED', 'Manufacturing cost payment',         '2024-11-19 10:00:00');

-- Arnab (Kolkata)
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 108,  72000.00,'NEFT',       'COMPLETED', 'Salary credit - Sep',                '2024-09-01 10:00:00'),
(108,  NULL, 22000.00,'NEFT',       'COMPLETED', 'Rent payment',                       '2024-09-05 09:00:00'),
(108,  NULL,  5000.00,'WITHDRAWAL', 'COMPLETED', 'ATM cash',                           '2024-09-20 14:00:00'),
(NULL, 108,  72000.00,'NEFT',       'COMPLETED', 'Salary credit - Oct',                '2024-10-01 10:00:00'),
(108,  NULL, 22000.00,'NEFT',       'COMPLETED', 'Rent payment',                       '2024-10-05 09:00:00'),
(NULL, 108,  72000.00,'NEFT',       'COMPLETED', 'Salary credit - Nov',                '2024-11-01 10:00:00');

-- ── DECEMBER 2024 — NORMAL CONTINUED ────────────────────────────
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary credit - Dec 2024',           '2024-12-01 09:05:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent - Dec',                         '2024-12-03 18:30:00'),
(101,  107, 50000.00, 'NEFT',       'COMPLETED', 'Year-end bonus transfer',            '2024-12-20 15:00:00'),
(NULL, 104, 120000.00,'NEFT',       'COMPLETED', 'Salary Dec - Meera',                 '2024-12-01 10:00:00'),
(104,  NULL, 42500.00,'NEFT',       'COMPLETED', 'Home loan EMI - Dec',                '2024-12-05 08:00:00'),
(104,  105,  80000.00,'TRANSFER',   'COMPLETED', 'Year end transfer to current',       '2024-12-22 12:00:00'),
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary Dec - Rohit',                 '2024-12-01 11:00:00'),
(NULL, 111, 140000.00,'NEFT',       'COMPLETED', 'Salary Dec - Kavitha',               '2024-12-01 10:30:00'),
(NULL, 108,  72000.00,'NEFT',       'COMPLETED', 'Salary Dec - Arnab',                 '2024-12-01 10:00:00'),
(NULL, 109, 610000.00,'RTGS',       'COMPLETED', 'Client payment Dec - Vikash',        '2024-12-10 10:00:00'),
(NULL, 113, 780000.00,'RTGS',       'COMPLETED', 'Export proceeds Dec - Muthu',        '2024-12-12 09:00:00');

-- ── JAN–FEB 2025 — NORMAL CONTINUED ─────────────────────────────
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary Jan 2025',                    '2025-01-01 09:05:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent Jan',                           '2025-01-03 18:30:00'),
(NULL, 104, 120000.00,'NEFT',       'COMPLETED', 'Salary Jan - Meera',                 '2025-01-01 10:00:00'),
(104,  NULL, 42500.00,'NEFT',       'COMPLETED', 'EMI Jan',                            '2025-01-05 08:00:00'),
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary Jan - Rohit',                 '2025-01-01 11:00:00'),
(NULL, 111, 140000.00,'NEFT',       'COMPLETED', 'Salary Jan - Kavitha',               '2025-01-01 10:30:00'),
(NULL, 101, 85000.00, 'NEFT',       'COMPLETED', 'Salary Feb 2025',                    '2025-02-01 09:05:00'),
(101,  103, 15000.00, 'UPI',        'COMPLETED', 'Rent Feb',                           '2025-02-03 18:30:00'),
(NULL, 104, 120000.00,'NEFT',       'COMPLETED', 'Salary Feb - Meera',                 '2025-02-01 10:00:00'),
(104,  NULL, 42500.00,'NEFT',       'COMPLETED', 'EMI Feb',                            '2025-02-05 08:00:00'),
(NULL, 106, 95000.00, 'NEFT',       'COMPLETED', 'Salary Feb - Rohit',                 '2025-02-01 11:00:00'),
(NULL, 111, 140000.00,'NEFT',       'COMPLETED', 'Salary Feb - Kavitha',               '2025-02-01 10:30:00'),
(NULL, 109, 490000.00,'RTGS',       'COMPLETED', 'Client payment Jan - Vikash',        '2025-01-08 10:00:00'),
(109,  NULL,240000.00,'RTGS',       'COMPLETED', 'Vendor payment Jan',                 '2025-01-09 11:00:00'),
(NULL, 113, 820000.00,'RTGS',       'COMPLETED', 'Export proceeds Jan - Muthu',        '2025-01-14 09:00:00'),
(113,  NULL,410000.00,'RTGS',       'COMPLETED', 'Supplier payment Jan',               '2025-01-15 10:00:00');

-- ── NEW CUSTOMER TRANSACTIONS ─────────────────────────────────────
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
-- Divya (120) — fresh grad, small transactions
(NULL, 120, 52000.00, 'NEFT',       'COMPLETED', 'First salary - Divya',               '2023-05-01 10:00:00'),
(120,  NULL,  8000.00,'UPI',        'COMPLETED', 'PG rent payment',                    '2023-05-05 18:00:00'),
(NULL, 120, 52000.00, 'NEFT',       'COMPLETED', 'Salary Jun - Divya',                 '2023-06-01 10:00:00'),
(NULL, 120, 56000.00, 'NEFT',       'COMPLETED', 'Salary with increment - Divya',      '2024-01-01 10:00:00'),
(120,  106,  10000.00,'IMPS',       'COMPLETED', 'Split trip expenses with Rohit',     '2024-09-15 19:00:00'),
-- Senthil (121) — startup, irregular but growing
(NULL, 121, 200000.00,'RTGS',       'COMPLETED', 'Investor seed funding',              '2023-07-01 10:00:00'),
(121,  NULL, 80000.00,'NEFT',       'COMPLETED', 'Office rent payment',                '2023-07-05 09:00:00'),
(NULL, 121, 350000.00,'RTGS',       'COMPLETED', 'Series A funding tranche 1',         '2024-03-15 10:00:00'),
(121,  NULL,120000.00,'RTGS',       'COMPLETED', 'Developer salaries',                 '2024-03-20 11:00:00'),
-- Harpreet (122) — NGO, regular smaller donations
(NULL, 122,  25000.00,'NEFT',       'COMPLETED', 'NGO donation - anonymous',           '2023-09-10 10:00:00'),
(NULL, 122,  40000.00,'NEFT',       'COMPLETED', 'NGO donation - Tata Trust',          '2023-12-01 10:00:00'),
(NULL, 122,  30000.00,'NEFT',       'COMPLETED', 'NGO donation - anonymous',           '2024-06-15 10:00:00'),
(122,  NULL, 15000.00,'NEFT',       'COMPLETED', 'Field worker salaries',              '2024-06-20 11:00:00');

-- ============================================================
-- AML PATTERN 1: STRUCTURING (Rajesh — customer 10)
-- Splits ₹9.5 lakh across 5 transactions same day
-- Each below ₹2 lakh threshold — classic smurfing
-- ============================================================
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(115, 103, 180000.00,'IMPS',       'COMPLETED', 'Business payment 1',                 '2024-10-15 09:10:00'),
(115, 106, 190000.00,'IMPS',       'COMPLETED', 'Business payment 2',                 '2024-10-15 10:25:00'),
(115, 108, 175000.00,'IMPS',       'COMPLETED', 'Business payment 3',                 '2024-10-15 11:40:00'),
(115, 107, 185000.00,'IMPS',       'COMPLETED', 'Business payment 4',                 '2024-10-15 13:15:00'),
(115, 104, 170000.00,'IMPS',       'COMPLETED', 'Business payment 5',                 '2024-10-15 14:50:00');
-- Total: ₹9,00,000 in 1 day from one account — structuring flag

-- AML PATTERN 2: LARGE TRANSACTION (Rajesh — blocked by AML)
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(116, 109, 1200000.00,'RTGS',      'BLOCKED',   'BLOCKED by FinGuard AML - large txn','2024-11-02 10:00:00');

-- AML PATTERN 3: RAPID MOVEMENT / LAYERING (Sanjay — customer 11)
-- Money arrives and leaves within hours
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 117, 500000.00,'RTGS',      'COMPLETED', 'Incoming wire - unknown source',     '2024-10-20 09:00:00'),
(117,  115, 200000.00,'IMPS',      'COMPLETED', 'Immediate transfer out 1',           '2024-10-20 10:30:00'),
(117,  119, 180000.00,'IMPS',      'COMPLETED', 'Immediate transfer out 2',           '2024-10-20 11:00:00'),
(117,  116, 90000.00, 'IMPS',      'COMPLETED', 'Immediate transfer out 3',           '2024-10-20 11:45:00');
-- 94% of funds moved within 3 hours — layering flag

-- AML PATTERN 4: STRUCTURING (Sanjay — splits again next month)
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 117, 600000.00,'RTGS',      'COMPLETED', 'Incoming wire - November',           '2024-11-10 09:00:00'),
(117,  103,  95000.00,'IMPS',      'COMPLETED', 'Split transfer 1',                   '2024-11-10 10:00:00'),
(117,  104,  98000.00,'IMPS',      'COMPLETED', 'Split transfer 2',                   '2024-11-10 10:45:00'),
(117,  106,  97000.00,'IMPS',      'COMPLETED', 'Split transfer 3',                   '2024-11-10 11:30:00'),
(117,  108,  96000.00,'IMPS',      'COMPLETED', 'Split transfer 4',                   '2024-11-10 12:15:00'),
(117,  120,  94000.00,'IMPS',      'COMPLETED', 'Split transfer 5',                   '2024-11-10 13:00:00'),
(117,  107,  99000.00,'IMPS',      'COMPLETED', 'Split transfer 6',                   '2024-11-10 14:00:00');
-- ₹5,79,000 in 6 transactions same day — structuring

-- AML PATTERN 5: PRADEEP (customer 12) — round tripping
-- Money goes out and comes back through different accounts
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 119, 800000.00,'RTGS',      'COMPLETED', 'Incoming transfer - shell company',  '2024-10-05 09:00:00'),
(119,  116, 400000.00,'RTGS',      'COMPLETED', 'Transfer to associate',              '2024-10-05 09:30:00'),
(119,  118, 380000.00,'RTGS',      'COMPLETED', 'Transfer to partner',                '2024-10-05 10:00:00'),
(116,  119, 395000.00,'RTGS',      'COMPLETED', 'Transfer back - round trip',         '2024-10-06 09:00:00'),
(118,  119, 375000.00,'RTGS',      'COMPLETED', 'Transfer back - round trip',         '2024-10-06 10:00:00');
-- Classic round-tripping pattern

-- AML PATTERN 6: VELOCITY SPIKE (Pooja — customer 5)
-- Normally transacts ₹5–15k, suddenly ₹3.5 lakh
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(107,  104, 350000.00,'NEFT',      'COMPLETED', 'Unusual large payment to Meera',     '2025-02-15 14:00:00');
-- 3 sigma spike above normal behavior

-- ── RECENT MARCH 2025 TRANSACTIONS ───────────────────────────────
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(NULL, 101, 85000.00, 'NEFT',      'COMPLETED', 'Salary Mar 2025 - Ananya',           '2025-03-01 09:05:00'),
(101,  103, 15000.00, 'UPI',       'COMPLETED', 'Rent Mar - Ananya to Suresh',        '2025-03-03 18:30:00'),
(NULL, 104, 120000.00,'NEFT',      'COMPLETED', 'Salary Mar - Meera',                 '2025-03-01 10:00:00'),
(104,  NULL, 42500.00,'NEFT',      'COMPLETED', 'Home loan EMI Mar',                  '2025-03-05 08:00:00'),
(NULL, 106, 95000.00, 'NEFT',      'COMPLETED', 'Salary Mar - Rohit',                 '2025-03-01 11:00:00'),
(106,  120,  20000.00,'UPI',       'COMPLETED', 'Payment to Divya',                   '2025-03-08 17:00:00'),
(NULL, 111, 140000.00,'NEFT',      'COMPLETED', 'Salary Mar - Kavitha',               '2025-03-01 10:30:00'),
(111,  NULL, 45000.00,'NEFT',      'COMPLETED', 'Apartment EMI Mar',                  '2025-03-05 08:30:00'),
(NULL, 108,  72000.00,'NEFT',      'COMPLETED', 'Salary Mar - Arnab',                 '2025-03-01 10:00:00'),
(NULL, 109, 560000.00,'RTGS',      'COMPLETED', 'Client payment Mar - Vikash',        '2025-03-05 10:00:00'),
(109,  NULL,300000.00,'RTGS',      'COMPLETED', 'Vendor payment Mar - Vikash',        '2025-03-06 11:00:00'),
(NULL, 113, 890000.00,'RTGS',      'COMPLETED', 'Export proceeds Mar - Muthu',        '2025-03-10 09:00:00'),
(113,  NULL,445000.00,'RTGS',      'COMPLETED', 'Supplier payment Mar',               '2025-03-11 10:00:00'),
(NULL, 121, 180000.00,'NEFT',      'COMPLETED', 'Revenue - Senthil startup Mar',      '2025-03-07 10:00:00'),
(121,  NULL, 90000.00,'NEFT',      'COMPLETED', 'Team salaries Mar - Senthil',        '2025-03-10 11:00:00');

-- ============================================================
-- STEP 6: AML ALERTS (raised by the AML engine on above patterns)
-- ============================================================
-- alerts cleared above
INSERT INTO Alert (alert_no, transaction_id, customer_id, alert_type, severity, description, status, alert_timestamp) VALUES

(1,  NULL, 10, 'STRUCTURING',       'CRITICAL',
 'STRUCTURING DETECTED: 5 transactions totaling ₹9,00,000 on 2024-10-15 from account 115. Each transaction kept below ₹2,00,000. Classic smurfing pattern to evade reporting thresholds. Customer risk score elevated.',
 'OPEN', '2024-10-15 15:05:00'),

(2,  NULL, 10, 'LARGE_TRANSACTION', 'CRITICAL',
 'LARGE TRANSACTION BLOCKED: ₹12,00,000 RTGS from account 116 to account 109 on 2024-11-02. Exceeds ₹10,00,000 single transaction threshold. Transaction blocked and account suspended pending compliance review.',
 'OPEN', '2024-11-02 10:01:00'),

(3,  NULL, 11, 'RAPID_MOVEMENT',    'CRITICAL',
 'LAYERING DETECTED: ₹5,00,000 received in account 117 at 09:00 and 94% (₹4,70,000) moved out to 3 different accounts within 3 hours. Funds barely touched account. Possible money laundering layering stage.',
 'UNDER_REVIEW', '2024-10-20 12:00:00'),

(4,  NULL, 11, 'STRUCTURING',       'CRITICAL',
 'STRUCTURING DETECTED: 6 transactions totaling ₹5,79,000 on 2024-11-10 from account 117. Transactions range ₹94,000–₹99,000 — deliberately kept below ₹1,00,000 to avoid scrutiny. Consecutive timing pattern confirms smurfing.',
 'OPEN', '2024-11-10 14:15:00'),

(5,  NULL, 12, 'RAPID_MOVEMENT',    'CRITICAL',
 'ROUND-TRIPPING DETECTED: ₹8,00,000 received in account 119, immediately split to accounts 116 and 118, then returned to account 119 within 24 hours. Classic round-trip to create appearance of legitimate transactions.',
 'OPEN', '2024-10-06 11:00:00'),

(6,  NULL, 12, 'VELOCITY_SPIKE',    'HIGH',
 'BEHAVIORAL ANOMALY: Account 119 had zero activity for 60 days before receiving ₹8,00,000 on 2024-10-05. Dormant account suddenly activated with large unexplained inflow. Possible mule account.',
 'UNDER_REVIEW', '2024-10-05 09:05:00'),

(7,  NULL, 5,  'VELOCITY_SPIKE',    'MEDIUM',
 'BEHAVIORAL ANOMALY: Customer 5 (Pooja Verma) made a ₹3,50,000 transfer on 2025-02-15. Average transaction over past 6 months is ₹8,200. This is 42x the average — 4.1 standard deviations above baseline. Possible account compromise.',
 'OPEN', '2025-02-15 14:05:00'),

(8,  NULL, 10, 'DORMANT_ACTIVATED', 'HIGH',
 'DORMANT ACCOUNT: Account 116 (Rajesh Venkataraman) was inactive for 90+ days before the ₹12,00,000 blocked transaction. Pattern consistent with sleeper mule account.',
 'OPEN', '2024-11-02 10:02:00');

-- ============================================================
-- STEP 7: BEHAVIOR PROFILES (60-day rolling window)
-- Used by AML velocity spike detection
-- ============================================================
-- cleared above
INSERT INTO Customer_Behavior_Profile
  (customer_id, window_start, window_end, avg_txn_amount, avg_daily_txn_count, avg_monthly_outflow, stddev_txn_amount, total_unique_payees, updated_at) VALUES
(1,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  18500.00, 0.5,  25000.00,  8200.00,  4,  NOW()),
(2,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  10200.00, 0.3,  15000.00,  4500.00,  2,  NOW()),
(3,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  42000.00, 0.8,  85000.00,  12000.00, 3,  NOW()),
(4,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  28000.00, 0.6,  40000.00,  9500.00,  3,  NOW()),
(5,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),   8200.00, 0.2,  12000.00,  3800.00,  2,  NOW()),
(6,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  16000.00, 0.4,  22000.00,  6200.00,  2,  NOW()),
(7,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 245000.00, 1.2, 480000.00, 95000.00,  6,  NOW()),
(8,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  52000.00, 0.7,  90000.00, 18000.00,  4,  NOW()),
(9,  DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 380000.00, 0.9, 760000.00,120000.00,  5,  NOW()),
(10, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 195000.00, 2.1, 410000.00, 62000.00,  8,  NOW()),
(11, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 168000.00, 1.8, 350000.00, 58000.00,  7,  NOW()),
(12, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 420000.00, 1.5, 850000.00,145000.00,  5,  NOW()),
(13, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  16000.00, 0.3,  18000.00,  6500.00,  2,  NOW()),
(14, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(), 120000.00, 0.6, 200000.00, 42000.00,  4,  NOW()),
(15, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  22000.00, 0.4,  30000.00,  9000.00,  3,  NOW());

-- ============================================================
-- STEP 8: DAILY TRANSACTION SUMMARY (last 30 days for AML)
-- ============================================================
-- cleared above
INSERT INTO Daily_Transaction_Summary (account_id, summary_date, total_debit, total_credit, txn_count, max_single_txn, distinct_payees) VALUES
(101, DATE_SUB(CURDATE(),INTERVAL 10 DAY), 15000.00, 85000.00, 2, 85000.00, 2),
(104, DATE_SUB(CURDATE(),INTERVAL 10 DAY), 42500.00,120000.00, 2,120000.00, 1),
(106, DATE_SUB(CURDATE(),INTERVAL 10 DAY), 30000.00, 95000.00, 2, 95000.00, 1),
(109, DATE_SUB(CURDATE(),INTERVAL  8 DAY),300000.00,560000.00, 2,560000.00, 1),
(113, DATE_SUB(CURDATE(),INTERVAL  3 DAY),445000.00,890000.00, 2,890000.00, 1),
(115, '2024-10-15',                        900000.00,      0.00, 5,190000.00, 5),
(117, '2024-10-20',                        470000.00,500000.00, 4,500000.00, 3),
(117, '2024-11-10',                        579000.00,600000.00, 7,600000.00, 6),
(119, '2024-10-05',                        780000.00,800000.00, 3,800000.00, 2);

-- ============================================================
-- STEP 9: AML BLACKLIST (known bad entities)
-- ============================================================
-- cleared above
INSERT INTO AML_Blacklist (entity_type, entity_value, reason, added_by, added_at) VALUES
('PAN',    'XYZRJ9999Z', 'Linked to hawala network - RBI watchlist 2023',     3, '2023-06-01 10:00:00'),
('IP',     '103.45.67.89','Multiple fraudulent login attempts - blacklisted',  4, '2024-01-15 10:00:00'),
('DEVICE', 'DEVFRD00192','Device fingerprint linked to 3 fraud cases',         4, '2024-03-20 10:00:00'),
('PAN',    'ABCFK0000X', 'Shell company director - ED investigation',          3, '2024-08-10 10:00:00'),
('IP',     '192.168.99.1','Internal testing blacklist entry',                  1, '2024-09-01 10:00:00');

-- ============================================================
-- STEP 10: AUDIT LOG (management actions history)
-- ============================================================
-- cleared above
INSERT INTO Audit_Log (table_name, operation, record_id, changed_by, old_values, new_values, logged_at) VALUES
('Account', 'UPDATE', 115, 3, '{"status":"ACTIVE"}',    '{"status":"SUSPENDED","reason":"AML structuring alert ALR001","actioned_by":"Priya Rajan"}', '2024-10-15 16:00:00'),
('Account', 'UPDATE', 116, 3, '{"status":"ACTIVE"}',    '{"status":"FROZEN","reason":"AML large transaction block ALR002","actioned_by":"Priya Rajan"}', '2024-11-02 11:00:00'),
('Account', 'UPDATE', 117, 4, '{"status":"ACTIVE"}',    '{"status":"SUSPENDED","reason":"AML layering alert ALR003","actioned_by":"Karthik Sundar"}', '2024-10-20 13:00:00'),
('Account', 'UPDATE', 118, 4, '{"status":"ACTIVE"}',    '{"status":"FROZEN","reason":"AML structuring alert ALR004","actioned_by":"Karthik Sundar"}', '2024-11-10 15:00:00'),
('Account', 'UPDATE', 119, 3, '{"status":"ACTIVE"}',    '{"status":"SUSPENDED","reason":"AML round-trip alert ALR005","actioned_by":"Priya Rajan"}', '2024-10-06 12:00:00'),
('Customer','UPDATE', 10,  3, '{"risk_score":20,"is_flagged":0}', '{"risk_score":78,"is_flagged":1,"reason":"Multiple AML alerts","actioned_by":"Priya Rajan"}', '2024-11-02 11:30:00'),
('Customer','UPDATE', 11,  4, '{"risk_score":15,"is_flagged":0}', '{"risk_score":82,"is_flagged":1,"reason":"Structuring + layering","actioned_by":"Karthik Sundar"}', '2024-11-10 15:30:00'),
('Customer','UPDATE', 12,  3, '{"risk_score":10,"is_flagged":0}', '{"risk_score":91,"is_flagged":1,"reason":"Round-tripping detected","actioned_by":"Priya Rajan"}', '2024-10-06 12:30:00'),
('Alert',   'UPDATE', 3,   4, '{"status":"OPEN"}',       '{"status":"UNDER_REVIEW","assigned_to":"Karthik Sundar"}', '2024-10-22 09:00:00'),
('Alert',   'UPDATE', 6,   3, '{"status":"OPEN"}',       '{"status":"UNDER_REVIEW","assigned_to":"Priya Rajan"}',    '2024-10-07 10:00:00');

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STEP 11: RECREATE the overdraft trigger
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

    IF NEW.from_account_id IS NOT NULL THEN
        SELECT balance, status, daily_limit
        INTO v_balance, v_status, v_limit
        FROM Account WHERE account_id = NEW.from_account_id;

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
        WHERE from_account_id = NEW.from_account_id
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
  (SELECT COUNT(*) FROM Customer), ' customers | ',
  (SELECT COUNT(*) FROM Account), ' accounts | ',
  (SELECT COUNT(*) FROM Transaction), ' transactions | ',
  (SELECT COUNT(*) FROM Alert), ' AML alerts | ',
  (SELECT COUNT(*) FROM Employee), ' employees'
) AS status;
