-- ============================================================
--  FinGuard Data Warehouse — SEED DATA
--  Run AFTER realistic_seed_data.sql AND bank_warehouse_schema_fixed2.sql
-- ============================================================

USE finguard_warehouse;

SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE agg_customer_monthly;
TRUNCATE TABLE fact_alert;
TRUNCATE TABLE fact_transaction;
TRUNCATE TABLE dim_account;
TRUNCATE TABLE dim_customer;
TRUNCATE TABLE dim_date;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STEP 1: dim_date (Sep 2024 – Mar 2025)
-- ============================================================
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, week_of_year, day_of_week, day_name, is_weekend)
WITH RECURSIVE dates AS (
  SELECT DATE('2024-09-01') AS d
  UNION ALL
  SELECT DATE_ADD(d, INTERVAL 1 DAY) FROM dates WHERE d < '2025-03-15'
)
SELECT
  DATE_FORMAT(d,'%Y%m%d'), d, YEAR(d), QUARTER(d), MONTH(d),
  MONTHNAME(d), WEEK(d,1), DAYOFWEEK(d), DAYNAME(d),
  IF(DAYOFWEEK(d) IN (1,7), 1, 0)
FROM dates;

UPDATE dim_date SET is_holiday = 1 WHERE full_date IN (
  '2024-10-02','2024-10-13','2024-11-01','2024-11-15','2024-12-25',
  '2025-01-14','2025-01-26','2025-02-26','2025-03-14'
);

-- ============================================================
-- STEP 2: dim_customer
-- customer_id is VARCHAR (alphanumeric from OLTP)
-- surrogate key = customer_sk (auto-increment)
-- ============================================================
INSERT INTO dim_customer
  (customer_sk, customer_id, full_name, PAN_number, city, state,
   age_bucket, risk_tier, is_flagged, effective_from, effective_to, is_current)
SELECT
  ROW_NUMBER() OVER (ORDER BY c.customer_id),
  c.customer_id,
  c.full_name,
  c.PAN_number,
  c.city,
  b.state,
  CASE
    WHEN TIMESTAMPDIFF(YEAR, c.DOB, CURDATE()) < 25 THEN '<25'
    WHEN TIMESTAMPDIFF(YEAR, c.DOB, CURDATE()) < 35 THEN '25-35'
    WHEN TIMESTAMPDIFF(YEAR, c.DOB, CURDATE()) < 50 THEN '35-50'
    WHEN TIMESTAMPDIFF(YEAR, c.DOB, CURDATE()) < 65 THEN '50-65'
    ELSE '65+'
  END,
  CASE
    WHEN c.risk_score >= 75 THEN 'CRITICAL'
    WHEN c.risk_score >= 50 THEN 'HIGH'
    WHEN c.risk_score >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END,
  c.is_flagged,
  DATE(c.created_at),
  NULL,
  1
FROM finguard_bank.Customer c
JOIN finguard_bank.Branch b ON c.branch_id = b.branch_id;

-- ============================================================
-- STEP 3: dim_account
-- account_no is BIGINT (12-digit)
-- ============================================================
INSERT INTO dim_account (account_sk, account_no, account_type, branch_name, city, state, IFSC_code)
SELECT
  ROW_NUMBER() OVER (ORDER BY a.account_no),
  a.account_no,
  a.account_type,
  b.branch_name,
  b.city,
  b.state,
  b.IFSC_code
FROM finguard_bank.Account a
JOIN finguard_bank.Branch b ON a.branch_id = b.branch_id;

-- ============================================================
-- STEP 4: fact_transaction
-- Uses account_no FK lookup and alphanumeric customer_id lookup
-- ip_country removed
-- ============================================================
INSERT INTO fact_transaction
  (transaction_id, from_account_sk, to_account_sk, from_customer_sk, to_customer_sk,
   txn_type_sk, date_key, amount, transaction_hour, was_flagged, alert_count, is_cross_branch)
SELECT
  t.transaction_id,
  da_from.account_sk,
  da_to.account_sk,
  dc_from.customer_sk,
  dc_to.customer_sk,
  COALESCE(tt.txn_type_sk, 1),
  DATE_FORMAT(t.transaction_timestamp, '%Y%m%d'),
  t.amount,
  HOUR(t.transaction_timestamp),
  CASE WHEN t.transaction_status IN ('BLOCKED','UNDER_REVIEW') THEN 1 ELSE 0 END,
  COALESCE((
    SELECT COUNT(*) FROM finguard_bank.Alert al
    WHERE al.transaction_id = t.transaction_id
  ), 0),
  CASE
    WHEN a_from.branch_id IS NOT NULL AND a_to.branch_id IS NOT NULL
         AND a_from.branch_id != a_to.branch_id THEN 1
    ELSE 0
  END
FROM finguard_bank.Transaction t
LEFT JOIN finguard_bank.Account       a_from  ON t.from_account_no = a_from.account_no
LEFT JOIN finguard_bank.Account       a_to    ON t.to_account_no   = a_to.account_no
LEFT JOIN dim_account                 da_from ON t.from_account_no = da_from.account_no
LEFT JOIN dim_account                 da_to   ON t.to_account_no   = da_to.account_no
LEFT JOIN dim_customer                dc_from ON a_from.customer_id = dc_from.customer_id AND dc_from.is_current = 1
LEFT JOIN dim_customer                dc_to   ON a_to.customer_id   = dc_to.customer_id   AND dc_to.is_current  = 1
LEFT JOIN dim_transaction_type        tt      ON tt.txn_type_code   = t.transaction_type
WHERE DATE(t.transaction_timestamp) BETWEEN '2024-09-01' AND '2025-03-15';

-- ============================================================
-- STEP 5: fact_alert
-- customer_id is VARCHAR — join to dim_customer on customer_id
-- ============================================================
INSERT INTO fact_alert
  (alert_no, customer_sk, txn_fact_id, date_key, alert_type, severity, was_true_positive)
SELECT
  al.alert_no,
  dc.customer_sk,
  al.transaction_id,
  DATE_FORMAT(al.alert_timestamp, '%Y%m%d'),
  al.alert_type,
  al.severity,
  CASE WHEN al.status != 'FALSE_POSITIVE' THEN 1 ELSE 0 END
FROM finguard_bank.Alert al
JOIN dim_customer dc ON al.customer_id = dc.customer_id AND dc.is_current = 1
WHERE DATE(al.alert_timestamp) BETWEEN '2024-09-01' AND '2025-03-15';

-- ============================================================
-- STEP 6: agg_customer_monthly
-- ============================================================
INSERT INTO agg_customer_monthly
  (customer_sk, `year_month`, total_outflow, total_inflow, txn_count,
   distinct_payees, max_single_txn, alert_count, risk_score_end)
SELECT
  dc.customer_sk,
  DATE_FORMAT(t.transaction_timestamp, '%Y-%m'),
  COALESCE(SUM(CASE WHEN t.from_account_no = a.account_no THEN t.amount ELSE 0 END), 0),
  COALESCE(SUM(CASE WHEN t.to_account_no   = a.account_no THEN t.amount ELSE 0 END), 0),
  COUNT(DISTINCT t.transaction_id),
  COUNT(DISTINCT t.to_account_no),
  MAX(t.amount),
  COALESCE((
    SELECT COUNT(*) FROM finguard_bank.Alert al
    WHERE al.customer_id = c.customer_id
      AND DATE_FORMAT(al.alert_timestamp, '%Y-%m') = DATE_FORMAT(t.transaction_timestamp, '%Y-%m')
  ), 0),
  c.risk_score
FROM finguard_bank.Transaction t
JOIN finguard_bank.Account  a  ON (t.from_account_no = a.account_no OR t.to_account_no = a.account_no)
JOIN finguard_bank.Customer c  ON a.customer_id = c.customer_id
JOIN dim_customer           dc ON c.customer_id  = dc.customer_id AND dc.is_current = 1
WHERE t.transaction_status = 'COMPLETED'
  AND DATE(t.transaction_timestamp) BETWEEN '2024-09-01' AND '2025-03-15'
GROUP BY dc.customer_sk, DATE_FORMAT(t.transaction_timestamp, '%Y-%m'), c.risk_score
ON DUPLICATE KEY UPDATE
  total_outflow   = VALUES(total_outflow),
  total_inflow    = VALUES(total_inflow),
  txn_count       = VALUES(txn_count),
  distinct_payees = VALUES(distinct_payees),
  max_single_txn  = VALUES(max_single_txn),
  alert_count     = VALUES(alert_count),
  risk_score_end  = VALUES(risk_score_end);

-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT 'dim_date'              AS tbl, COUNT(*) AS rows FROM dim_date             UNION ALL
SELECT 'dim_customer',                 COUNT(*)        FROM dim_customer          UNION ALL
SELECT 'dim_account',                  COUNT(*)        FROM dim_account           UNION ALL
SELECT 'fact_transaction',             COUNT(*)        FROM fact_transaction      UNION ALL
SELECT 'fact_alert',                   COUNT(*)        FROM fact_alert            UNION ALL
SELECT 'agg_customer_monthly',         COUNT(*)        FROM agg_customer_monthly;

SELECT '=== TOP 5 CUSTOMERS BY OUTFLOW ===' AS analysis;
SELECT dc.full_name, dc.risk_tier, SUM(acm.total_outflow) AS total_sent, SUM(acm.txn_count) AS txns
FROM agg_customer_monthly acm
JOIN dim_customer dc ON acm.customer_sk = dc.customer_sk AND dc.is_current = 1
GROUP BY dc.customer_sk, dc.full_name, dc.risk_tier
ORDER BY total_sent DESC LIMIT 5;

SELECT '=== MONTHLY VOLUME TREND ===' AS analysis;
SELECT `year_month`, SUM(txn_count) AS transactions, SUM(total_outflow) AS volume, SUM(alert_count) AS alerts
FROM agg_customer_monthly
GROUP BY `year_month` ORDER BY `year_month`;

SELECT '=== STRUCTURING CANDIDATES ===' AS analysis;
SELECT * FROM vw_structuring_candidates LIMIT 5;

SELECT '=== VELOCITY ANOMALIES ===' AS analysis;
SELECT * FROM vw_velocity_anomalies LIMIT 5;

SELECT '✅ Warehouse loaded and all analytics verified!' AS final_status;