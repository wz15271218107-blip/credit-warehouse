# 信贷违约数仓 · 完整项目

基于 Lending Club 真实信贷数据构建的一套**端到端数据仓库实战项目**：从原始 CSV 落库 → ODS 贴源 → DWD 清洗打标签 → DWS 主题汇总 → ADS 报表成品 → FineBI 可视化大屏 → 影刀 RPA 自动调度，覆盖数仓工程师日常工作全链路。

## 数据来源

- Lending Club 贷款数据（LoanStats3a.csv，H2O 官方镜像）
- 42,542 行 × 52 列，2007-06 ~ 2011-12 真实信贷数据
- 字段：贷款金额、利率、期限、借款人收入/职位/住房、放款日期、地区、贷款状态等

## 技术栈

| 层 | 工具 | 用途 |
|---|---|---|
| 数据库 | MySQL 8.0 | 数仓分层存储（ODS/DWD/DWS/ADS） |
| 数据导入 | Python 3 + pymysql | 批量导入 CSV，替代图形向导 |
| 可视化 | FineBI 6.0 | 连 MySQL 直连模式，搭监控大屏 |
| 自动化调度 | 影刀 RPA | 定时巡检 + 异常弹窗 |
| 版本管理 | Git / GitHub | 全程小步提交 |

## 数仓架构（四层分层）

```
src.loan_raw (42542行原始CSV)
    ↓ 原样落库 + 加时间戳
ods.loan_ods (42542行贴源)
    ↓ 清洗：口径过滤/去空格/日期格式化/利率转数值/违约打标签
dwd.loan_dwd (38979行明细)
    ↓ 星型拆分：事实表 fact_loan + 维度表 dim_date/dim_region/dim_customer
dws.dws_customer / dws_date / dws_region (按主题预汇总)
    ↓ 落地业务规则：样本门槛/主口径/排序
ads.ads_overview (1行总览)
ads.ads_region_default (43行地区排行)
ads.ads_month_trend (55行月度趋势)
    ↓ FineBI 直连展示
监控大屏 (4指标卡 + 地区Top10 + 月度趋势)
```

## 核心成果

### 数据层

| 层 | 表 | 规模 | 说明 |
|---|---|---|---|
| src | loan_raw | 42,542 × 52 | 原始 CSV 原样落库 |
| ods | loan_ods | 42,542 × 54 | +dt（数据日期）+ etl_time（入仓时间） |
| dwd | loan_dwd | 38,979 × 13 | 清洗后明细，违约 6,203 / 正常 32,776 |
| 维度 | dim_date / dim_region / dim_customer | 55 / 50 / 38,979 | 日期 / 州 / 客户字典 |
| 事实 | fact_loan | 38,979 | 一笔贷款一行，3 外键 + 金额/利率/违约标签 |
| dws | dws_customer / dws_date / dws_region | 38,979 / 55 / 50 | 按客户/月/州预汇总 |
| ads | ads_overview | 1 行 | 总览：38,979 笔 / $4.17亿 / 违约率 15.91% / 平均单笔 $10,699 |
| ads | ads_region_default | 43 行 | 地区违约率排行（门槛 loan_cnt>=50） |
| ads | ads_month_trend | 55 行 | 月度违约率趋势（2007-06~2011-12） |

### 清洗动作

口径过滤（剔除进行中贷款）、空行清理、双空格标准化、日期格式化（文本→DATE）、利率转数值（%→小数）、缺失处理（职位填 Unknown、收入转 NULL）、违约打标签（0/1）。

### 业务规则（判断层）

- **违约定义**：Charged Off / Default / Does not meet...Charged Off 共 6,203 笔
- **小样本门槛**：地区表 loan_cnt >= 50 才展示（7 个小州过滤，保留全量数据但展示层过滤）
- **利率主口径**：金额加权平均利率 12.61%（资金收益视角），算术平均 11.94% 备用

### BI 大屏（FineBI 6.0）

- 顶部 4 指标卡：总贷款 38,979 笔 / 违约率 15.91% / 总放款 $417,052,675 / 平均单笔 $10,699.42
- 左下：地区违约率 Top10 条形图（NV 0.2537 第一）
- 右下：月度违约率折线图（2007-06~2011-12）
- 数据模式：直连模式（实时查 MySQL，避免抽取模式文件锁问题）

### RPA 自动巡检（影刀）

- 每天 09:00 自动连 MySQL
- 跑校验 SQL：三张 ADS 表行数 + 总笔数勾稽
- 条件判断：总笔数 == 38,979？弹窗"巡检通过" / "数据异常！预期 38979"
- 替代人工手动巡检，异常自动报警

## 数据质量

8 项校验全通过（见 `doc/数据质量报告.md`）：
- 四层行数勾稽：42542 = 42542 = 38979 = 38979
- 外键 NULL = 0
- DWS 汇总 = 明细加总
- 差异留档：地区表差 112 笔 = 门槛过滤 7 个小样本州

## 怎么跑

1. **导入原始数据**（如库中无数据）：`python scripts/import_csv_to_mysql.py`
2. **建库建表 + ODS/DWD**：执行 `sql/week1.sql`（按四段顺序）
3. **DWS + ADS**：执行 `sql/week2.sql`
4. **质量校验**：执行 `sql/day9_quality_check.sql`
5. **FineBI**：数据连接「信贷违约」连 MySQL ads 库，三张 ADS 表加为数据集
6. **RPA 巡检**：影刀流程「数据工程师自动化练习」每天 09:00 定时执行

## 目录结构

```
credit-warehouse/
├── README.md                  -- 项目说明（本文件）
├── 学习进度.md                -- 学习日志与踩坑记录（Day0~Day13）
├── sql/
│   ├── week1.sql              -- 第1周总入口（ODS/DWD/维度事实）
│   ├── week2.sql              -- 第2周总入口（DWS/ADS/质量校验）
│   ├── day6_dws.sql           -- DWS 三表
│   ├── day8_ads.sql           -- ADS 三表
│   └── day9_quality_check.sql -- 8 项质量校验
├── doc/
│   ├── 架构图.md              -- 分层 + 星型结构
│   ├── 清洗记录.md             -- 每步清洗前后行数
│   ├── 指标字典.md             -- 5 指标口径定义
│   └── 数据质量报告.md         -- 8 项校验结果
├── data/
│   └── LoanStats3a.csv        -- 原始数据
└── scripts/
    ├── import_csv_to_mysql.py  -- 批量导入脚本
    └── download_data.py        -- 数据下载脚本
```

## 面试亮点

- **完整数仓闭环**：CSV → ODS → DWD → DWS → ADS → BI → RPA，不是只写 SQL
- **业务判断**：违约口径定义、小样本门槛、加权 vs 算术平均利率——不是纯搬运
- **数据质量意识**：8 项校验脚本、行数勾稽、外键 NULL 闸、差异留档
- **工具栈匹配央国企**：MySQL + FineBI（帆软市占率第一）+ 影刀 RPA（已有三级证书）
- **踩坑经验**：spider 文件锁改直连模式、year_month 保留字反引号、FineBI 公式引擎≠MySQL
