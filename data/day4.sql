-- ① 日期维度
create table dwd.dim_date (
	date_key int auto_increment primary key,
    full_date date not NULL unique,
	year int,
    month int,
    quarter int
);

insert into dwd.dim_date (full_date, year, month, quarter)
select distinct issue_d, year(issue_d), month(issue_d), quarter(issue_d)
from dwd.loan_dwd
order by issue_d;


-- ② 地区维度
drop table if exists dwd.dim_region;
create table dwd.dim_region(
	region_key int auto_increment primary key,
    state_code varchar(10) not NULL unique
);
insert into dwd.dim_region (state_code)
select distinct addr_state
from dwd.loan_dwd
order by addr_state;

-- ③ 客户维度
drop table if exists dwd.dim_customer;
create table dwd.dim_customer (
	customer_key int auto_increment primary key,
    member_id varchar(20) not NULL unique,
    emp_title varchar(100),
    annual_inc decimal(12,2),
    home_ownership varchar(20),
    emp_length varchar(20)
);

insert into dwd.dim_customer (member_id, emp_title, annual_inc, home_ownership, emp_length)
select distinct o.member_id, d.emp_title, CASE WHEN TRIM(d.annual_inc) = '' THEN NULL
            ELSE CAST(d.annual_inc AS DECIMAL(12,2)) END, d.home_ownership, d.emp_length
from dwd.loan_dwd d
join ods.loan_ods o on d.id = o.id;

SELECT COUNT(*) FROM dwd.dim_date;     -- 应 55
SELECT COUNT(*) FROM dwd.dim_region;   -- 应 50
SELECT COUNT(*) FROM dwd.dim_customer; -- 应 38979
SELECT * FROM dwd.dim_date LIMIT 5;    -- 抽查




-- ============ 区块2：事实表 ============

create table dwd.fact_loan(
	loan_id varchar(20) primary key,	-- 贷款ID（业务主键）
    customer_key int,					-- 外键 → dim_customer
    date_key int,						-- 外键 → dim_date
    region_key int,						-- 外键 → dim_region
    loan_amnt decimal(12,2),			-- 金额（文本转数值）
    int_rate decimal(6,4),				-- 利率（Day 3 已转好）
    installment decimal(10,2),			-- 月供（文本转数值）
    term varchar(20),					-- 期限（TRIM 去前导空格）
    is_default int						-- 违约标签 0/1
);

insert into dwd.fact_loan
select
	d.id,
    dc.customer_key,
    dd.date_key,
    dr.region_key,
    cast(d.loan_amnt as decimal(12,2)),
    d.int_rate,
    cast(d.installment as decimal(10,2)),
    trim(d.term),
    d.is_default
from dwd.loan_dwd d
join ods.loan_ods o on d.id = o.id
join dwd.dim_customer dc on dc.member_id = o.member_id
join dwd.dim_date dd on dd.full_date = d.issue_d
join dwd.dim_region dr on dr.state_code = d.addr_state;

SELECT COUNT(*) FROM dwd.fact_loan; 

select
	f.loan_id,
    c.member_id, c.emp_title, c.home_ownership,
    d.full_date, d.year, d.month, d.quarter,
    r.state_code,
    f.loan_amnt, f.int_rate, f.is_default
from dwd.fact_loan f
join dwd.dim_customer c on f.customer_key = c.customer_key
join dwd.dim_date d on f.date_key = d.date_key
join dwd.dim_region r on f.region_key = r.region_key
limit 5;