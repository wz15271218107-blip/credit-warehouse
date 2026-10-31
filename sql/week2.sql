-- ============================================================
-- 信贷违约数仓 · 第 2 周总入口（Day 6-9）
-- 主题：DWS 预汇总 → ADS 成品 → 数据质量校验
-- 前置：week1.sql 已跑通（src/ods/dwd/dim/fact 全部就绪）
-- 复跑顺序：本文件从上到下依次执行；Workbench 多语句只选中要跑的段
-- ============================================================

-- ############################################################
-- Day 6：DWS 主题汇总（按客户 / 按月 / 按州预汇总）
-- ############################################################

-- 6.1 dws_customer：每客户一行
CREATE TABLE dws.dws_customer (
    customer_key INT PRIMARY KEY,
    loan_cnt INT,
    total_amount DECIMAL(14,2),
    default_cnt INT
);
INSERT INTO dws.dws_customer
SELECT f.customer_key,
       COUNT(*) AS loan_cnt,
       ROUND(SUM(f.loan_amnt),2) AS total_amount,
       SUM(f.is_default) AS default_cnt
FROM dwd.fact_loan f
GROUP BY f.customer_key;
-- 38979 行；SUM(loan_cnt)=38979, SUM(default_cnt)=6203

-- 6.2 dws_date：每月一行（复合主键 year+month）
CREATE TABLE dws.dws_date (
    year INT,
    month INT,
    loan_cnt INT,
    total_amount DECIMAL(14,2),
    default_cnt INT,
    default_rate DECIMAL(8,4),
    PRIMARY KEY (year, month)
);
INSERT INTO dws.dws_date
SELECT d.year, d.month,
       COUNT(*) AS loan_cnt,
       ROUND(SUM(f.loan_amnt),2) AS total_amount,
       SUM(f.is_default) AS default_cnt,
       ROUND(AVG(f.is_default),4) AS default_rate
FROM dwd.fact_loan f
JOIN dwd.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month;
-- 55 行（2007-06 ~ 2011-12）

-- 6.3 dws_region：每州一行
CREATE TABLE dws.dws_region (
    region_key INT PRIMARY KEY,
    loan_cnt INT,
    total_amount DECIMAL(14,2),
    default_cnt INT,
    default_rate DECIMAL(8,4)
);
INSERT INTO dws.dws_region
SELECT f.region_key,
       COUNT(*) AS loan_cnt,
       ROUND(SUM(f.loan_amnt),2) AS total_amount,
       SUM(f.is_default) AS default_cnt,
       ROUND(AVG(f.is_default),4) AS default_rate
FROM dwd.fact_loan f
GROUP BY f.region_key;
-- 50 行

-- ############################################################
-- Day 8：ADS 结果表（报表/大屏直接用的成品）
-- ############################################################

-- 8.1 ads_overview：整体总览 1 行
CREATE TABLE ads.ads_overview (
    total_loans INT,
    total_amount DECIMAL(14,2),
    default_cnt INT,
    overall_default_rate DECIMAL(8,4),
    weighted_avg_rate DECIMAL(8,4),
    avg_loan DECIMAL(12,2)
);
INSERT INTO ads.ads_overview
SELECT
    (SELECT SUM(loan_cnt) FROM dws.dws_date),
    (SELECT SUM(total_amount) FROM dws.dws_date),
    (SELECT SUM(default_cnt) FROM dws.dws_date),
    (SELECT ROUND(SUM(default_cnt)/SUM(loan_cnt),4) FROM dws.dws_date),
    (SELECT ROUND(SUM(loan_amnt*int_rate)/SUM(loan_amnt),4) FROM dwd.fact_loan),
    (SELECT ROUND(SUM(total_amount)/SUM(loan_cnt),2) FROM dws.dws_date);
-- 结果：38979 / 417052675.00 / 6203 / 0.1591 / 0.1261 / 10699.42

-- 8.2 ads_region_default：地区违约率排行（落地 loan_cnt>=50 门槛）
CREATE TABLE ads.ads_region_default (
    state_code VARCHAR(20) PRIMARY KEY,
    loan_cnt INT,
    default_cnt INT,
    default_rate DECIMAL(8,4)
);
INSERT INTO ads.ads_region_default
SELECT di.state_code, dd.loan_cnt, dd.default_cnt, dd.default_rate
FROM dws.dws_region dd
JOIN dwd.dim_region di ON dd.region_key = di.region_key
WHERE dd.loan_cnt >= 50
ORDER BY dd.default_rate DESC;
-- 43 行；排行前5：NV 0.2537 / SD 0.2000 / FL 0.1982 / MO 0.1920 / MT 0.1868

-- 8.3 ads_month_trend：月度趋势（DWS 直搬）
CREATE TABLE ads.ads_month_trend (
    year INT,
    month INT,
    loan_cnt INT,
    default_cnt INT,
    default_rate DECIMAL(8,4),
    PRIMARY KEY (year, month)
);
INSERT INTO ads.ads_month_trend
SELECT year, month, loan_cnt, default_cnt, default_rate
FROM dws.dws_date;
-- 55 行；SUM(loan_cnt)=38979, SUM(default_cnt)=6203

-- ############################################################
-- Day 9：数据质量校验（8 项，复跑验证）
-- 详见 doc/数据质量报告.md
-- ############################################################

-- 9.1 唯一性：dwd.id 无重复（预期 0 行）
SELECT id, COUNT(*) AS cnt FROM dwd.loan_dwd GROUP BY id HAVING cnt > 1;

-- 9.2 完整性：四层行数链
SELECT 'src' AS layer, COUNT(*) AS rows_cnt FROM src.loan_raw
UNION ALL SELECT 'ods', COUNT(*) FROM ods.loan_ods
UNION ALL SELECT 'dwd', COUNT(*) FROM dwd.loan_dwd
UNION ALL SELECT 'fact', COUNT(*) FROM dwd.fact_loan;

-- 9.3 完整性：剔除勾稽（42542 - 38979 = 3563）
SELECT (SELECT COUNT(*) FROM ods.loan_ods) AS ods_cnt,
       (SELECT COUNT(*) FROM dwd.loan_dwd) AS dwd_cnt,
       (SELECT COUNT(*) FROM ods.loan_ods) - (SELECT COUNT(*) FROM dwd.loan_dwd) AS removed;

-- 9.4 空值率：fact 外键 NULL（预期 0/0/0）
SELECT SUM(customer_key IS NULL) AS null_customer,
       SUM(date_key IS NULL) AS null_date,
       SUM(region_key IS NULL) AS null_region
FROM dwd.fact_loan;

-- 9.5 准确性：DWS 三表交叉勾稽（均 38979/6203）
SELECT 'dws_customer' AS layer, SUM(loan_cnt) AS loans, SUM(default_cnt) AS defaults FROM dws.dws_customer
UNION ALL SELECT 'dws_date', SUM(loan_cnt), SUM(default_cnt) FROM dws.dws_date
UNION ALL SELECT 'dws_region', SUM(loan_cnt), SUM(default_cnt) FROM dws.dws_region;

-- 9.6 准确性：fact 明细金额（417052675.00）
SELECT ROUND(SUM(loan_amnt),2) FROM dwd.fact_loan;

-- 9.7 一致性：ads_month_trend 勾稽（55/38979/6203）
SELECT COUNT(*), SUM(loan_cnt), SUM(default_cnt) FROM ads.ads_month_trend;

-- 9.8 一致性说明：ads_region_default（43 行/38867，差112=门槛过滤7州）
SELECT COUNT(*) AS state_cnt, SUM(loan_cnt) AS region_loans FROM ads.ads_region_default;
