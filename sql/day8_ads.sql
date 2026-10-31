-- ============================================================
-- Day 8：ADS 结果表（第 2 周第 3 天）
-- 目的：把 DWS 汇总 + 指标字典口径，包装成报表/大屏直接用的成品表
-- 原则：ADS 从 DWS 取数（复用/快/口径一致），应用业务规则（门槛/排序/主口径）
-- 口径来源：doc/指标字典.md
-- ============================================================

-- ========== 1. ads.ads_overview：整体总览（1 行） ==========
CREATE TABLE ads.ads_overview (
    total_loans INT,                    -- 总贷款笔数
    total_amount DECIMAL(14,2),         -- 总放款金额
    default_cnt INT,                    -- 总违约笔数
    overall_default_rate DECIMAL(8,4),  -- 整体违约率（计数相除）
    weighted_avg_rate DECIMAL(8,4),     -- 金额加权平均利率（指标字典主口径）
    avg_loan DECIMAL(12,2)              -- 平均单笔金额
);

-- 完整版（从 DWS 取数，不重扫明细；加权利率 DWS 没有，回 fact 算）
INSERT INTO ads.ads_overview (total_loans, total_amount, default_cnt, overall_default_rate, weighted_avg_rate, avg_loan)
SELECT
    (SELECT SUM(loan_cnt) FROM dws.dws_date),
    (SELECT SUM(total_amount) FROM dws.dws_date),
    (SELECT SUM(default_cnt) FROM dws.dws_date),
    (SELECT ROUND(SUM(default_cnt)/SUM(loan_cnt), 4) FROM dws.dws_date),
    (SELECT ROUND(SUM(loan_amnt*int_rate)/SUM(loan_amnt),4) FROM dwd.fact_loan),
    (SELECT ROUND(SUM(total_amount)/SUM(loan_cnt),2) FROM dws.dws_date);

-- 当前值：38979 / 417052675.00 / 6203 / 0.1591 / 0.1261 / 10699.42

-- ========== 2. ads.ads_region_default：地区违约率排行 ==========
CREATE TABLE ads.ads_region_default (
    state_code VARCHAR(20) PRIMARY KEY,  -- 州代码
    loan_cnt INT,                       -- 该州贷款笔数
    default_cnt INT,                    -- 该州违约笔数
    default_rate DECIMAL(8,4)           -- 该州违约率
);

-- 关键：WHERE loan_cnt >= 50 = Day7 决议的"展示层样本门槛"
-- 过滤掉 NE(11笔/54.55%)、IN(19笔)、ME(3笔/0%) 等小样本失真州
INSERT INTO ads.ads_region_default (state_code, loan_cnt, default_cnt, default_rate)
SELECT di.state_code, dd.loan_cnt, dd.default_cnt, dd.default_rate
FROM dws.dws_region dd
JOIN dwd.dim_region di ON dd.region_key = di.region_key
WHERE dd.loan_cnt >= 50
ORDER BY dd.default_rate DESC;

-- 当前值：43 行（50 州 - 小样本州）；排行前5：NV 0.2537 / SD 0.2000 / FL 0.1982 / MO 0.1920 / MT 0.1868

-- ========== 3. ads.ads_month_trend：按月违约率趋势 ==========
CREATE TABLE ads.ads_month_trend (
    year INT,
    month INT,
    loan_cnt INT,
    default_cnt INT,
    default_rate DECIMAL(8,4),
    PRIMARY KEY (year, month)
);

-- 直接从 DWS 搬数（ADS 复用 DWS 的典型场景）
INSERT INTO ads.ads_month_trend (year, month, loan_cnt, default_cnt, default_rate)
SELECT year, month, loan_cnt, default_cnt, default_rate
FROM dws.dws_date;

-- 当前值：55 行（2007-06~2011-12）；笔数之和=38979、违约之和=6203

-- ========== 验收查询 ==========
SELECT * FROM ads.ads_overview;
SELECT COUNT(*) FROM ads.ads_region_default;              -- 43
SELECT * FROM ads.ads_region_default ORDER BY default_rate DESC LIMIT 10;
SELECT COUNT(*), SUM(loan_cnt), SUM(default_cnt) FROM ads.ads_month_trend;  -- 55 / 38979 / 6203
