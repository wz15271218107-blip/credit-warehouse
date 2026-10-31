-- ============================================================
-- Day 9：数据质量校验脚本（全链路勾稽）
-- 维度：唯一性 / 完整性 / 准确性 / 空值率 / 一致性
-- 用法：数据重灌后一键重跑；预期结果见 doc/数据质量报告.md
-- ============================================================

-- ========== 1. 唯一性：DWD 明细 id 无重复（预期 0 行）==========
SELECT id, COUNT(*) AS cnt
FROM dwd.loan_dwd
GROUP BY id
HAVING cnt > 1;

-- ========== 2. 完整性：四层行数勾稽链 ==========
SELECT 'src' AS layer, COUNT(*) AS rows_cnt FROM src.loan_raw
UNION ALL
SELECT 'ods', COUNT(*) FROM ods.loan_ods
UNION ALL
SELECT 'dwd', COUNT(*) FROM dwd.loan_dwd
UNION ALL
SELECT 'fact', COUNT(*) FROM dwd.fact_loan;
-- 预期：42542 / 42542 / 38979 / 38979

-- ========== 3. 完整性：剔除勾稽（ods - dwd = 3563）==========
SELECT
    (SELECT COUNT(*) FROM ods.loan_ods) AS ods_cnt,
    (SELECT COUNT(*) FROM dwd.loan_dwd) AS dwd_cnt,
    (SELECT COUNT(*) FROM ods.loan_ods) - (SELECT COUNT(*) FROM dwd.loan_dwd) AS removed;
-- 预期：42542 / 38979 / 3563

-- ========== 4. 空值率：fact 外键 NULL（预期 0/0/0）==========
SELECT
    SUM(customer_key IS NULL) AS null_customer,
    SUM(date_key IS NULL)     AS null_date,
    SUM(region_key IS NULL)   AS null_region
FROM dwd.fact_loan;

-- ========== 5. 准确性：DWS 三表笔数/违约之和（均应 38979/6203）==========
SELECT 'dws_customer' AS layer, SUM(loan_cnt) AS loans, SUM(default_cnt) AS defaults FROM dws.dws_customer
UNION ALL
SELECT 'dws_date', SUM(loan_cnt), SUM(default_cnt) FROM dws.dws_date
UNION ALL
SELECT 'dws_region', SUM(loan_cnt), SUM(default_cnt) FROM dws.dws_region;

-- ========== 6. 准确性：fact 明细金额基准（应 417052675.00）==========
SELECT ROUND(SUM(loan_amnt), 2) AS fact_total_amount FROM dwd.fact_loan;

-- ========== 7. 一致性：ads_month_trend 勾稽（55行/38979/6203）==========
SELECT COUNT(*) AS rows_cnt, SUM(loan_cnt) AS loans, SUM(default_cnt) AS defaults
FROM ads.ads_month_trend;

-- ========== 8. 一致性说明：ads_region_default 笔数和（差112=门槛过滤7州）==========
SELECT COUNT(*) AS state_cnt, SUM(loan_cnt) AS region_loans
FROM ads.ads_region_default;
-- 预期：43 行 / 38867（与明细差 112，为 loan_cnt>=50 门槛过滤的小样本州，见报告第三节）
