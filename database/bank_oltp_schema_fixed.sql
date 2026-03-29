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
-- =============================================================
CREATE TABLE IF NOT EXISTS Branch (
    branch_id     INT            NOT NULL AUTO_INCREMENT,
    bank_id       INT            NOT NULL,
    branch_name   VARCHAR(150)   NOT NULL,
    IFSC_code     CHAR(11)       NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    state         VARCHAR(100)   NOT NULL,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_branch      PRIMARY KEY (branch_id),
    CONSTRAINT uq_ifsc        UNIQUE (IFSC_code),
    CONSTRAINT fk_branch_bank FOREIGN KEY (bank_id)
        REFERENCES Bank(bank_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_branch_bank ON Branch(bank_id);
CREATE INDEX idx_branch_city ON Branch(city);

-- =============================================================
-- TABLE 3: EMPLOYEE
-- employee_id: alphanumeric (e.g. 'arjun01', 'priya02')
-- =============================================================
CREATE TABLE IF NOT EXISTS Employee (
    employee_id   VARCHAR(20)    NOT NULL,
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
    password_hash VARCHAR(255)   NOT NULL,
    is_active     TINYINT(1)     NOT NULL DEFAULT 1,
    CONSTRAINT pk_employee        PRIMARY KEY (employee_id),
    CONSTRAINT uq_employee_email  UNIQUE (email),
    CONSTRAINT fk_employee_branch FOREIGN KEY (branch_id)
        REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_employee_branch ON Employee(branch_id);
CREATE INDEX idx_employee_role   ON Employee(role);

-- =============================================================
-- TABLE 4: CUSTOMER
-- customer_id: alphanumeric (e.g. 'ananya12', 'suresh85')
-- aadhar_hash removed (not required for AML purposes)
-- =============================================================
CREATE TABLE IF NOT EXISTS Customer (
    customer_id   VARCHAR(20)    NOT NULL,
    branch_id     INT            NOT NULL,
    full_name     VARCHAR(200)   NOT NULL,
    email         VARCHAR(200)   NOT NULL,
    phone         VARCHAR(15)    NOT NULL,
    address       TEXT           NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    DOB           DATE           NOT NULL,
    PAN_number    CHAR(10)       NOT NULL,
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
-- account_no: BIGINT, 12-digit unique number (e.g. 432156780987)
-- =============================================================
CREATE TABLE IF NOT EXISTS Account (
    account_no    BIGINT         NOT NULL,
    customer_id   VARCHAR(20)    NOT NULL,
    branch_id     INT            NOT NULL,
    account_type  ENUM('SAVINGS','CURRENT','FIXED_DEPOSIT','LOAN')
                                 NOT NULL DEFAULT 'SAVINGS',
    balance       DECIMAL(15,2)  NOT NULL DEFAULT 0.00
                                 CHECK (balance >= 0),
    daily_limit   DECIMAL(15,2)  NOT NULL DEFAULT 200000.00,
    status        ENUM('ACTIVE','FROZEN','CLOSED','SUSPENDED')
                                 NOT NULL DEFAULT 'ACTIVE',
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_account          PRIMARY KEY (account_no),
    CONSTRAINT fk_account_customer FOREIGN KEY (customer_id)
        REFERENCES Customer(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_account_branch   FOREIGN KEY (branch_id)
        REFERENCES Branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_account_customer ON Account(customer_id);
CREATE INDEX idx_account_status   ON Account(status);

-- =============================================================
-- TABLE 6: TRANSACTION
-- ip_address, device_fingerprint, latitude, longitude removed
-- =============================================================
CREATE TABLE IF NOT EXISTS Transaction (
    transaction_id         INT            NOT NULL AUTO_INCREMENT,
    from_account_no        BIGINT,                -- NULL for cash deposits
    to_account_no          BIGINT,                -- NULL for cash withdrawals
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
    remarks                VARCHAR(500),
    is_aml_reviewed        TINYINT(1)     NOT NULL DEFAULT 0,
    CONSTRAINT pk_transaction        PRIMARY KEY (transaction_id),
    CONSTRAINT fk_txn_from_account   FOREIGN KEY (from_account_no)
        REFERENCES Account(account_no)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_to_account     FOREIGN KEY (to_account_no)
        REFERENCES Account(account_no)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_txn_from         ON Transaction(from_account_no);
CREATE INDEX idx_txn_to           ON Transaction(to_account_no);
CREATE INDEX idx_txn_timestamp    ON Transaction(transaction_timestamp);
CREATE INDEX idx_txn_status       ON Transaction(transaction_status);
CREATE INDEX idx_txn_amount       ON Transaction(amount);
CREATE INDEX idx_txn_account_time ON Transaction(from_account_no, transaction_timestamp);

-- =============================================================
-- TABLE 7: ALERT
-- GEO_ANOMALY removed from alert_type ENUM
-- =============================================================
CREATE TABLE IF NOT EXISTS Alert (
    alert_no           INT            NOT NULL AUTO_INCREMENT,
    transaction_id     INT,
    customer_id        VARCHAR(20)    NOT NULL,
    alert_type         ENUM(
                         'LARGE_TRANSACTION',
                         'STRUCTURING',
                         'RAPID_MOVEMENT',
                         'VELOCITY_SPIKE',
                         'DORMANT_ACTIVATED',
                         'ROUND_TRIPPING',
                         'BLACKLIST_MATCH'
                       )              NOT NULL,
    severity           ENUM('LOW','MEDIUM','HIGH','CRITICAL')
                                      NOT NULL DEFAULT 'MEDIUM',
    description        TEXT           NOT NULL,
    status             ENUM('OPEN','UNDER_REVIEW','RESOLVED','FALSE_POSITIVE')
                                      NOT NULL DEFAULT 'OPEN',
    assigned_to        VARCHAR(20),
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
-- TABLE 8: DAILY_TRANSACTION_SUMMARY
-- =============================================================
CREATE TABLE IF NOT EXISTS Daily_Transaction_Summary (
    summary_id        INT            NOT NULL AUTO_INCREMENT,
    account_no        BIGINT         NOT NULL,
    summary_date      DATE           NOT NULL,
    total_debit       DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    total_credit      DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    txn_count         INT            NOT NULL DEFAULT 0,
    max_single_txn    DECIMAL(15,2)  NOT NULL DEFAULT 0.00,
    distinct_payees   INT            NOT NULL DEFAULT 0,
    CONSTRAINT pk_dts  PRIMARY KEY (summary_id),
    CONSTRAINT uq_dts  UNIQUE (account_no, summary_date),
    CONSTRAINT fk_dts_account FOREIGN KEY (account_no)
        REFERENCES Account(account_no)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_dts_date  ON Daily_Transaction_Summary(summary_date);
CREATE INDEX idx_dts_debit ON Daily_Transaction_Summary(total_debit);

-- =============================================================
-- TABLE 9: CUSTOMER_BEHAVIOR_PROFILE
-- =============================================================
CREATE TABLE IF NOT EXISTS Customer_Behavior_Profile (
    profile_id           INT            NOT NULL AUTO_INCREMENT,
    customer_id          VARCHAR(20)    NOT NULL,
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
-- IP and DEVICE removed from entity_type (not tracked anymore)
-- =============================================================
CREATE TABLE IF NOT EXISTS AML_Blacklist (
    blacklist_id    INT          NOT NULL AUTO_INCREMENT,
    entity_type     ENUM('PAN','ACCOUNT','NAME')
                                 NOT NULL,
    entity_value    VARCHAR(255) NOT NULL,
    reason          TEXT         NOT NULL,
    added_by        VARCHAR(20),
    added_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_blacklist   PRIMARY KEY (blacklist_id),
    CONSTRAINT uq_blacklist   UNIQUE (entity_type, entity_value),
    CONSTRAINT fk_bl_employee FOREIGN KEY (added_by)
        REFERENCES Employee(employee_id)
        ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE INDEX idx_bl_type_value ON AML_Blacklist(entity_type, entity_value);

-- =============================================================
-- TABLE 11: AUDIT_LOG
-- =============================================================
CREATE TABLE IF NOT EXISTS Audit_Log (
    log_id         BIGINT       NOT NULL AUTO_INCREMENT,
    table_name     VARCHAR(100) NOT NULL,
    operation      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id      VARCHAR(50)  NOT NULL,
    changed_by     VARCHAR(20),
    old_values     JSON,
    new_values     JSON,
    logged_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_audit PRIMARY KEY (log_id)
) ENGINE=InnoDB;

CREATE INDEX idx_audit_table  ON Audit_Log(table_name, record_id(20));
CREATE INDEX idx_audit_logged ON Audit_Log(logged_at);

-- =============================================================
-- VIEWS
-- =============================================================
CREATE OR REPLACE VIEW vw_account_summary AS
SELECT
    a.account_no,
    a.account_type,
    a.balance,
    a.status,
    a.daily_limit,
    c.full_name   AS customer_name,
    c.customer_id,
    b.branch_name,
    b.IFSC_code
FROM Account  a
JOIN Customer c ON a.customer_id = c.customer_id
JOIN Branch   b ON a.branch_id   = b.branch_id;

CREATE OR REPLACE VIEW vw_open_alerts AS
SELECT
    al.alert_no,
    al.alert_type,
    al.severity,
    al.description,
    al.alert_timestamp,
    c.full_name     AS customer_name,
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
-- STORED PROCEDURES — AML RULES ENGINE
-- =============================================================

DELIMITER $$

-- Rule 1: Large Transaction
CREATE PROCEDURE sp_check_large_transaction(
    IN p_transaction_id INT,
    IN p_account_no     BIGINT,
    IN p_amount         DECIMAL(15,2)
)
BEGIN
    DECLARE v_customer_id        VARCHAR(20);
    DECLARE v_threshold_high     DECIMAL(15,2) DEFAULT 1000000.00;
    DECLARE v_threshold_critical DECIMAL(15,2) DEFAULT 5000000.00;

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_no = p_account_no;

    IF p_amount >= v_threshold_critical THEN
        UPDATE Transaction
        SET transaction_status = 'BLOCKED'
        WHERE transaction_id = p_transaction_id;

        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id, v_customer_id, 'LARGE_TRANSACTION', 'CRITICAL',
            CONCAT('Transfer of ₹', FORMAT(p_amount,0), ' from account ', p_account_no,
                   ' was BLOCKED — exceeds the ₹50,00,000 critical limit. Immediate review needed.')
        );

        UPDATE Account SET status = 'SUSPENDED' WHERE account_no = p_account_no;

    ELSEIF p_amount >= v_threshold_high THEN
        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id, v_customer_id, 'LARGE_TRANSACTION', 'HIGH',
            CONCAT('Account ', p_account_no, ' transferred ₹', FORMAT(p_amount,0),
                   ' — above the ₹10,00,000 reporting threshold. Please review.')
        );
    END IF;
END$$

-- Rule 2: Structuring / Smurfing
CREATE PROCEDURE sp_check_structuring(
    IN p_account_no  BIGINT,
    IN p_customer_id VARCHAR(20)
)
BEGIN
    DECLARE v_txn_count      INT;
    DECLARE v_total_24h      DECIMAL(15,2);
    DECLARE v_max_single     DECIMAL(15,2);
    DECLARE v_threshold      DECIMAL(15,2) DEFAULT 1000000.00;
    DECLARE v_min_txn_count  INT           DEFAULT 3;

    SELECT COUNT(*), SUM(amount), MAX(amount)
    INTO   v_txn_count, v_total_24h, v_max_single
    FROM Transaction
    WHERE from_account_no = p_account_no
      AND transaction_status IN ('COMPLETED','PENDING')
      AND transaction_timestamp >= NOW() - INTERVAL 24 HOUR;

    IF v_txn_count >= v_min_txn_count
       AND v_total_24h >= v_threshold
       AND v_max_single < v_threshold
    THEN
        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            NULL, p_customer_id, 'STRUCTURING', 'CRITICAL',
            CONCAT('Account ', p_account_no, ' made ', v_txn_count,
                   ' transactions totaling ₹', FORMAT(v_total_24h,0),
                   ' in 24 hours, each kept below ₹10,00,000 — possible structuring to avoid detection.')
        );

        UPDATE Customer
        SET risk_score = LEAST(risk_score + 30, 100), is_flagged = 1
        WHERE customer_id = p_customer_id;
    END IF;
END$$

-- Rule 3: Velocity Spike
CREATE PROCEDURE sp_check_velocity_spike(
    IN p_customer_id VARCHAR(20),
    IN p_amount      DECIMAL(15,2)
)
BEGIN
    DECLARE v_avg DECIMAL(15,2);
    DECLARE v_std DECIMAL(15,2);
    DECLARE v_z   DECIMAL(10,4);

    SELECT avg_txn_amount, stddev_txn_amount
    INTO   v_avg, v_std
    FROM Customer_Behavior_Profile
    WHERE customer_id = p_customer_id
    ORDER BY window_end DESC
    LIMIT 1;

    IF v_avg IS NOT NULL AND v_std > 0 THEN
        SET v_z = (p_amount - v_avg) / v_std;

        IF v_z > 3.0 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                NULL, p_customer_id, 'VELOCITY_SPIKE', 'HIGH',
                CONCAT('Customer ', p_customer_id, ' made a ₹', FORMAT(p_amount,0),
                       ' transfer — ', ROUND(v_z,1), 'x above their usual average of ₹',
                       FORMAT(v_avg,0), '. Possible account compromise or unusual activity.')
            );
        END IF;
    END IF;
END$$

-- Rule 4: Rapid Movement / Layering
CREATE PROCEDURE sp_check_rapid_movement(
    IN p_to_account_no BIGINT
)
BEGIN
    DECLARE v_customer_id    VARCHAR(20);
    DECLARE v_inflow_2h      DECIMAL(15,2);
    DECLARE v_outflow_2h     DECIMAL(15,2);
    DECLARE v_layering_ratio DECIMAL(5,2);

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_no = p_to_account_no;

    SELECT SUM(amount) INTO v_inflow_2h
    FROM Transaction
    WHERE to_account_no = p_to_account_no
      AND transaction_status = 'COMPLETED'
      AND transaction_timestamp >= NOW() - INTERVAL 2 HOUR;

    SELECT SUM(amount) INTO v_outflow_2h
    FROM Transaction
    WHERE from_account_no = p_to_account_no
      AND transaction_status IN ('COMPLETED','PENDING')
      AND transaction_timestamp >= NOW() - INTERVAL 2 HOUR;

    IF v_inflow_2h > 0 AND v_outflow_2h IS NOT NULL THEN
        SET v_layering_ratio = v_outflow_2h / v_inflow_2h;

        IF v_layering_ratio >= 0.80 AND v_inflow_2h >= 500000 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                NULL, v_customer_id, 'RAPID_MOVEMENT', 'CRITICAL',
                CONCAT('Account ', p_to_account_no, ' received ₹', FORMAT(v_inflow_2h,0),
                       ' and moved out ', ROUND(v_layering_ratio*100,0),
                       '% within 2 hours — classic layering pattern to hide money origin.')
            );
        END IF;
    END IF;
END$$

-- Rule 5: Dormant Account Activated
CREATE PROCEDURE sp_check_dormant_account(
    IN p_account_no     BIGINT,
    IN p_transaction_id INT,
    IN p_amount         DECIMAL(15,2)
)
BEGIN
    DECLARE v_last_txn_date DATETIME;
    DECLARE v_customer_id   VARCHAR(20);
    DECLARE v_days_dormant  INT;

    SELECT customer_id INTO v_customer_id
    FROM Account WHERE account_no = p_account_no;

    SELECT MAX(transaction_timestamp)
    INTO v_last_txn_date
    FROM Transaction
    WHERE (from_account_no = p_account_no OR to_account_no = p_account_no)
      AND transaction_id != p_transaction_id
      AND transaction_status = 'COMPLETED';

    IF v_last_txn_date IS NOT NULL THEN
        SET v_days_dormant = DATEDIFF(NOW(), v_last_txn_date);

        IF v_days_dormant >= 90 AND p_amount >= 100000 THEN
            INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
            VALUES (
                p_transaction_id, v_customer_id, 'DORMANT_ACTIVATED', 'HIGH',
                CONCAT('Account ', p_account_no, ' was inactive for ', v_days_dormant,
                       ' days and just transacted ₹', FORMAT(p_amount,0),
                       '. Possible account takeover or mule account.')
            );
        END IF;
    END IF;
END$$

-- Rule 6: Blacklist Check
CREATE PROCEDURE sp_check_blacklist(
    IN p_transaction_id INT,
    IN p_customer_id    VARCHAR(20),
    IN p_pan            CHAR(10)
)
BEGIN
    DECLARE v_match_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_match_count
    FROM AML_Blacklist
    WHERE (entity_type = 'PAN'  AND entity_value = p_pan);

    IF v_match_count > 0 THEN
        UPDATE Transaction
        SET transaction_status = 'BLOCKED'
        WHERE transaction_id = p_transaction_id;

        INSERT INTO Alert (transaction_id, customer_id, alert_type, severity, description)
        VALUES (
            p_transaction_id, p_customer_id, 'BLACKLIST_MATCH', 'CRITICAL',
            CONCAT('Transaction BLOCKED — PAN ', p_pan,
                   ' is on the AML watchlist. Immediate investigation required.')
        );
    END IF;
END$$

-- Master AML orchestrator
CREATE PROCEDURE sp_run_aml_checks(
    IN p_transaction_id INT
)
BEGIN
    DECLARE v_amount      DECIMAL(15,2);
    DECLARE v_from_acct   BIGINT;
    DECLARE v_to_acct     BIGINT;
    DECLARE v_customer_id VARCHAR(20);
    DECLARE v_pan         CHAR(10);

    SELECT t.amount, t.from_account_no, t.to_account_no,
           c.customer_id, c.PAN_number
    INTO   v_amount, v_from_acct, v_to_acct, v_customer_id, v_pan
    FROM Transaction t
    JOIN Account     a ON a.account_no   = t.from_account_no
    JOIN Customer    c ON c.customer_id  = a.customer_id
    WHERE t.transaction_id = p_transaction_id;

    CALL sp_check_large_transaction(p_transaction_id, v_from_acct, v_amount);
    CALL sp_check_structuring(v_from_acct, v_customer_id);
    CALL sp_check_velocity_spike(v_customer_id, v_amount);
    CALL sp_check_rapid_movement(v_to_acct);
    CALL sp_check_dormant_account(v_from_acct, p_transaction_id, v_amount);
    CALL sp_check_blacklist(p_transaction_id, v_customer_id, v_pan);
END$$

DELIMITER ;

-- =============================================================
-- TRIGGERS
-- =============================================================

DELIMITER $$

-- Trigger: Update balances on PENDING → COMPLETED
CREATE TRIGGER trg_update_balances
AFTER UPDATE ON Transaction
FOR EACH ROW
BEGIN
    IF NEW.transaction_status = 'COMPLETED'
       AND OLD.transaction_status = 'PENDING' THEN
        IF NEW.from_account_no IS NOT NULL THEN
            UPDATE Account SET balance = balance - NEW.amount
            WHERE account_no = NEW.from_account_no;
        END IF;
        IF NEW.to_account_no IS NOT NULL THEN
            UPDATE Account SET balance = balance + NEW.amount
            WHERE account_no = NEW.to_account_no;
        END IF;
    END IF;
END$$

-- Trigger: Prevent overdraft / limit violations (BLOCKED/FAILED bypass all checks)
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

-- =============================================================
-- SCHEDULED EVENTS
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
        DATE_SUB(CURDATE(), INTERVAL 60 DAY),
        CURDATE(),
        COALESCE(AVG(t.amount), 0),
        COUNT(t.transaction_id) / 60.0,
        COALESCE(SUM(t.amount) / 2, 0),
        COALESCE(STDDEV(t.amount), 0),
        COUNT(DISTINCT t.to_account_no)
    FROM Customer c
    LEFT JOIN Account     a ON a.customer_id       = c.customer_id
    LEFT JOIN Transaction t ON t.from_account_no   = a.account_no
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

CREATE EVENT IF NOT EXISTS evt_rebuild_daily_summary
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURDATE(), '01:30:00')
DO
BEGIN
    INSERT INTO Daily_Transaction_Summary
        (account_no, summary_date, total_debit, total_credit,
         txn_count, max_single_txn, distinct_payees)
    SELECT
        COALESCE(from_account_no, to_account_no),
        DATE(transaction_timestamp),
        SUM(CASE WHEN from_account_no IS NOT NULL THEN amount ELSE 0 END),
        SUM(CASE WHEN to_account_no   IS NOT NULL THEN amount ELSE 0 END),
        COUNT(*),
        MAX(amount),
        COUNT(DISTINCT to_account_no)
    FROM Transaction
    WHERE DATE(transaction_timestamp) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
      AND transaction_status = 'COMPLETED'
    GROUP BY COALESCE(from_account_no, to_account_no), DATE(transaction_timestamp)
    ON DUPLICATE KEY UPDATE
        total_debit     = VALUES(total_debit),
        total_credit    = VALUES(total_credit),
        txn_count       = VALUES(txn_count),
        max_single_txn  = VALUES(max_single_txn),
        distinct_payees = VALUES(distinct_payees);
END$$

DELIMITER ;

-- =============================================================
-- MINIMAL SEED (Bank + Branches only)
-- Full data is in realistic_seed_data.sql
-- =============================================================
INSERT INTO Bank (bank_name, hq_location) VALUES
    ('FinGuard National Bank', 'Mumbai, Maharashtra');

INSERT INTO Branch (bank_id, branch_name, IFSC_code, city, state) VALUES
    (1, 'Andheri West Branch',  'FGNB0001234', 'Mumbai',    'Maharashtra'),
    (1, 'T. Nagar Branch',      'FGNB0005678', 'Chennai',   'Tamil Nadu'),
    (1, 'Koramangala Branch',   'FGNB0009012', 'Bangalore', 'Karnataka');

SET FOREIGN_KEY_CHECKS = 1;
-- End of OLTP Schema