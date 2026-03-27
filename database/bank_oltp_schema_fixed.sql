-- =============================================================
--  BANK MANAGEMENT SYSTEM — OLTP DATABASE (MySQL 8.0+)
--  Project: FinGuard — Anti-Money Laundering Detection
--  Normal Form: 5NF (all join dependencies explicitly modeled)
--  Author: Generated for DBMS Course Project
-- =============================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS finguard_bank
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE finguard_bank;

-- =============================================================
-- TABLE 1: BANK
-- Stores top-level bank entity. One row per banking institution.
-- =============================================================
CREATE TABLE IF NOT EXISTS Bank (
    bank_id       INT            NOT NULL AUTO_INCREMENT,
    bank_name     VARCHAR(150)   NOT NULL,
    hq_location   VARCHAR(255)   NOT NULL,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_bank PRIMARY KEY (bank_id),
    CONSTRAINT uq_bank_name UNIQUE (bank_name)
) ENGINE=InnoDB;

-- =============================================================
-- TABLE 2: BRANCH
-- Each branch belongs to exactly one bank.
-- IFSC code uniquely identifies a branch in India.
-- =============================================================
CREATE TABLE IF NOT EXISTS Branch (
    branch_id     INT            NOT NULL AUTO_INCREMENT,
    bank_id       INT            NOT NULL,
    branch_name   VARCHAR(150)   NOT NULL,
    IFSC_code     CHAR(11)       NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    state         VARCHAR(100)   NOT NULL,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_branch     PRIMARY KEY (branch_id),
    CONSTRAINT uq_ifsc       UNIQUE (IFSC_code),
    CONSTRAINT fk_branch_bank FOREIGN KEY (bank_id)
        REFERENCES Bank(bank_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_branch_bank ON Branch(bank_id);
CREATE INDEX idx_branch_city ON Branch(city);

-- =============================================================
-- TABLE 3: EMPLOYEE
-- Bank staff. Role determines access rights in application layer.
-- =============================================================
CREATE TABLE IF NOT EXISTS Employee (
    employee_id   INT            NOT NULL AUTO_INCREMENT,
    branch_id     INT            NOT NULL,
    name          VARCHAR(150)   NOT NULL,
    role          ENUM(
                    'BRANCH_MANAGER',
                    'TELLER',
                    'LOAN_OFFICER',
                    'COMPLIANCE_OFFICER',
                    'IT_ADMIN',
                    'AML_ANALYST'
                  )              NOT NULL,
    salary        DECIMAL(12,2)  NOT NULL CHECK (salary >= 0),
    joining_date  DATE           NOT NULL,
    email         VARCHAR(200)   NOT NULL,
    password_hash VARCHAR(255)   NOT NULL,      -- bcrypt hash
    is_active     TINYINT(1)     NOT NULL DEFAULT 1,
    CONSTRAINT pk_employee       PRIMARY KEY (employee_id),
    CONSTRAINT uq_employee_email UNIQUE (email),
    CONSTRAINT fk_employee_branch FOREIGN KEY (branch_id)
        REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_employee_branch ON Employee(branch_id);
CREATE INDEX idx_employee_role   ON Employee(role);

-- =============================================================
-- TABLE 4: CUSTOMER
-- KYC-complete customer profile.
-- PAN number is India's tax ID — unique per person (AML anchor).
-- risk_score: 0-100, updated by AML engine.
-- =============================================================
CREATE TABLE IF NOT EXISTS Customer (
    customer_id   INT            NOT NULL AUTO_INCREMENT,
    branch_id     INT            NOT NULL,
    full_name     VARCHAR(200)   NOT NULL,
    email         VARCHAR(200)   NOT NULL,
    phone         VARCHAR(15)    NOT NULL,
    address       TEXT           NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    DOB           DATE           NOT NULL,
    PAN_number    CHAR(10)       NOT NULL,
    aadhar_hash   VARCHAR(255),                 -- hashed, never plaintext
    risk_score    DECIMAL(5,2)   NOT NULL DEFAULT 0.00
                                 CHECK (risk_score BETWEEN 0 AND 100),
    is_flagged    TINYINT(1)     NOT NULL DEFAULT 0,
    password_hash VARCHAR(255)   NOT NULL,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_customer        PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_email  UNIQUE (email),
    CONSTRAINT uq_customer_pan    UNIQUE (PAN_number),
    CONSTRAINT fk_customer_branch FOREIGN KEY (branch_id)
        REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_pan_format CHECK (PAN_number REGEXP '^[A-Z]{5}[0-9]{4}[A-Z]$')
) ENGINE=InnoDB;

CREATE INDEX idx_customer_branch  ON Customer(branch_id);
CREATE INDEX idx_customer_flagged ON Customer(is_flagged);
CREATE INDEX idx_customer_risk    ON Customer(risk_score);

-- =============================================================
-- TABLE 5: ACCOUNT
-- One customer may have multiple accounts.
-- daily_limit enforced at application + trigger level.
-- =============================================================
CREATE TABLE IF NOT EXISTS Account (
    account_id    INT            NOT NULL AUTO_INCREMENT,
    customer_id   INT            NOT NULL,
    branch_id     INT            NOT NULL,
    account_type  ENUM('SAVINGS','CURRENT','FIXED_DEPOSIT','LOAN')
                                 NOT NULL DEFAULT 'SAVINGS',
    balance       DECIMAL(15,2)  NOT NULL DEFAULT 0.00
                                 CHECK (balance >= 0),
    daily_limit   DECIMAL(15,2)  NOT NULL DEFAULT 200000.00,
    status        ENUM('ACTIVE','FROZEN','CLOSED','SUSPENDED')
                                 NOT NULL DEFAULT 'ACTIVE',
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_account         PRIMARY KEY (account_id),
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_account_branch  FOREIGN KEY (branch_id)
        REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_account_customer ON Account(customer_id);
CREATE INDEX idx_account_status   ON Account(status);

-- =============================================================
-- TABLE 6: TRANSACTION
-- Core OLTP table. Every debit/credit recorded atomically.
-- Both from_account and to_account stored for bidirectional tracing.
-- ip_address + device_fingerprint: fraud correlation.
-- =============================================================
CREATE TABLE IF NOT EXISTS Transaction (
    transaction_id         INT            NOT NULL AUTO_INCREMENT,
    from_account_id        INT,                   -- NULL for cash deposits
    to_account_id          INT,                   -- NULL for cash withdrawals
    amount                 DECIMAL(15,2)  NOT NULL CHECK (amount > 0),
    transaction_type       ENUM(
                             'TRANSFER',
                             'DEPOSIT',
                             'WITHDRAWAL',
                             'UPI',
                             'NEFT',
                             'RTGS',
                             'IMPS',
                             'BILL_PAYMENT'
                           )              NOT NULL,
    transaction_status     ENUM(
                             'PENDING',
                             'COMPLETED',
                             'FAILED',
                             'BLOCKED',
                             'UNDER_REVIEW'
                           )              NOT NULL DEFAULT 'PENDING',
    transaction_timestamp  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address             VARCHAR(45),           -- IPv4 or IPv6
    device_fingerprint     VARCHAR(255),
    latitude               DECIMAL(9,6),          -- geo-location
    longitude              DECIMAL(9,6),
    remarks                VARCHAR(500),
    is_aml_reviewed        TINYINT(1)     NOT NULL DEFAULT 0,
    CONSTRAINT pk_transaction       PRIMARY KEY (transaction_id),
    CONSTRAINT fk_txn_from_account  FOREIGN KEY (from_account_id)
        REFERENCES Account(account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_to_account    FOREIGN KEY (to_account_id)
        REFERENCES Account(account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_txn_from        ON Transaction(from_account_id);
CREATE INDEX idx_txn_to          ON Transaction(to_account_id);
CREATE INDEX idx_txn_timestamp   ON Transaction(transaction_timestamp);
CREATE INDEX idx_txn_status      ON Transaction(transaction_status);
CREATE INDEX idx_txn_amount      ON Transaction(amount);
-- Composite index for AML structuring detection query:
CREATE INDEX idx_txn_account_time ON Transaction(from_account_id, transaction_timestamp);

-- =============================================================
-- TABLE 7: ALERT  (FinGuard Core)
-- Generated by AML stored procedures / triggers.
-- Links to the transaction(s) that triggered it.
-- =============================================================
CREATE TABLE IF NOT EXISTS Alert (
    alert_no           INT            NOT NULL AUTO_INCREMENT,
    transaction_id     INT,
    customer_id        INT            NOT NULL,
    alert_type         ENUM(
                         'LARGE_TRANSACTION',
                         'STRUCTURING',        -- smurfing / splitting
                         'RAPID_MOVEMENT',     -- layering
                         'VELOCITY_SPIKE',     -- sudden behavior change
                         'GEO_ANOMALY',        -- impossible travel
                         'DORMANT_ACTIVATED',  -- inactive account suddenly active
                         'ROUND_TRIPPING',     -- money round-trip
                         'BLACKLIST_MATCH'
                       )              NOT NULL,
    severity           ENUM('LOW','MEDIUM','HIGH','CRITICAL')
                                      NOT NULL DEFAULT 'MEDIUM',
    description        TEXT           NOT NULL,
    status             ENUM('OPEN','UNDER_REVIEW','RESOLVED','FALSE_POSITIVE')
                                      NOT NULL DEFAULT 'OPEN',
    assigned_to        INT,                   -- employee_id of assigned analyst
    alert_timestamp    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at        DATETIME,
    CONSTRAINT pk_alert          PRIMARY KEY (alert_no),
    CONSTRAINT fk_alert_txn      FOREIGN KEY (transaction_id)
        REFERENCES Transaction(transaction_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_alert_customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_alert_assigned FOREIGN KEY (assigned_to)
        REFERENCES Employee(employee_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_alert_customer   ON Alert(customer_id);
CREATE INDEX idx_alert_status     ON Alert(status);
CREATE INDEX idx_alert_severity   ON Alert(severity);
CREATE INDEX idx_alert_type       ON Alert(alert_type);
CREATE INDEX idx_alert_timestamp  ON Alert(alert_timestamp);

-- =============================================================
-- TABLE 8: DAILY_TRANSACTION_SUMMARY (AML helper, updated nightly)
-- Denormalized aggregates for fast AML rule evaluation.
-- Satisfies 5NF as a separate derived entity.
-- =============================================================
CREATE TABLE IF NOT EXISTS Daily_Transaction_Summary (
    summary_id        INT            NOT NULL AUTO_INCREMENT,
    account_id        INT            NOT NULL,
    summary_date      DATE           NOT NULL,
    total_debit       DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    total_credit      DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    txn_count         INT            NOT NULL DEFAULT 0,
    max_single_txn    DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    distinct_payees   INT            NOT NULL DEFAULT 0,
    CONSTRAINT pk_dts  PRIMARY KEY (summary_id),
    CONSTRAINT uq_dts  UNIQUE (account_id, summary_date),
    CONSTRAINT fk_dts_account FOREIGN KEY (account_id)
        REFERENCES Account(account_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_dts_date    ON Daily_Transaction_Summary(summary_date);
CREATE INDEX idx_dts_debit   ON Daily_Transaction_Summary(total_debit);

-- =============================================================
-- TABLE 9: CUSTOMER_BEHAVIOR_PROFILE (2-month rolling window)
-- Updated by nightly ETL job. Feeds AML velocity checks.
-- =============================================================
CREATE TABLE IF NOT EXISTS Customer_Behavior_Profile (
    profile_id           INT            NOT NULL AUTO_INCREMENT,
    customer_id          INT            NOT NULL,
    window_start         DATE           NOT NULL,
    window_end           DATE           NOT NULL,
    avg_txn_amount       DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    avg_daily_txn_count  DECIMAL(8,2)   NOT NULL DEFAULT 0.00,
    avg_monthly_outflow  DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    stddev_txn_amount    DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    total_unique_payees  INT            NOT NULL DEFAULT 0,
    updated_at           DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_cbp          PRIMARY KEY (profile_id),
    CONSTRAINT uq_cbp          UNIQUE (customer_id, window_start),
    CONSTRAINT fk_cbp_customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =============================================================
-- TABLE 10: AML_BLACKLIST
-- Known bad actors, accounts, or device fingerprints.
-- =============================================================
CREATE TABLE IF NOT EXISTS AML_Blacklist (
    blacklist_id    INT          NOT NULL AUTO_INCREMENT,
    entity_type     ENUM('PAN','ACCOUNT','IP','DEVICE','NAME')
                                 NOT NULL,
    entity_value    VARCHAR(255) NOT NULL,
    reason          TEXT         NOT NULL,
    added_by        INT,
    added_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_blacklist  PRIMARY KEY (blacklist_id),
    CONSTRAINT uq_blacklist  UNIQUE (entity_type, entity_value),
    CONSTRAINT fk_bl_employee FOREIGN KEY (added_by)
        REFERENCES Employee(employee_id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_bl_type_value ON AML_Blacklist(entity_type, entity_value);

-- =============================================================
-- TABLE 11: AUDIT_LOG (immutable event log)
-- Every write operation on sensitive tables is recorded.
-- =============================================================
CREATE TABLE IF NOT EXISTS Audit_Log (
    log_id         BIGINT       NOT NULL AUTO_INCREMENT,
    table_name     VARCHAR(100) NOT NULL,
    operation      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id      INT          NOT NULL,
    changed_by     INT,
    old_values     JSON,
    new_values     JSON,
    logged_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit PRIMARY KEY (log_id)
) ENGINE=InnoDB;

CREATE INDEX idx_audit_table   ON Audit_Log(table_name, record_id);
CREATE INDEX idx_audit_logged  ON Audit_Log(logged_at);

-- =============================================================
-- VIEWS
-- =============================================================

-- Account summary view (used by customer app)
CREATE OR REPLACE VIEW vw_account_summary AS
SELECT
    a.account_id,
    a.account_type,
    a.balance,
    a.status,
    a.daily_limit,
    c.full_name       AS customer_name,
    c.customer_id,
    b.branch_name,
    b.IFSC_code
FROM Account a
JOIN Customer c ON a.customer_id = c.customer_id
JOIN Branch   b ON a.branch_id   = b.branch_id;

-- Open alerts view for manager dashboard
CREATE OR REPLACE VIEW vw_open_alerts AS
SELECT
    al.alert_no,
    al.alert_type,
    al.severity,
    al.description,
    al.alert_timestamp,
    c.full_name         AS customer_name,
    c.PAN_number,
    c.risk_score,
    t.amount,
    t.transaction_type,
    t.transaction_timestamp
FROM Alert al
JOIN Customer    c ON al.customer_id   = c.customer_id
LEFT JOIN Transaction t ON al.transaction_id = t.transaction_id
WHERE al.status = 'OPEN'
ORDER BY
    FIELD(al.severity,'CRITICAL','HIGH','MEDIUM','LOW'),
    al.alert_timestamp DESC;

-- =============================================================
-- STORED PROCEDURES — AML RULES ENGINE (FinGuard)
-- =============================================================

DELIMITER $$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_large_transaction
-- Rule 1: Single transaction > ₹10 lakh → HIGH alert
--         Single transaction > ₹50 lakh → CRITICAL alert + block
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_large_transaction(
    IN p_transaction_id INT,
    IN p_account_id     INT,
    IN p_amount         DECIMAL(15,2)
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_threshold_high     DECIMAL(15,2) DEFAULT 1000000.00;   -- 10 lakh
    DECLARE v_threshold_critical DECIMAL(15,2) DEFAULT 5000000.00;   -- 50 lakh

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_id = p_account_id;

    IF p_amount >= v_threshold_critical THEN
        -- Block the transaction
        UPDATE Transaction
        SET transaction_status = 'BLOCKED'
        WHERE transaction_id = p_transaction_id;

        -- Raise CRITICAL alert
        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id,
            v_customer_id,
            'LARGE_TRANSACTION',
            'CRITICAL',
            CONCAT('Transaction of ₹', FORMAT(p_amount,2),
                   ' BLOCKED. Exceeds critical threshold of ₹50,00,000. Immediate review required.')
        );

        -- Freeze account pending review
        UPDATE Account SET status = 'SUSPENDED' WHERE account_id = p_account_id;

    ELSEIF p_amount >= v_threshold_high THEN
        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id,
            v_customer_id,
            'LARGE_TRANSACTION',
            'HIGH',
            CONCAT('Large transaction of ₹', FORMAT(p_amount,2),
                   ' detected. Exceeds ₹10,00,000 reporting threshold.')
        );
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_structuring
-- Rule 2: Smurfing / Structuring detection
-- If a customer sends >3 transactions in 24 hours where:
--   - each individually < ₹10 lakh
--   - but total within 24h > ₹10 lakh
-- This is classic "structuring" to evade reporting thresholds.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_structuring(
    IN p_account_id INT,
    IN p_customer_id INT
)
BEGIN
    DECLARE v_txn_count      INT;
    DECLARE v_total_24h      DECIMAL(15,2);
    DECLARE v_max_single     DECIMAL(15,2);
    DECLARE v_threshold      DECIMAL(15,2) DEFAULT 1000000.00;
    DECLARE v_min_txn_count  INT           DEFAULT 3;

    SELECT
        COUNT(*),
        SUM(amount),
        MAX(amount)
    INTO
        v_txn_count,
        v_total_24h,
        v_max_single
    FROM Transaction
    WHERE from_account_id = p_account_id
      AND transaction_status IN ('COMPLETED','PENDING')
      AND transaction_timestamp >= NOW() - INTERVAL 24 HOUR;

    IF v_txn_count >= v_min_txn_count
       AND v_total_24h >= v_threshold
       AND v_max_single < v_threshold  -- each individually below threshold
    THEN
        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            NULL,
            p_customer_id,
            'STRUCTURING',
            'CRITICAL',
            CONCAT('STRUCTURING DETECTED: ', v_txn_count,
                   ' transactions totaling ₹', FORMAT(v_total_24h,2),
                   ' in 24 hours. Each transaction kept below ₹10,00,000 threshold.',
                   ' Classic smurfing pattern.')
        );

        -- Elevate customer risk score
        UPDATE Customer
        SET risk_score = LEAST(risk_score + 30, 100),
            is_flagged = 1
        WHERE customer_id = p_customer_id;
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_velocity_spike
-- Rule 3: Behavioral anomaly — current 7-day average is >3 SD
-- above the 60-day rolling baseline from behavior profile.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_velocity_spike(
    IN p_customer_id INT,
    IN p_amount      DECIMAL(15,2)
)
BEGIN
    DECLARE v_avg   DECIMAL(15,2);
    DECLARE v_std   DECIMAL(15,2);
    DECLARE v_z     DECIMAL(10,4);

    SELECT avg_txn_amount, stddev_txn_amount
    INTO v_avg, v_std
    FROM Customer_Behavior_Profile
    WHERE customer_id = p_customer_id
    ORDER BY window_end DESC
    LIMIT 1;

    IF v_avg IS NOT NULL AND v_std > 0 THEN
        SET v_z = (p_amount - v_avg) / v_std;

        IF v_z > 3.0 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                NULL,
                p_customer_id,
                'VELOCITY_SPIKE',
                'HIGH',
                CONCAT('BEHAVIORAL ANOMALY: Transaction of ₹', FORMAT(p_amount,2),
                       ' is ', ROUND(v_z,1), ' standard deviations above 60-day average of ₹',
                       FORMAT(v_avg,2), '. Possible account takeover or sudden activity spike.')
            );
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_rapid_movement (Layering)
-- Rule 4: Money that arrives in account and leaves within 2 hours
-- across multiple hops — classic layering to obscure origin.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_rapid_movement(
    IN p_to_account_id INT
)
BEGIN
    DECLARE v_customer_id       INT;
    DECLARE v_inflow_2h         DECIMAL(15,2);
    DECLARE v_outflow_2h        DECIMAL(15,2);
    DECLARE v_layering_ratio    DECIMAL(5,2);

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_id = p_to_account_id;

    SELECT SUM(amount) INTO v_inflow_2h
    FROM Transaction
    WHERE to_account_id = p_to_account_id
      AND transaction_status = 'COMPLETED'
      AND transaction_timestamp >= NOW() - INTERVAL 2 HOUR;

    SELECT SUM(amount) INTO v_outflow_2h
    FROM Transaction
    WHERE from_account_id = p_to_account_id
      AND transaction_status IN ('COMPLETED','PENDING')
      AND transaction_timestamp >= NOW() - INTERVAL 2 HOUR;

    IF v_inflow_2h > 0 AND v_outflow_2h IS NOT NULL THEN
        SET v_layering_ratio = v_outflow_2h / v_inflow_2h;

        IF v_layering_ratio >= 0.80 AND v_inflow_2h >= 500000 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                NULL,
                v_customer_id,
                'RAPID_MOVEMENT',
                'CRITICAL',
                CONCAT('LAYERING DETECTED: ₹', FORMAT(v_inflow_2h,2),
                       ' received and ', ROUND(v_layering_ratio*100,1),
                       '% moved out within 2 hours. Funds barely touched account.')
            );
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_dormant_account
-- Rule 5: Account with no activity for >90 days suddenly transacts
-- a large amount — high-risk indicator.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_dormant_account(
    IN p_account_id     INT,
    IN p_transaction_id INT,
    IN p_amount         DECIMAL(15,2)
)
BEGIN
    DECLARE v_last_txn_date DATETIME;
    DECLARE v_customer_id   INT;
    DECLARE v_days_dormant  INT;

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_id = p_account_id;

    SELECT MAX(transaction_timestamp)
    INTO v_last_txn_date
    FROM Transaction
    WHERE (from_account_id = p_account_id OR to_account_id = p_account_id)
      AND transaction_id != p_transaction_id
      AND transaction_status = 'COMPLETED';

    IF v_last_txn_date IS NOT NULL THEN
        SET v_days_dormant = DATEDIFF(NOW(), v_last_txn_date);

        IF v_days_dormant >= 90 AND p_amount >= 100000 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                p_transaction_id,
                v_customer_id,
                'DORMANT_ACTIVATED',
                'HIGH',
                CONCAT('DORMANT ACCOUNT ACTIVATED: No activity for ', v_days_dormant,
                       ' days. First transaction after dormancy = ₹', FORMAT(p_amount,2),
                       '. Possible account takeover or mule account.')
            );
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_geo_anomaly
-- Rule 6: Impossible travel — two transactions from geographic
-- locations that are physically impossible within the time gap.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_geo_anomaly(
    IN p_account_id        INT,
    IN p_transaction_id    INT,
    IN p_lat               DECIMAL(9,6),
    IN p_lon               DECIMAL(9,6)
)
BEGIN
    DECLARE v_prev_lat      DECIMAL(9,6);
    DECLARE v_prev_lon      DECIMAL(9,6);
    DECLARE v_prev_time     DATETIME;
    DECLARE v_customer_id   INT;
    DECLARE v_hours_apart   DECIMAL(10,4);
    DECLARE v_distance_km   DECIMAL(10,2);
    DECLARE v_speed_kmh     DECIMAL(10,2);

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_id = p_account_id;

    SELECT latitude, longitude, transaction_timestamp
    INTO v_prev_lat, v_prev_lon, v_prev_time
    FROM Transaction
    WHERE from_account_id = p_account_id
      AND transaction_id != p_transaction_id
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
    ORDER BY transaction_timestamp DESC
    LIMIT 1;

    IF v_prev_lat IS NOT NULL THEN
        SET v_hours_apart = TIMESTAMPDIFF(MINUTE, v_prev_time, NOW()) / 60.0;

        -- Haversine approximation (simplified)
        SET v_distance_km = 111.045 * SQRT(
            POW(p_lat - v_prev_lat, 2) +
            POW((p_lon - v_prev_lon) * COS(RADIANS((p_lat + v_prev_lat)/2)), 2)
        );

        IF v_hours_apart > 0 THEN
            SET v_speed_kmh = v_distance_km / v_hours_apart;

            -- > 900 km/h = impossible by road, suspicious even by air
            IF v_speed_kmh > 900 AND v_distance_km > 200 THEN
                INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
                VALUES (
                    p_transaction_id,
                    v_customer_id,
                    'GEO_ANOMALY',
                    'HIGH',
                    CONCAT('GEO ANOMALY: Two transactions ', ROUND(v_distance_km,0),
                           ' km apart within ', ROUND(v_hours_apart,2),
                           ' hours (implied speed: ', ROUND(v_speed_kmh,0),
                           ' km/h). Possible credential sharing or card cloning.')
                );
            END IF;
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------------
-- PROCEDURE: sp_check_blacklist
-- Rule 7: Check if any party (PAN, IP, device) is blacklisted.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_check_blacklist(
    IN p_transaction_id INT,
    IN p_customer_id    INT,
    IN p_pan            CHAR(10),
    IN p_ip             VARCHAR(45),
    IN p_device         VARCHAR(255)
)
BEGIN
    DECLARE v_match_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_match_count
    FROM AML_Blacklist
    WHERE (entity_type = 'PAN'    AND entity_value = p_pan)
       OR (entity_type = 'IP'     AND entity_value = p_ip)
       OR (entity_type = 'DEVICE' AND entity_value = p_device);

    IF v_match_count > 0 THEN
        UPDATE Transaction
        SET transaction_status = 'BLOCKED'
        WHERE transaction_id = p_transaction_id;

        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id,
            p_customer_id,
            'BLACKLIST_MATCH',
            'CRITICAL',
            CONCAT('BLACKLIST HIT: Transaction blocked. Customer PAN, IP, or device ',
                   'matched against AML blacklist. Immediate investigation required.')
        );
    END IF;
END$$

-- ------------------------------------------------------------------
-- MASTER PROCEDURE: sp_run_aml_checks
-- Called after every transaction INSERT. Orchestrates all rules.
-- ------------------------------------------------------------------
CREATE PROCEDURE sp_run_aml_checks(
    IN p_transaction_id INT
)
BEGIN
    DECLARE v_amount       DECIMAL(15,2);
    DECLARE v_from_acct    INT;
    DECLARE v_to_acct      INT;
    DECLARE v_customer_id  INT;
    DECLARE v_pan          CHAR(10);
    DECLARE v_ip           VARCHAR(45);
    DECLARE v_device       VARCHAR(255);
    DECLARE v_lat          DECIMAL(9,6);
    DECLARE v_lon          DECIMAL(9,6);

    -- Load transaction context
    SELECT t.amount, t.from_account_id, t.to_account_id,
           t.ip_address, t.device_fingerprint, t.latitude, t.longitude,
           c.customer_id, c.PAN_number
    INTO   v_amount, v_from_acct, v_to_acct,
           v_ip, v_device, v_lat, v_lon,
           v_customer_id, v_pan
    FROM Transaction t
    JOIN Account     a ON a.account_id   = t.from_account_id
    JOIN Customer    c ON c.customer_id  = a.customer_id
    WHERE t.transaction_id = p_transaction_id;

    -- Run all AML rules in sequence
    CALL sp_check_large_transaction(p_transaction_id, v_from_acct, v_amount);
    CALL sp_check_structuring(v_from_acct, v_customer_id);
    CALL sp_check_velocity_spike(v_customer_id, v_amount);
    CALL sp_check_rapid_movement(v_to_acct);
    CALL sp_check_dormant_account(v_from_acct, p_transaction_id, v_amount);
    CALL sp_check_geo_anomaly(v_from_acct, p_transaction_id, v_lat, v_lon);
    CALL sp_check_blacklist(p_transaction_id, v_customer_id, v_pan, v_ip, v_device);

    -- (AML review flag updated by backend layer)

END$$

DELIMITER ;

-- =============================================================
-- TRIGGERS
-- =============================================================

DELIMITER $$

-- NOTE: AML checks are called explicitly by the backend after each insert.
-- The trigger is intentionally removed to avoid MySQL restriction
-- (cannot update Transaction table inside a trigger on Transaction).

-- Trigger: Update account balances on completed transaction
CREATE TRIGGER trg_update_balances
AFTER UPDATE ON Transaction
FOR EACH ROW
BEGIN
    IF NEW.transaction_status = 'COMPLETED'
       AND OLD.transaction_status = 'PENDING' THEN
        IF NEW.from_account_id IS NOT NULL THEN
            UPDATE Account
            SET balance = balance - NEW.amount
            WHERE account_id = NEW.from_account_id;
        END IF;
        IF NEW.to_account_id IS NOT NULL THEN
            UPDATE Account
            SET balance = balance + NEW.amount
            WHERE account_id = NEW.to_account_id;
        END IF;
    END IF;
END$$

-- Trigger: Prevent overdraft
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

        -- Block if account not active
        IF v_status != 'ACTIVE' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Account is not active. Transaction rejected.';
        END IF;

        -- Check balance
        IF v_balance < NEW.amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient balance. Transaction rejected.';
        END IF;

        -- Check daily limit
        SELECT COALESCE(SUM(amount),0) INTO v_daily_out
        FROM Transaction
        WHERE from_account_id = NEW.from_account_id
          AND DATE(transaction_timestamp) = CURDATE()
          AND transaction_status IN ('COMPLETED','PENDING');

        -- Allow BLOCKED inserts to be recorded in history.
        -- The application uses transaction_status='BLOCKED' for attempts blocked by limits,
        -- and we still want the customer/manager to see them in Transaction history.
        IF NEW.transaction_status IN ('PENDING','COMPLETED') AND (v_daily_out + NEW.amount) > v_limit THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Daily transaction limit exceeded. Transaction rejected.';
        END IF;
    END IF;
END$$

DELIMITER ;

-- =============================================================
-- SCHEDULED EVENT: Nightly behavior profile refresh
-- Runs at 2:00 AM every day to update 60-day rolling window.
-- =============================================================
SET GLOBAL event_scheduler = ON;

DELIMITER $$

CREATE EVENT IF NOT EXISTS evt_refresh_behavior_profiles
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURDATE(), '02:00:00')
DO
BEGIN
    INSERT INTO Customer_Behavior_Profile
        (customer_id, window_start, window_end,
         avg_txn_amount, avg_daily_txn_count, avg_monthly_outflow,
         stddev_txn_amount, total_unique_payees)
    SELECT
        c.customer_id,
        DATE_SUB(CURDATE(), INTERVAL 60 DAY)  AS window_start,
        CURDATE()                              AS window_end,
        COALESCE(AVG(t.amount),0)             AS avg_txn_amount,
        COUNT(t.transaction_id) / 60.0        AS avg_daily_txn_count,
        COALESCE(SUM(t.amount) / 2, 0)        AS avg_monthly_outflow,
        COALESCE(STDDEV(t.amount), 0)         AS stddev_txn_amount,
        COUNT(DISTINCT t.to_account_id)       AS total_unique_payees
    FROM Customer c
    LEFT JOIN Account     a ON a.customer_id       = c.customer_id
    LEFT JOIN Transaction t ON t.from_account_id   = a.account_id
                            AND t.transaction_timestamp >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
                            AND t.transaction_status = 'COMPLETED'
    GROUP BY c.customer_id
    ON DUPLICATE KEY UPDATE
        window_end           = VALUES(window_end),
        avg_txn_amount       = VALUES(avg_txn_amount),
        avg_daily_txn_count  = VALUES(avg_daily_txn_count),
        avg_monthly_outflow  = VALUES(avg_monthly_outflow),
        stddev_txn_amount    = VALUES(stddev_txn_amount),
        total_unique_payees  = VALUES(total_unique_payees),
        updated_at           = NOW();
END$$

-- Nightly: Rebuild daily transaction summary
CREATE EVENT IF NOT EXISTS evt_rebuild_daily_summary
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURDATE(), '01:30:00')
DO
BEGIN
    INSERT INTO Daily_Transaction_Summary
        (account_id, summary_date, total_debit, total_credit,
         txn_count, max_single_txn, distinct_payees)
    SELECT
        COALESCE(from_account_id, to_account_id) AS account_id,
        DATE(transaction_timestamp)              AS summary_date,
        SUM(CASE WHEN from_account_id IS NOT NULL THEN amount ELSE 0 END),
        SUM(CASE WHEN to_account_id   IS NOT NULL THEN amount ELSE 0 END),
        COUNT(*),
        MAX(amount),
        COUNT(DISTINCT to_account_id)
    FROM Transaction
    WHERE DATE(transaction_timestamp) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
      AND transaction_status = 'COMPLETED'
    GROUP BY account_id, summary_date
    ON DUPLICATE KEY UPDATE
        total_debit    = VALUES(total_debit),
        total_credit   = VALUES(total_credit),
        txn_count      = VALUES(txn_count),
        max_single_txn = VALUES(max_single_txn),
        distinct_payees = VALUES(distinct_payees);
END$$

DELIMITER ;

-- =============================================================
-- SEED DATA (minimal demo)
-- =============================================================
INSERT INTO Bank (bank_name, hq_location) VALUES
    ('FinGuard National Bank', 'Mumbai, Maharashtra');

INSERT INTO Branch (bank_id, branch_name, IFSC_code, city, state) VALUES
    (1, 'Andheri West Branch',  'FGNB0001234', 'Mumbai',  'Maharashtra'),
    (1, 'T. Nagar Branch',      'FGNB0005678', 'Chennai', 'Tamil Nadu'),
    (1, 'Koramangala Branch',   'FGNB0009012', 'Bangalore','Karnataka');

INSERT INTO Employee (branch_id, name, role, salary, joining_date, email, password_hash) VALUES
    (1, 'Arjun Mehta',     'BRANCH_MANAGER',    120000, '2018-04-01', 'arjun.mehta@fgnb.in',    '$2b$12$placeholder'),
    (2, 'Priya Rajan',     'COMPLIANCE_OFFICER', 95000, '2019-07-15', 'priya.rajan@fgnb.in',    '$2b$12$placeholder'),
    (2, 'Karthik Sundar',  'AML_ANALYST',        88000, '2021-01-10', 'karthik.sundar@fgnb.in', '$2b$12$placeholder');

SET FOREIGN_KEY_CHECKS = 1;

-- End of OLTP Schema
