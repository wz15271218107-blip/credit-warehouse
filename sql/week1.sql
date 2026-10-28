-- ============================================================
-- 信贷违约数仓 · 第 1 周全部 SQL（Week 1）
-- 数据：Lending Club 贷款数据（LoanStats3a.csv，42542 行）
-- 链路：src.loan_raw → ods.loan_ods → dwd.loan_dwd → 星型结构
--
-- 执行顺序（每段都可在 Workbench 中选中执行）：
--   一、Day1-2：建库 + ODS（src → ods.loan_ods）
--   二、Day3  ：DWD 清洗（dwd.loan_dwd，38979 行）
--   三、Day4  ：星型结构（dim_date / dim_region / dim_customer / fact_loan）
--   四、Day5  ：第 1 周验收查询
-- 完整验证结果见 doc/清洗记录.md、doc/架构图.md、README.md
-- ============================================================

-- ============================================================
-- 一、Day 1-2：建源库 + 建四层库 + ODS
-- ============================================================

-- 数据导入用脚本 scripts/import_csv_to_mysql.py（批量导入，秒级）
CREATE DATABASE IF NOT EXISTS src;

-- 数仓四层库
CREATE DATABASE IF NOT EXISTS ods;
CREATE DATABASE IF NOT EXISTS dwd;
CREATE DATABASE IF NOT EXISTS dws;
CREATE DATABASE IF NOT EXISTS ads;

-- ODS 表：复制 raw 结构（52列，不复制数据）
CREATE TABLE ods.loan_ods LIKE src.loan_raw;

-- ODS 加时间戳：dt(数据日期) + etl_time(入仓时间)，用于留底/追溯/按天增量
ALTER TABLE ods.loan_ods ADD COLUMN dt DATE, ADD COLUMN etl_time DATETIME;

-- 从 raw 灌数进 ODS（52列 + 当天日期 + 此刻时间）
INSERT INTO ods.loan_ods SELECT *, CURRENT_DATE, NOW() FROM src.loan_raw;

-- 验证：42542 行
SELECT COUNT(*) FROM ods.loan_ods;

-- ============================================================
-- 二、Day 3：DWD 清洗（口径过滤 + 打标签 + 标准化）
-- ============================================================

-- 侦查：状态分布（定义违约口径的依据）
SELECT loan_status, COUNT(*) AS cnt
FROM ods.loan_ods
GROUP BY loan_status
ORDER BY cnt DESC;

-- 建 DWD 清洗表（CTAS），清洗动作：
--   1. 白名单只留已终结贷款（剔除进行中 3556 + 状态空 7）→ 38979
--   2. 过滤空行（id <> ''）
--   3. 双空格标准化 REPLACE(loan_status,'  ',' ')
--   4. 违约打标签 CASE WHEN ... IN(违约名单) THEN 1 ELSE 0
--   5. 日期格式化 STR_TO_DATE(CONCAT(issue_d,'-01'),'%b-%Y-%d')
--      （直接 STR_TO_DATE 缺日补0 会被 sql_mode NO_ZERO_DATE 拒绝）
--   6. 利率转数值 CAST(REPLACE(TRIM(int_rate),'%','') AS DECIMAL(6,4))/100
--      （空利率 → NULL，避免污染均值）
--   7. 职位缺失 → 'Unknown'（空串 2625 行，保留行便于分组）
DROP TABLE IF EXISTS dwd.loan_dwd;

CREATE TABLE dwd.loan_dwd AS
SELECT
    id,
    loan_amnt,
    CASE WHEN TRIM(int_rate) = '' THEN NULL
         ELSE CAST(REPLACE(TRIM(int_rate), '%', '') AS DECIMAL(6,4)) / 100
    END AS int_rate,
    term,
    installment,
    annual_inc,
    CASE WHEN emp_title IS NULL OR TRIM(emp_title) = '' THEN 'Unknown'
         ELSE TRIM(emp_title)
    END AS emp_title,
    emp_length,
    home_ownership,
    addr_state,
    STR_TO_DATE(CONCAT(issue_d, '-01'), '%b-%Y-%d') AS issue_d,
    REPLACE(loan_status, '  ', ' ') AS loan_status,
    CASE WHEN REPLACE(loan_status, '  ', ' ') IN ('Charged Off', 'Default', 'Does not meet the credit policy. Status:Charged Off')
         THEN 1 ELSE 0 END AS is_default
FROM ods.loan_ods
WHERE id <> ''
  AND REPLACE(loan_status, '  ', ' ') IN ('Fully Paid', 'Charged Off', 'Default',
      'Does not meet the credit policy. Status:Fully Paid',
      'Does not meet the credit policy. Status:Charged Off');

-- DWD 验证：38979 行；is_default 0:32776 / 1:6203；issue_d 无 NULL
SELECT COUNT(*) FROM dwd.loan_dwd;
SELECT is_default, COUNT(*) FROM dwd.loan_dwd GROUP BY is_default;

-- ============================================================
-- 三、Day 4：星型结构（3 张维度表 + 1 张事实表）
-- ============================================================

-- 维度表1：日期字典（55 行：2007-06 ~ 2011-12）
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

-- 维度表2：地区字典（50 个州）
CREATE TABLE dwd.dim_region (
    region_key INT AUTO_INCREMENT PRIMARY KEY,
    state_code VARCHAR(10) NOT NULL UNIQUE
);

INSERT INTO dwd.dim_region (state_code)
SELECT DISTINCT addr_state
FROM dwd.loan_dwd
ORDER BY addr_state;

-- 维度表3：客户字典（38979 个借款人，member_id 从 ODS JOIN 取回）
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

-- 事实表：一笔贷款一行（3 个外键 + 数字指标）
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

-- 星型结构验证
SELECT COUNT(*) FROM dwd.dim_date;     -- 55
SELECT COUNT(*) FROM dwd.dim_region;   -- 50
SELECT COUNT(*) FROM dwd.dim_customer; -- 38979
SELECT COUNT(*) FROM dwd.fact_loan;    -- 38979

-- ============================================================
-- 四、Day 5：第 1 周验收查询（星型 JOIN 完整档案）
-- ============================================================

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
