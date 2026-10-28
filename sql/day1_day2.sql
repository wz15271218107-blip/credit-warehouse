-- =============================================
-- 信贷违约数仓 · Day 1-2 已完成 SQL 归档
-- 说明：本文件收录 Day 1（建源库）和 Day 2（建四层库 + ODS）全部已验证 SQL
-- 执行顺序：从上到下
-- =============================================

-- ---------------------------------------------
-- 【Day 1】建源库 src
-- 数据导入用脚本: scripts/import_csv_to_mysql.py（秒级批量导入）
-- ---------------------------------------------
CREATE DATABASE IF NOT EXISTS src;

-- ---------------------------------------------
-- 【Day 2】建数仓四层库
-- ---------------------------------------------
CREATE DATABASE IF NOT EXISTS ods;
CREATE DATABASE IF NOT EXISTS dwd;
CREATE DATABASE IF NOT EXISTS dws;
CREATE DATABASE IF NOT EXISTS ads;

-- ---------------------------------------------
-- 【Day 2】建 ODS 表（复制 raw 结构，不复制数据）
-- ---------------------------------------------
CREATE TABLE ods.loan_ods LIKE src.loan_raw;

-- ---------------------------------------------
-- 【Day 2】ODS 加时间戳列：dt(数据日期) + etl_time(入仓时间)
-- 为什么加：留底、可追溯、支持按天增量
-- ---------------------------------------------
ALTER TABLE ods.loan_ods ADD COLUMN dt DATE, ADD COLUMN etl_time DATETIME;

-- ---------------------------------------------
-- 【Day 2】从 raw 灌数据进 ODS（52列 + 今天日期 + 此刻时间）
-- ---------------------------------------------
INSERT INTO ods.loan_ods SELECT *, CURRENT_DATE, NOW() FROM src.loan_raw;

-- ---------------------------------------------
-- 【Day 2】验证
-- ---------------------------------------------
-- 行数应 = 42542
SELECT COUNT(*) FROM ods.loan_ods;
-- 前3行 + 时间戳检查
SELECT * FROM ods.loan_ods LIMIT 3;
