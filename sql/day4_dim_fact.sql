-- =============================================
-- 信贷违约数仓 · Day 4 SQL 归档（星型结构）
-- 内容：3 张维度表 + 1 张事实表 + 四表 JOIN 验证
-- 验证：fact_loan=38979；JOIN 出完整记录 ✅
-- =============================================

-- ---------------------------------------------
-- 维度表 1：日期维度（字典：一个日期一行）
-- 要点：代理键 date_key 自增；业务键 full_date 唯一
--       YEAR/MONTH/QUARTER 三个提取函数算出年月季
-- ---------------------------------------------
CREATE TABLE dwd.dim_date (
    date_key INT AUTO_INCREMENT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INT,
    month INT,
    quarter INT
);

INSERT INTO dwd.dim_date (full_date, year, month, quarter)
SELECT DISTINCT issue_d, YEAR(issue_d), MONTH(issue_d), QUARTER(issue_d)
FROM dwd.loan_dwd
ORDER BY issue_d;

-- ---------------------------------------------
-- 维度表 2：地区维度（字典：一个州一行）
-- 要点：DISTINCT 去重出 50 个州；ORDER BY 保证编号有规律
-- ---------------------------------------------
CREATE TABLE dwd.dim_region (
    region_key INT AUTO_INCREMENT PRIMARY KEY,
    state_code VARCHAR(10) NOT NULL UNIQUE
);

INSERT INTO dwd.dim_region (state_code)
SELECT DISTINCT addr_state
FROM dwd.loan_dwd
ORDER BY addr_state;

-- ---------------------------------------------
-- 维度表 3：客户维度（字典：一个借款人一行）
-- 要点：member_id 从 ODS JOIN 取回（DWD 未保留）
--       annual_inc 空串 → NULL（严格模式 1366 坑，不能硬转 0）
-- ---------------------------------------------
CREATE TABLE dwd.dim_customer (
    customer_key INT AUTO_INCREMENT PRIMARY KEY,
    member_id VARCHAR(20) NOT NULL UNIQUE,
    emp_title VARCHAR(100),
    annual_inc DECIMAL(12,2),
    home_ownership VARCHAR(20),
    emp_length VARCHAR(20)
);

INSERT INTO dwd.dim_customer (member_id, emp_title, annual_inc, home_ownership, emp_length)
SELECT DISTINCT o.member_id, d.emp_title,
       CASE WHEN TRIM(d.annual_inc) = '' THEN NULL
            ELSE CAST(d.annual_inc AS DECIMAL(12,2)) END,
       d.home_ownership, d.emp_length
FROM dwd.loan_dwd d
JOIN ods.loan_ods o ON d.id = o.id;

-- ---------------------------------------------
-- 事实表：一笔贷款一行
-- 要点：3 个外键存维度表的自增编号（不存长字符串）
--       loan_amnt/installment 文本转数值；term TRIM 去前导空格
--       JOIN 链：loan_dwd → ods(拿member_id) → 3张维度表(拿key)
-- ---------------------------------------------
CREATE TABLE dwd.fact_loan (
    loan_id VARCHAR(20) PRIMARY KEY,
    customer_key INT,
    date_key INT,
    region_key INT,
    loan_amnt DECIMAL(12,2),
    int_rate DECIMAL(6,4),
    installment DECIMAL(10,2),
    term VARCHAR(20),
    is_default INT
);

INSERT INTO dwd.fact_loan
SELECT
    d.id,
    dc.customer_key,
    dd.date_key,
    dr.region_key,
    CAST(d.loan_amnt AS DECIMAL(12,2)),
    d.int_rate,
    CAST(d.installment AS DECIMAL(10,2)),
    TRIM(d.term),
    d.is_default
FROM dwd.loan_dwd d
JOIN ods.loan_ods o ON d.id = o.id
JOIN dwd.dim_customer dc ON dc.member_id = o.member_id
JOIN dwd.dim_date dd ON dd.full_date = d.issue_d
JOIN dwd.dim_region dr ON dr.state_code = d.addr_state;

-- ---------------------------------------------
-- 【验证】星型结构
-- ---------------------------------------------
SELECT COUNT(*) FROM dwd.dim_date;     -- 55
SELECT COUNT(*) FROM dwd.dim_region;   -- 50
SELECT COUNT(*) FROM dwd.dim_customer; -- 38979
SELECT COUNT(*) FROM dwd.fact_loan;    -- 38979

-- 事实表 JOIN 三张维度表，拼出一条完整贷款档案
SELECT
    f.loan_id,
    c.member_id, c.emp_title, c.home_ownership,
    d.full_date, d.year, d.month, d.quarter,
    r.state_code,
    f.loan_amnt, f.int_rate, f.is_default
FROM dwd.fact_loan f
JOIN dwd.dim_customer c ON f.customer_key = c.customer_key
JOIN dwd.dim_date d ON f.date_key = d.date_key
JOIN dwd.dim_region r ON f.region_key = r.region_key
LIMIT 5;
