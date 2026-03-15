-- =============================================================
--  BANK MANAGEMENT SYSTEM — DATA WAREHOUSE (OLAP)
--  Project: FinGuard — Anti-Money Laundering Detection
--  Architecture: Star Schema / Snowflake hybrid
--  Purpose: Historical behavioral analytics, AML pattern detection
-- =============================================================

DROP DATABASE IF EXISTS finguard_warehouse;
CREATE DATABASE finguard_warehouse
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE finguard_warehouse;

-- =============================================================
-- DIMENSION TABLE: dim_date
-- Standard time dimension for OLAP cube slicing.
-- =============================================================
CREATE TABLE IF NOT EXISTS dim_date (
    date_key        INT          NOT NULL,   -- YYYYMMDD format
    full_date       DATE         NOT NULL,
    year            SMALLINT     NOT NULL,
    quarter         TINYINT      NOT NULL,
    month           TINYINT      NOT NULL,
    month_name      VARCHAR(12)  NOT NULL,
    week_of_year    TINYINT      NOT NULL,
    day_of_week     TINYINT      NOT NULL,
    day_name        VARCHAR(12)  NOT NULL,
    is_weekend      TINYINT(1)   NOT NULL DEFAULT 0,
    is_holiday      TINYINT(1)   NOT NULL DEFAULT 0,
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
) ENGINE=InnoDB;

-- =============================================================
-- DIMENSION TABLE: dim_customer
-- Slowly changing dimension (SCD Type 2).
-- Tracks how customer risk profile evolves over time.
-- =============================================================
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_sk       INT          NOT NULL AUTO_INCREMENT,  -- surrogate key
    customer_id       INT          NOT NULL,                 -- business key
    full_name         VARCHAR(200) NOT NULL,
    PAN_number        CHAR(10)     NOT NULL,
    city              VARCHAR(100) NOT NULL,
    state             VARCHAR(100) NOT NULL,
    age_bucket        ENUM('<25','25-35','35-50','50-65','65+') NOT NULL,
    risk_tier         ENUM('LOW','MEDIUM','HIGH','CRITICAL')    NOT NULL DEFAULT 'LOW',
    is_flagged        TINYINT(1)   NOT NULL DEFAULT 0,
    effective_from    DATE         NOT NULL,
    effective_to      DATE,                                  -- NULL = current record
    is_current        TINYINT(1)   NOT NULL DEFAULT 1,
    CONSTRAINT pk_dim_customer PRIMARY KEY (customer_sk)
) ENGINE=InnoDB;

CREATE INDEX idx_dc_customer_id  ON dim_customer(customer_id);
CREATE INDEX idx_dc_current      ON dim_customer(is_current, customer_id);

-- =============================================================
-- DIMENSION TABLE: dim_account
-- =============================================================
CREATE TABLE IF NOT EXISTS dim_account (
    account_sk      INT          NOT NULL AUTO_INCREMENT,
    account_id      INT          NOT NULL,
    account_type    VARCHAR(50)  NOT NULL,
    branch_name     VARCHAR(150) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    state           VARCHAR(100) NOT NULL,
    IFSC_code       CHAR(11)     NOT NULL,
    CONSTRAINT pk_dim_account PRIMARY KEY (account_sk)
) ENGINE=InnoDB;

CREATE INDEX idx_da_account_id ON dim_account(account_id);

-- =============================================================
-- DIMENSION TABLE: dim_transaction_type
-- =============================================================
CREATE TABLE IF NOT EXISTS dim_transaction_type (
    txn_type_sk     INT          NOT NULL AUTO_INCREMENT,
    txn_type_code   VARCHAR(20)  NOT NULL,
    txn_category    VARCHAR(50)  NOT NULL,   -- 'ELECTRONIC','CASH','WIRE' etc.
    channel         VARCHAR(50)  NOT NULL,   -- 'MOBILE','BRANCH','ATM','ONLINE'
    CONSTRAINT pk_dim_txn_type PRIMARY KEY (txn_type_sk),
    CONSTRAINT uq_txn_type_code UNIQUE (txn_type_code)
) ENGINE=InnoDB;

INSERT INTO dim_transaction_type (txn_type_code, txn_category, channel) VALUES
    ('TRANSFER',     'ELECTRONIC', 'ONLINE'),
    ('DEPOSIT',      'CASH',       'BRANCH'),
    ('WITHDRAWAL',   'CASH',       'ATM'),
    ('UPI',          'ELECTRONIC', 'MOBILE'),
    ('NEFT',         'WIRE',       'ONLINE'),
    ('RTGS',         'WIRE',       'ONLINE'),
    ('IMPS',         'ELECTRONIC', 'MOBILE'),
    ('BILL_PAYMENT', 'ELECTRONIC', 'ONLINE');

-- =============================================================
-- FACT TABLE: fact_transaction
-- Grain: one row per completed transaction.
-- Central table of the star schema.
-- =============================================================
CREATE TABLE IF NOT EXISTS fact_transaction (
    txn_fact_id         BIGINT         NOT NULL AUTO_INCREMENT,
    transaction_id      INT            NOT NULL,   -- NK from OLTP
    from_account_sk     INT,
    to_account_sk       INT,
    from_customer_sk    INT,
    to_customer_sk      INT,
    txn_type_sk         INT            NOT NULL,
    date_key            INT            NOT NULL,
    amount              DECIMAL(15,2)  NOT NULL,
    transaction_hour    TINYINT        NOT NULL,   -- 0-23
    was_flagged         TINYINT(1)     NOT NULL DEFAULT 0,
    alert_count         TINYINT        NOT NULL DEFAULT 0,
    ip_country          VARCHAR(50),
    is_cross_branch     TINYINT(1)     NOT NULL DEFAULT 0,
    CONSTRAINT pk_fact_txn PRIMARY KEY (txn_fact_id),
    CONSTRAINT fk_ft_from_acct    FOREIGN KEY (from_account_sk)  REFERENCES dim_account(account_sk),
    CONSTRAINT fk_ft_to_acct      FOREIGN KEY (to_account_sk)    REFERENCES dim_account(account_sk),
    CONSTRAINT fk_ft_from_cust    FOREIGN KEY (from_customer_sk) REFERENCES dim_customer(customer_sk),
    CONSTRAINT fk_ft_to_cust      FOREIGN KEY (to_customer_sk)   REFERENCES dim_customer(customer_sk),
    CONSTRAINT fk_ft_txn_type     FOREIGN KEY (txn_type_sk)      REFERENCES dim_transaction_type(txn_type_sk),
    CONSTRAINT fk_ft_date         FOREIGN KEY (date_key)         REFERENCES dim_date(date_key)
) ENGINE=InnoDB;

CREATE INDEX idx_ft_from_cust  ON fact_transaction(from_customer_sk, date_key);
CREATE INDEX idx_ft_date       ON fact_transaction(date_key);
CREATE INDEX idx_ft_amount     ON fact_transaction(amount);
CREATE INDEX idx_ft_flagged    ON fact_transaction(was_flagged);

-- =============================================================
-- FACT TABLE: fact_alert
-- Grain: one row per AML alert raised.
-- =============================================================
CREATE TABLE IF NOT EXISTS fact_alert (
    alert_fact_id   BIGINT       NOT NULL AUTO_INCREMENT,
    alert_no        INT          NOT NULL,
    customer_sk     INT          NOT NULL,
    txn_fact_id     BIGINT,
    date_key        INT          NOT NULL,
    alert_type      VARCHAR(50)  NOT NULL,
    severity        VARCHAR(20)  NOT NULL,
    was_true_positive TINYINT(1) NOT NULL DEFAULT 0,
    days_to_resolve INT,
    CONSTRAINT pk_fact_alert PRIMARY KEY (alert_fact_id),
    CONSTRAINT fk_fa_customer FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk),
    CONSTRAINT fk_fa_date     FOREIGN KEY (date_key)    REFERENCES dim_date(date_key)
) ENGINE=InnoDB;

CREATE INDEX idx_fa_customer  ON fact_alert(customer_sk);
CREATE INDEX idx_fa_type      ON fact_alert(alert_type);
CREATE INDEX idx_fa_severity  ON fact_alert(severity);

-- =============================================================
-- AGGREGATE TABLE: agg_customer_monthly
-- Pre-aggregated monthly metrics for fast AML dashboard queries.
-- Refreshed nightly by ETL job.
-- =============================================================
CREATE TABLE IF NOT EXISTS agg_customer_monthly (
    agg_id              INT            NOT NULL AUTO_INCREMENT,
    customer_sk         INT            NOT NULL,
    `year_month`          CHAR(7)        NOT NULL,   -- 'YYYY-MM'
    total_outflow       DECIMAL(15,2)  NOT NULL DEFAULT 0,
    total_inflow        DECIMAL(15,2)  NOT NULL DEFAULT 0,
    txn_count           INT            NOT NULL DEFAULT 0,
    distinct_payees     INT            NOT NULL DEFAULT 0,
    max_single_txn      DECIMAL(15,2)  NOT NULL DEFAULT 0,
    alert_count         INT            NOT NULL DEFAULT 0,
    risk_score_end      DECIMAL(5,2)   NOT NULL DEFAULT 0,
    CONSTRAINT pk_agg PRIMARY KEY (agg_id),
    CONSTRAINT uq_agg UNIQUE (customer_sk, `year_month`),
    CONSTRAINT fk_agg_cust FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk)
) ENGINE=InnoDB;

-- =============================================================
-- ANALYTICAL VIEW: Structuring Detection Query
-- Groups by customer + day, flags structuring patterns.
-- This is the OLAP query that would be impossible in OLTP.
-- =============================================================
CREATE OR REPLACE VIEW vw_structuring_candidates AS
SELECT
    dc.customer_id,
    dc.full_name,
    dc.PAN_number,
    d.full_date                     AS txn_date,
    COUNT(ft.txn_fact_id)          AS txn_count,
    SUM(ft.amount)                 AS total_amount,
    MAX(ft.amount)                 AS max_single_amount,
    SUM(ft.amount) /
        COUNT(ft.txn_fact_id)      AS avg_txn_amount
FROM fact_transaction ft
JOIN dim_customer dc ON ft.from_customer_sk = dc.customer_sk AND dc.is_current = 1
JOIN dim_date     d  ON ft.date_key         = d.date_key
GROUP BY dc.customer_id, dc.full_name, dc.PAN_number, d.full_date
HAVING
    txn_count >= 3
    AND total_amount >= 1000000
    AND max_single_amount < 1000000   -- each txn individually below threshold
ORDER BY txn_date DESC;

-- =============================================================
-- ANALYTICAL VIEW: Layering Detection
-- Multi-hop fund tracking across accounts in 48 hours.
-- =============================================================
CREATE OR REPLACE VIEW vw_layering_candidates AS
SELECT
    dc_from.customer_id   AS origin_customer_id,
    dc_from.full_name     AS origin_customer,
    dc_to.customer_id     AS intermediate_customer_id,
    dc_to.full_name       AS intermediate_customer,
    COUNT(*)              AS hop_count,
    SUM(ft.amount)        AS total_moved,
    MIN(d.full_date)      AS first_hop_date,
    MAX(d.full_date)      AS last_hop_date
FROM fact_transaction ft
JOIN dim_customer dc_from ON ft.from_customer_sk = dc_from.customer_sk AND dc_from.is_current = 1
JOIN dim_customer dc_to   ON ft.to_customer_sk   = dc_to.customer_sk   AND dc_to.is_current = 1
JOIN dim_date     d       ON ft.date_key          = d.date_key
WHERE dc_from.customer_id != dc_to.customer_id
GROUP BY
    dc_from.customer_id, dc_from.full_name,
    dc_to.customer_id,   dc_to.full_name
HAVING
    hop_count >= 3
    AND DATEDIFF(MAX(d.full_date), MIN(d.full_date)) <= 2
    AND total_moved >= 500000
ORDER BY total_moved DESC;

-- =============================================================
-- ANALYTICAL VIEW: Velocity Spike Detection (3-sigma)
-- Compares current 7-day volume to 60-day baseline.
-- =============================================================
CREATE OR REPLACE VIEW vw_velocity_anomalies AS
SELECT
    dc.customer_id,
    dc.full_name,
    dc.PAN_number,
    recent.recent_avg,
    baseline.baseline_avg,
    baseline.baseline_std,
    CASE
        WHEN baseline.baseline_std > 0
        THEN (recent.recent_avg - baseline.baseline_avg) / baseline.baseline_std
        ELSE 0
    END AS z_score
FROM dim_customer dc

JOIN (
    SELECT from_customer_sk,
           AVG(amount) AS recent_avg
    FROM   fact_transaction ft
    JOIN   dim_date d ON ft.date_key = d.date_key
    WHERE  d.full_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP  BY from_customer_sk
) recent ON dc.customer_sk = recent.from_customer_sk

JOIN (
    SELECT from_customer_sk,
           AVG(amount)    AS baseline_avg,
           STDDEV(amount) AS baseline_std
    FROM   fact_transaction ft
    JOIN   dim_date d ON ft.date_key = d.date_key
    WHERE  d.full_date BETWEEN DATE_SUB(CURDATE(), INTERVAL 60 DAY)
                           AND DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP  BY from_customer_sk
) baseline ON dc.customer_sk = baseline.from_customer_sk

WHERE dc.is_current = 1
HAVING z_score > 3
ORDER BY z_score DESC;

-- End of Data Warehouse Schema
