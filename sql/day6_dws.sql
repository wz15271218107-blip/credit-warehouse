-- ============================================================
-- Day 6：DWS 主题汇总（第 2 周第 1 天）
-- 目的：把星型结构（fact_loan + 维度表）按主题预汇总成 3 张表
-- 核心：GROUP BY + 聚合函数；0/1 求和技巧（SUM(is_default)=违约笔数）
-- 勾稽：三张表"笔数之和"都 = fact 行数 38979
-- ============================================================

-- ========== 1. dws.dws_customer：按客户汇总（38979 行） ==========
CREATE TABLE dws.dws_customer (
    customer_key INT PRIMARY KEY,          -- 客户编号（对应 fact 外键）
    loan_cnt INT,                          -- 贷款笔数
    total_amount DECIMAL(12,2),            -- 放款总额（金额，2位小数）
    default_cnt INT,                       -- 违约笔数（SUM 0/1 标签）
    default_rate DECIMAL(8,4)              -- 违约率（AVG 0/1 标签，4位小数）
);

INSERT INTO dws.dws_customer (customer_key, loan_cnt, total_amount, default_cnt, default_rate)
SELECT customer_key,
       COUNT(*) AS loan_cnt,
       SUM(loan_amnt) AS total_amount,
       SUM(is_default) AS default_cnt,
       ROUND(AVG(is_default), 4) AS default_rate
FROM dwd.fact_loan
GROUP BY customer_key;

-- ========== 2. dws.dws_date：按月汇总（55 行：2007-06 ~ 2011-12） ==========
CREATE TABLE dws.dws_date (
    year INT,
    month INT,
    loan_cnt INT,
    total_amount DECIMAL(12,2),
    default_cnt INT,
    default_rate DECIMAL(8,4),
    PRIMARY KEY (year, month)              -- 复合主键：一个年月一行
);

INSERT INTO dws.dws_date (year, month, loan_cnt, total_amount, default_cnt, default_rate)
SELECT dd.year, dd.month,
       COUNT(*),
       SUM(f.loan_amnt),
       SUM(f.is_default),
       ROUND(AVG(f.is_default), 4)
FROM dwd.fact_loan f
JOIN dwd.dim_date dd ON f.date_key = dd.date_key
GROUP BY dd.year, dd.month;

-- ========== 3. dws.dws_region：按地区汇总（50 行 = 50 个州） ==========
CREATE TABLE dws.dws_region (
    region_key INT PRIMARY KEY,
    loan_cnt INT,
    total_amount DECIMAL(12,2),
    default_cnt INT,
    default_rate DECIMAL(8,4)
);

INSERT INTO dws.dws_region (region_key, loan_cnt, total_amount, default_cnt, default_rate)
SELECT dr.region_key,
       COUNT(*),
       SUM(f.loan_amnt),
       SUM(f.is_default),
       ROUND(AVG(f.is_default), 4)
FROM dwd.fact_loan f
JOIN dwd.dim_region dr ON f.region_key = dr.region_key
GROUP BY dr.region_key;

-- ========== 验收：三表行数 + 勾稽 ==========
SELECT COUNT(*) FROM dws.dws_customer; -- 38979
SELECT COUNT(*) FROM dws.dws_date;     -- 55
SELECT COUNT(*) FROM dws.dws_region;   -- 50

-- 勾稽：每张表的笔数之和都必须 = 38979（汇总=明细）
SELECT 'customer' AS tbl, SUM(loan_cnt) AS total_loans FROM dws.dws_customer
UNION ALL
SELECT 'date', SUM(loan_cnt) FROM dws.dws_date
UNION ALL
SELECT 'region', SUM(loan_cnt) FROM dws.dws_region;
