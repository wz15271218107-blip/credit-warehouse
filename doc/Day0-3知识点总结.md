# 数据工程速成 · Day 0-3 全知识点总结

> 日期：2026-10-28 · 项目：信贷违约数仓（credit-warehouse）
> 本文件汇总今天从零到"第一张数仓表"的全部知识点：概念、SQL、踩坑、方法论
> 配套文件：`doc/Git-GitHub从零入门笔记.md`（Git 专项）、`sql/day1_day2.sql`、`sql/day3_dwd.sql`

---

## 一、今天做了什么（全景地图）

```
Day 0 ✅  环境+GitHub：MySQL 8.0 连接、Git 配置、GitHub 建仓、数据下载(42542行)
Day 1 ✅  数据落库：src.loan_raw（42542 行 × 52 列）
Day 2 ✅  数仓分层 + ODS：ods.loan_ods（+dt +etl_time，42542 行）
Day 3 ✅  DWD 清洗核心：dwd.loan_dwd（38979 行 × 13 列，违约标签）
```

**今天之后你手里的东西**：一台能跑的 MySQL、一个不断提交的 GitHub 仓库、一张"洗干净的明细表"。

---

## 二、Git & GitHub（Day 0）—— 速记版

### 心智模型
- **Git** = 本地存档工具（给文件夹拍快照）
- **GitHub** = 云端保险柜（存快照，防丢、可展示）

### 核心流程（8 步口诀：配身份 → 开存档 → 加文件 → 拍快照 → 定名字 → 指地址 → 推上去）

| 命令 | 大白话 |
|---|---|
| `git config --global user.name/email` | 告诉 Git 你是谁（配一次即可） |
| `git init` | 当前文件夹开启存档功能 |
| `git add .`（或指定文件） | 把改动放进"购物车"（暂存区） |
| `git commit -m "说明"` | 拍快照存版本（备注=这版干了啥） |
| `git branch -M main` | 主分支命名 main |
| `git remote add origin 地址` | 告诉 Git 云保险柜地址（静默成功） |
| `git push` | 上传到 GitHub |
| `git status` / `git log --oneline` | 看状态 / 看版本历史 |

### 认证（token 机制）
- GitHub 不用密码登录命令行，用 **Personal Access Token**（`ghp_` 开头）
- 生成：头像 → Settings → Developer settings → Personal access tokens → Tokens (classic) → 勾 repo → Generate
- **粘贴后屏幕不显示字符是正常的**，直接回车
- **铁律：token 绝不外发，泄露立即删除重新生成**

### 提交规范（今天确定的节奏）
- **每完成一个里程碑就提交一次**（小步高频），不要攒到最后
- 提交前先 `git status` 看改动
- 备注写清"这个版本干了什么"

---

## 三、数仓分层（Day 2）

### 四层模型（流水线四个工位，不是副本！）

| 层 | 干什么 | 比喻 |
|---|---|---|
| ODS 贴源层 | 原始数据原样存 + 时间戳 | 仓库收货区 |
| DWD 明细层 | 清洗 + 建模（事实/维度表） | 加工车间 |
| DWS 汇总层 | 按主题轻度汇总 | 半成品库 |
| ADS 应用层 | 直接给报表/大屏 | 成品展厅 |

**记忆口诀：原始进 ODS、洗干净进 DWD、按主题汇总进 DWS、给报表进 ADS。**

### 为什么分层（面试必问）
1. **数据血缘清晰**：出问题能逐层定位
2. **复用**：上层不用每次重算明细
3. **职责隔离**：改一处不会全乱

### ODS 时间戳的意义（dt / etl_time）
- `dt`（数据日期）= 这行数据属于哪一天（按天筛选）
- `etl_time`（入仓时间）= 什么时候被处理进数仓（追溯）
- 行业规范：**凡进 ODS 必须盖这两个戳**——留底、可追溯、支持按天增量

---

## 四、维度建模（Day 3）

- **事实表**：记录"发生的业务事件"，存能算的数字（金额/利率/标签），行数多字段少
- **维度表**：描述"谁/何时/何地"（客户/日期/地区），行数少字段多
- **粒度**：一行代表什么（本项目：一笔贷款）
- **星型模型**：事实表居中连维度表，主流
- **判断口诀**：能被"求和/计数"的是**事实**；用来"分组/筛选/描述"的是**维度**

**项目实例**：贷款金额、利率、违约标签 = 事实；客户、日期、地区 = 维度

---

## 五、SQL 语法手册（今天全部，含例句）

### 改结构 vs 改数据（三类动词别混）
| 想干什么 | 用什么 |
|---|---|
| 改表结构（加列/删列/改类型） | `ALTER TABLE` |
| 加新数据 | `INSERT INTO` |
| 改已有数据 | `UPDATE` |

### 建库
```sql
CREATE DATABASE IF NOT EXISTS ods;  -- IF NOT EXISTS = 存在也不报错
```

### 建表（两种方式）
```sql
CREATE TABLE ods.loan_ods LIKE src.loan_raw;  -- 只复制结构（52列，0行）
CREATE TABLE dwd.loan_dwd AS SELECT ...;       -- CTAS：建表+灌数据一步到位
```

### 加列
```sql
ALTER TABLE ods.loan_ods ADD COLUMN dt DATE, ADD COLUMN etl_time DATETIME;
```

### 灌数据（查询结果直接进表，列顺序要对上）
```sql
INSERT INTO ods.loan_ods SELECT *, CURRENT_DATE, NOW() FROM src.loan_raw;
-- CURRENT_DATE=今天日期，NOW()=此刻日期时间
```

### 筛选 WHERE（逐行过滤，条件为真才留）
```sql
WHERE id <> ''                    -- id 不等于空字符串（<> 是不等于）
AND loan_status IN ('Fully Paid', 'Charged Off', ...)  -- AND=都要满足，IN=名单任意一个
```

### 分组统计
```sql
SELECT loan_status, COUNT(*) AS cnt
FROM ods.loan_ods
GROUP BY loan_status              -- 按状态分组
ORDER BY cnt DESC;                -- 降序（DESC）
-- 分组后过滤用 HAVING，分组前过滤用 WHERE
```

### 条件打标签
```sql
CASE WHEN loan_status IN ('Charged Off', 'Default', ...) THEN 1 ELSE 0 END AS is_default
```

### 字符串替换（清洗利器）
```sql
REPLACE(loan_status, '  ', ' ')   -- 把双空格替换成单空格
```

### 删表（危险操作，确认不要了才用）
```sql
DROP TABLE IF EXISTS dwd.loan_dwd;
```

### 探查真实值（抓隐形脏）
```sql
SELECT loan_status, LENGTH(loan_status) FROM ...  -- 长度对比，空格骗不了人
```

---

## 六、清洗 5 件套 + 实战（Day 3）

| 件 | 做法 | 本项目 |
|---|---|---|
| 1 去重/去垃圾 | `WHERE id <> ''` | 删 4 行空行 |
| 2 定口径 | 只保留已终结贷款 | 42542 → 38979 |
| 3 统一格式 | REPLACE 去双空格 | 'Does not meet...' 修复 |
| 4 类型转换 | 去%转数值、文本日期转日期 | 下半场待做 |
| 5 打标签 | CASE WHEN → is_default | 6203 违约 / 32776 正常 |

### 实战案例：双空格事故（今天的最大金矿）
- **现象**：DWD 行数 36285 vs 预期 38979，差 2694 = 恰好等于两个长状态的数量
- **根因**：CSV 源数据里 `Does not meet the credit policy.  Status:xxx` 是**双空格**，SQL 的 IN 是逐字符精确匹配，差一个空格就不匹配
- **发现方法**：`LENGTH(字段)` 长度对比（51 vs 50）
- **修复**：`REPLACE(loan_status, '  ', ' ')` 标准化，SELECT/CASE/WHERE **三处一致**
- **衍生坑**：中间版本 WHERE 用了 REPLACE 但 CASE 没用 → 761 行标签打错

---

## 七、方法论（比语法值钱，面试和工作中天天用）

1. **对账思维（勾稽）**：动手前先算预期数字，跑完对实际。对不上 → 差异精确等于某组数量 → 锁定嫌疑 → 查真实存储值。**不靠肉眼，靠数字。**
2. **三处一致原则**：同一字段在一条 SQL 里多处使用，处理必须完全一致
3. **先懂数据再动手**：做清洗前先侦查（分布/重复/空值），心里有数据地图
4. **工具选型**：导大数据不用图形向导（逐行 INSERT 慢），用批量导入/ETL/LOAD DATA INFILE
5. **验证过的 SQL 进文件**：sql/ 目录按天归档带注释，git 提交，可复现

---

## 八、工程规范（Workbench + 仓库）

- **Workbench 编辑区** = 草稿本 + 执行器，写过的 SQL 不用删，往下接着写
- 执行：闪电图标 / Ctrl+Enter（当前语句）、选中多条一起执行
- 作用域：连接能操作所有库，但 `sys` 系统库别碰
- **SQL 归档节奏**：验证通过 → 存 `sql/dayX_xxx.sql`（带注释）→ git commit + push
- **提交节奏**：每完成一个里程碑提交一次

---

## 九、面试可能问的点（今天已覆盖）

1. **为什么数仓要分层？** → 血缘/复用/职责隔离
2. **ODS 为什么要加时间戳？** → 留底/可追溯/支持按天增量
3. **事实表和维度表怎么区分？** → 能求和计数=事实，能分组筛选=维度
4. **数据质量怎么保证？** → 对账勾稽、每步记录行数、分布抽查、长度探查
5. **遇到过什么脏数据？** → 双空格案例（发现→定位→修复全流程），这是面试亮点
6. **git 怎么用？** → 8 步流程 + token 认证 + 小步高频提交

---

## 十、待办（Day 3 下半场）

- [ ] `issue_d` 文本日期（Dec-2011）→ 真正日期（提示：STR_TO_DATE）
- [ ] `int_rate`（10.65%）→ 数值（提示：REPLACE + 除法）
- [ ] `emp_title` 缺失处理（删行/填默认/保留，权衡）
- [ ] 写 `doc/清洗记录.md`
- [ ] 验证 id 唯一性（无重复主键）
