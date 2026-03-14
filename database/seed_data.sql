-- ============================================================
--  FinGuard — Demo Password Seed (run AFTER bank_oltp_schema.sql)
--  Hashes below = bcrypt(password123, rounds=12)
--  Change ALL passwords before any real deployment!
-- ============================================================

USE finguard_bank;

-- Update employee passwords
UPDATE Employee SET password_hash = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa' WHERE email = 'arjun.mehta@fgnb.in';
UPDATE Employee SET password_hash = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa' WHERE email = 'priya.rajan@fgnb.in';
UPDATE Employee SET password_hash = '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa' WHERE email = 'karthik.sundar@fgnb.in';

-- Insert demo customers
INSERT INTO Customer (branch_id, full_name, email, phone, address, city, DOB, PAN_number, password_hash, risk_score, is_flagged) VALUES
(2, 'Ananya Krishnamurthy', 'ananya@example.com', '9876543210', '12 Anna Salai, T. Nagar', 'Chennai',   '1992-05-14', 'ABCPK1234H', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', 12, 0),
(1, 'Rajesh Venkataraman',  'rajesh@example.com', '9811223344', '45 Linking Road, Bandra', 'Mumbai',    '1985-11-02', 'XYZRV5678J', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', 78, 1),
(3, 'Meera Subramaniam',    'meera@example.com',  '9900112233', '8 MG Road, Koramangala', 'Bangalore', '1997-08-20', 'DEFMS9012K', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaZS1l8N4Ae3FDFpQ7YTaKvJa', 34, 0);

-- Insert demo accounts (IDs depend on your auto_increment; adjust if needed)
INSERT INTO Account (customer_id, branch_id, account_type, balance, daily_limit, status) VALUES
(1, 2, 'SAVINGS',  284350.75, 200000, 'ACTIVE'),
(1, 2, 'CURRENT',  850000.00, 500000, 'ACTIVE'),
(2, 1, 'SAVINGS',  120450.00, 200000, 'SUSPENDED'),
(3, 3, 'SAVINGS',   67800.50, 200000, 'ACTIVE');

-- Insert demo transactions
INSERT INTO Transaction (from_account_id, to_account_id, amount, transaction_type, transaction_status, remarks, transaction_timestamp) VALUES
(1, 4, 25000,  'UPI',      'COMPLETED',    'Rent payment',            '2024-03-13 14:32:00'),
(NULL, 1, 150000, 'NEFT',  'COMPLETED',    'Salary credit',           '2024-03-12 10:15:00'),
(2, 3, 45000,  'TRANSFER', 'COMPLETED',    'Business payment',        '2024-03-11 16:45:00'),
(3, 1, 980000, 'NEFT',     'BLOCKED',      'BLOCKED by FinGuard AML', '2024-03-10 09:00:00'),
(3, 4, 90000,  'IMPS',     'COMPLETED',    'Structuring txn 1/4',     '2024-03-09 11:20:00'),
(3, 1, 95000,  'IMPS',     'COMPLETED',    'Structuring txn 2/4',     '2024-03-09 12:10:00'),
(3, 4, 88000,  'IMPS',     'COMPLETED',    'Structuring txn 3/4',     '2024-03-09 13:45:00'),
(3, 2, 92000,  'IMPS',     'UNDER_REVIEW', 'Structuring txn 4/4',     '2024-03-09 15:00:00'),
(1, NULL, 8000, 'WITHDRAWAL','COMPLETED',  'ATM withdrawal',           '2024-03-08 17:30:00'),
(4, 1, 12000,  'UPI',      'COMPLETED',    'Reimbursement',           '2024-03-07 09:00:00');

-- Insert demo alerts
INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description, status, alert_timestamp) VALUES
(4, 2, 'LARGE_TRANSACTION', 'CRITICAL', 'Transaction of ₹9,80,000 flagged. Exceeds ₹10,00,000 threshold. Transaction BLOCKED and account suspended pending compliance review.', 'OPEN', '2024-03-10 09:00:05'),
(NULL, 2, 'STRUCTURING', 'CRITICAL', 'STRUCTURING DETECTED: 4 transactions totaling ₹3,65,000 in 24 hours. Each individually below ₹10,00,000 threshold. Classic smurfing/structuring pattern. Customer risk score elevated to 78.', 'OPEN', '2024-03-09 15:05:00'),
(8, 2, 'RAPID_MOVEMENT', 'HIGH', 'LAYERING DETECTED: ₹3,65,000 received and 82% moved out within 4 hours. Funds barely touched the account. Multi-hop transfer pattern detected.', 'UNDER_REVIEW', '2024-03-09 15:10:00'),
(NULL, 3, 'VELOCITY_SPIKE', 'MEDIUM', 'BEHAVIORAL ANOMALY: Recent transaction 2.8 standard deviations above 60-day average of ₹8,200. Possible unusual activity.', 'OPEN', '2024-03-07 10:00:00');

-- Build 60-day behavior profile for demo customers
INSERT INTO Customer_Behavior_Profile
  (customer_id, window_start, window_end, avg_txn_amount, avg_daily_txn_count, avg_monthly_outflow, stddev_txn_amount, total_unique_payees)
VALUES
  (1, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  25000.00, 0.5, 50000.00,  15000.00, 3),
  (2, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),  40000.00, 1.2, 80000.00,  20000.00, 4),
  (3, DATE_SUB(CURDATE(),INTERVAL 60 DAY), CURDATE(),   8200.00, 0.3, 16400.00,   5000.00, 2);
