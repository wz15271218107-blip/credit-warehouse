-- =============================================
-- 信贷违约数仓 · Day 3 DWD 清洗 SQL（最终版）
-- 清洗动作：口径过滤 + 空行清理 + 空格标准化 + 违约打标签
--          + 日期格式化 + 利率转数值 + 职位缺失处理
-- 验证：COUNT(*)=38979；is_default 0:32776/1:6203；issue_d 无 NULL ✅
-- =============================================

-- ---------------------------------------------
-- 【侦查】贷款状态分布（定义违约口径的依据）
-- 分布总和必须 = 42542（勾稽：每行都有去处）
-- ---------------------------------------------
SELECT loan_status, COUNT(*) AS cnt
FROM ods.loan_ods
GROUP BY loan_status
ORDER BY cnt DESC;

-- 【侦查】id 重复情况（发现 4 行 id 为空的全空垃圾行）
SELECT id, COUNT(*) AS cnt
FROM ods.loan_ods
GROUP BY id
HAVING COUNT(*) > 1;

-- ---------------------------------------------
-- 【核心】建 DWD 清洗表（CTAS：建表+灌数一步到位）
-- 清洗动作：
--   1. 白名单过滤：只保留已终结贷款（剔除进行中 + 状态为空）→ 38979
--   2. 过滤空行垃圾数据：id <> ''
--   3. 空格标准化：REPLACE(loan_status,'  ',' ') 去双空格
--   4. 违约打标签：CASE WHEN ... IN (违约名单) THEN 1 ELSE 0
--   5. 日期格式化：STR_TO_DATE(CONCAT(issue_d,'-01'),'%b-%Y-%d')
--      -- 直接 STR_TO_DATE(issue_d,'%b-%Y') 会因缺日→补0→被
--      -- sql_mode(NO_ZERO_DATE) 拒绝返回 NULL，必须先拼 '-01'
--   6. 利率转数值：CAST(REPLACE(TRIM(int_rate),'%','') AS DECIMAL(6,4))/100
--      -- TRIM 去前导空格；空利率转 NULL 而非 0（避免污染均值）
--   7. 职位缺失处理：空串/空值 → 'Unknown'（保留行，便于分组统计）
-- 教训：同一字段在 SELECT/CASE/WHERE 多处使用时，处理必须一致
-- ---------------------------------------------
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

-- ---------------------------------------------
-- 【验证】全部通过（2026-10-28）
-- ---------------------------------------------
SELECT COUNT(*) FROM dwd.loan_dwd;                                  -- 38979
SELECT is_default, COUNT(*) FROM dwd.loan_dwd GROUP BY is_default;  -- 0:32776 / 1:6203
SELECT issue_d, int_rate, emp_title FROM dwd.loan_dwd LIMIT 5;      -- 2011-12-01 / 0.10xx / Unknown...
SELECT COUNT(*) FROM dwd.loan_dwd WHERE issue_d IS NULL;            -- 0
SELECT MIN(int_rate), MAX(int_rate), AVG(int_rate) FROM dwd.loan_dwd;  -- 0.0542 / 0.2440 / 0.1194
