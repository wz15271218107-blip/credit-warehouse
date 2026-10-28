# Day 4 知识点总结：星型结构 + JOIN 专题

> 日期：2026-10-28 · 项目：信贷违约数仓（credit-warehouse）
> 配套文件：`sql/day4_dim_fact.sql`（全部 SQL 归档）、`学习进度.md`
> 前置：Day 3 完成 DWD 清洗（38979 行干净明细）

---

## 一、今天做了什么（全景）

```
Day 4 ✅  把干净明细拆成星型结构：
         dim_date(55) + dim_region(50) + dim_customer(38979) + fact_loan(38979)
         + 四表 JOIN 验证（一条完整贷款档案）
JOIN 专题 ✅ 机制 + 直觉方法论（"缺啥拼啥"条件反射）
```

**一句话**：明细表是"一锅端"，星型结构是"分门别类的仓库"——数字进事实表，描述进维度表，需要时用 JOIN 拼回来。

---

## 二、星型结构（四张表的设计）

### 结构图
```
                 ┌─ dim_customer（客户字典：member_id/职位/收入/住房/工龄）
                 │
fact_loan  ──────┤  ← 事实表（流水）：一笔贷款一行
(38979)          │    loan_id + 3个外键 + 金额/利率/期数/违约标签
                 │
                 ├─ dim_date（日期字典：日期/年/月/季度）
                 │
                 └─ dim_region（地区字典：州代码）
```

### 每张表设计要点

| 表 | 行数 | 关键字段 | 设计要点 |
|---|---|---|---|
| dim_date | 55 | date_key(自增主键), full_date(唯一), year/month/quarter | 业务键 full_date 唯一；年月季用函数提取 |
| dim_region | 50 | region_key(自增主键), state_code(唯一) | DISTINCT 去重抽字典 |
| dim_customer | 38979 | customer_key(自增主键), member_id(唯一), emp_title/annual_inc/home_ownership/emp_length | member_id 从 ODS JOIN 取回；收入转数值 |
| fact_loan | 38979 | loan_id(主键), customer_key/date_key/region_key(外键), loan_amnt/int_rate/installment/term/is_default | 只存外键编号 + 数字指标 |

### 核心概念
- **代理键**（date_key/customer_key）：数据库自己的自增编号，事实表用它引用
- **业务键**（full_date/member_id/state_code）：真实世界的标识，保证唯一
- **外键**：事实表里指向维度表的编号 = "学号"，靠它 JOIN 回维度表取描述
- **判断口诀（复习）**：能求和计数的是**事实**，能分组筛选描述的是**维度**

---

## 三、建表语法手册（今天的新语法）

### 自定义建表（不是 CTAS，是一列一列自己写）

```sql
CREATE TABLE dwd.dim_date (
    date_key INT AUTO_INCREMENT PRIMARY KEY,   -- 整型 + 自增 + 主键
    full_date DATE NOT NULL UNIQUE,            -- 日期 + 非空 + 唯一
    year INT,
    month INT,
    quarter INT
);
```

### 约束三件套（字典表的核心）
| 约束 | 含义 | 例子 |
|---|---|---|
| `PRIMARY KEY` | 主键，唯一标识一行 | date_key |
| `NOT NULL` | 不许为空 | full_date |
| `UNIQUE` | 不许重复 | full_date/member_id/state_code |

### 常用函数（今天新增）
| 函数 | 作用 | 例子 |
|---|---|---|
| `YEAR(日期)` | 取年份 | YEAR('2011-12-01') → 2011 |
| `MONTH(日期)` | 取月份 | MONTH('2011-12-01') → 12 |
| `QUARTER(日期)` | 取季度(1-4) | QUARTER('2011-12-01') → 4 |
| `CAST(x AS DECIMAL(12,2))` | 文本转数值 | CAST('10000' AS DECIMAL(12,2)) → 10000.00 |
| `TRIM(x)` | 去首尾空格 | TRIM(' 36 months') → '36 months' |
| `DISTINCT` | 去重 | SELECT DISTINCT addr_state → 50 个州 |

**回顾**：Day 3 已有 REPLACE / CASE WHEN / STR_TO_DATE / CONCAT / LIKE / LENGTH

---

## 四、JOIN 机制拆解（用迷你演示理解"拼接"）

### 两张演示表
```
demo_orders（左表，4行）          demo_customers（右表，3行）
O1 | A | 100                     A | 张三 | 上海
O2 | B | 200                     B | 李四 | 北京
O3 | A | 300                     D | 王五 | 广州
O4 | C | 150
```

### 执行过程（逐行配对）
```
左表O1 → 右表找 customer_id='A' → 拼上「张三·上海」
左表O2 → 找 'B' → 拼上「李四·北京」
左表O3 → 找 'A' → 再拼「张三·上海」（客户A拼了两次 = 一对多膨胀！）
左表O4 → 找 'C' → 右表没有 → INNER丢弃 / LEFT补NULL
```

### 实际结果
| 查询 | 结果行数 | 规律 |
|---|---|---|
| INNER JOIN | 3 | O4 匹配不到被丢；客户D无订单也不出现 |
| LEFT JOIN | 4 | 左表全保留，O4 右边补 NULL |

### 铁律：JOIN 会改变行数
- **键不唯一 → 行数膨胀**（客户A有2笔订单 → 拼出2行）
- **匹配不上 → INNER 丢行 / LEFT 补 NULL**
- 做 JOIN 前先想：**键是不是唯一的？** 这是 JOIN 最大的坑

---

## 五、JOIN 直觉方法论（老手条件反射 = 这套框架）

### 三层判断（3 秒出答案）
```
第1层 要不要拼？   当前表有没有我要的列？有→不拼；没有→拼
第2层 找谁拼？     缺"描述/分组"→ 找维度表；缺"流水数字"→ 找事实表
第3层 用什么拼？   事实表的外键(*_key) = 维度表的主键
```

### 三条金句
1. **JOIN = 查字典**。事实表只有"学号"，要"学生名字"就去查档案表。缺啥查啥。
2. **数字算，维度查**。需求里出现"按 XX 分组/筛选"——XX 不在当前表，就去有 XX 的表拼。
3. **从事实出发，缺啥拼啥**。90% 的 JOIN 都是：事实表 JOIN 维度表 ON 外键=主键。

### 需求 → 条件反射速查表
| 需求 | 第一反应 |
|---|---|
| 算总额/平均/笔数 | 不 JOIN，当前表直接算 |
| 按职位/收入/地区/月份分组 | JOIN 对应维度表 |
| 看客户资料 | JOIN dim_customer |
| 查贷款是哪年哪季 | JOIN dim_date |
| 查找不到档案的孤儿 | LEFT JOIN + WHERE 维度表主键 IS NULL |

### 项目实例（练三条）
1. "按州看违约率" → JOIN dim_region → 按 state_code 分组
2. "按月看放款总额" → JOIN dim_date → 按 year, month 分组
3. "算整体平均利率" → 当前表就有 int_rate → **不 JOIN**

### 使用规则清单
1. 写 JOIN 必带 ON（配对条件），FROM 后是左表
2. 多表查询列名全带 `表别名.` 前缀
3. JOIN 前先想键唯一性（不唯一会膨胀）
4. 左边全留用 LEFT JOIN，两边都要用 INNER
5. ON 放配对条件，WHERE 放过滤条件

---

## 六、今日踩坑记录（金矿）

### 坑 1：Error 1046 No database selected（表名漏点号）
- **现象**：`insert into dwd_dim_customer`（漏了 `dwd.` 的点）
- **原理**：`dwd_dim_customer` 被当成"当前库里的表"，而 Workbench 没选中任何库
- **铁律**：永远写 `库名.表名` 完全限定名，不依赖当前选中库

### 坑 2：Error 1366 Incorrect DECIMAL value（annual_inc 空串）
- **现象**：`CAST('' AS DECIMAL)` 在 SELECT 里没问题，INSERT 时报 1366
- **原理**：**严格模式（STRICT_TRANS_TABLES）只管"写"（INSERT/UPDATE），不管"算"（SELECT）**——空串转数值被严格模式拒绝
- **解决**：`CASE WHEN TRIM(x) = '' THEN NULL ELSE CAST(x AS DECIMAL) END`（空串→NULL，不硬转0）
- **复盘**：int_rate 和 annual_inc 用了同一个模式——**缺失数值 → NULL**，0 会污染平均值

### 坑 3：term 前导空格（' 36 months'）
- 今天的第 4 处空格脏（双空格/利率空格/职位空格/期限空格）
- **条件反射**：字符字段进表先 TRIM

### 坑 4：数据时间范围是 2007-06 ~ 2011-12
- dim_date 抽查发现 2007 年（Lending Club 早期数据），之前文档写的 2011-2013 是错的
- **教训**：探查时别只看按数量排序的前几个，要查 MIN/MAX

### 坑 5：Workbench 多语句执行
- 全选执行会把所有语句都跑一遍，结果标签会混
- **规范**：执行哪条就选中哪条

---

## 七、Day 4 验收结果（全通过）

| 验证项 | 结果 |
|---|---|
| dim_date | 55 ✅ |
| dim_region | 50 ✅ |
| dim_customer | 38979 ✅ |
| fact_loan | 38979 ✅ |
| 四表 JOIN | 一条完整记录（贷款ID+客户资料+日期+州+金额+利率+标签）✅ |

---

## 八、待办（Day 5：第 1 周收官）

- [ ] 写 `doc/架构图.md`（分层图 + 星型结构图）
- [ ] 写 `README.md`（项目背景/数据来源/怎么跑/目录结构）
- [ ] 全部 SQL 整理进 `sql/week1.sql` + git 提交
- [ ] git 提交：sql/day4_dim_fact.sql + 本总结 + 学习进度
