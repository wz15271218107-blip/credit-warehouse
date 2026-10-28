-- =============================================
-- 信贷违约数仓 · Day 3 已完成 SQL 归档
-- 内容：DWD 清洗表（核心：口径过滤 + 违约标签 + 空格标准化）
-- 验证：COUNT(*)=38979，is_default 0:32776 / 1:6203 ✅
-- =============================================

-- ---------------------------------------------
-- 【侦查】贷款状态分布（定义违约口径的依据）
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
--   1. 只保留已终结贷款（白名单，剔除进行中状态）→ 38979 行
--   2. 过滤空行垃圾数据（id <> ''）
--   3. 空格标准化：REPLACE(loan_status,'  ',' ') 去双空格
--   4. 违约打标签：CASE WHEN ... IN (违约名单) THEN 1 ELSE 0
-- 教训：同一字段在 SELECT/CASE/WHERE 多处使用时，处理必须一致
-- ---------------------------------------------
DROP TABLE IF EXISTS dwd.loan_dwd;

CREATE TABLE dwd.loan_dwd AS
SELECT
    id, loan_amnt, int_rate, term, installment, annual_inc,
    emp_title, emp_length, home_ownership, addr_state, issue_d,
    REPLACE(loan_status, '  ', ' ') AS loan_status,
    CASE WHEN REPLACE(loan_status, '  ', ' ') IN ('Charged Off', 'Default', 'Does not meet the credit policy. Status:Charged Off')
         THEN 1 ELSE 0 END AS is_default
FROM ods.loan_ods
WHERE id <> ''
  AND REPLACE(loan_status, '  ', ' ') IN ('Fully Paid', 'Charged Off', 'Default',
      'Does not meet the credit policy. Status:Fully Paid',
      'Does not meet the credit policy. Status:Charged Off');

-- ---------------------------------------------
-- 【验证】
-- ---------------------------------------------
-- 行数应 = 38979
SELECT COUNT(*) FROM dwd.loan_dwd;
-- 标签分布应 = 0:32776 / 1:6203
SELECT is_default, COUNT(*) FROM dwd.loan_dwd GROUP BY is_default;
-- 抽查前 5 行
SELECT * FROM dwd.loan_dwd LIMIT 5;
