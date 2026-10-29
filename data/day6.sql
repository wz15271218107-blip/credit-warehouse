select	count(*) as customer_cnt,
		sum(loan_cnt) as total_loans,
        sum(default_cnt) as total_defaults
from(
	select	customer_key,
			count(*) as loan_cnt,
			sum(loan_amnt) as total_amount,
			sum(is_default) as default_cnt,
			round(avg(is_default), 4) as default_rate
	from dwd.fact_loan
	group by customer_key
) t;

create table dws.dws_customer (
	customer_key int primary key,
    loan_cnt int,
    total_amount decimal(12,2),
    default_cnt int,
    default_rate decimal(8,4)
);

insert into dws.dws_customer (customer_key, loan_cnt, total_amount, default_cnt, default_rate)
select	customer_key,
		count(*) as loan_cnt,
        sum(loan_amnt) as total_amount,
        sum(is_default) as default_cnt,
        round(avg(is_default),4) as default_rate
from dwd.fact_loan
group by customer_key;

select count(*) from dws.dws_customer;
select * from dws.dws_customer limit 10;


drop table dws._dws_date;
create table dws.dws_date (
	year int, 
    month int,
    loan_cnt int,
    total_amount decimal(12,2),
    default_cnt int,
    default_rate decimal(8,4),
    primary key (year, month)
);

insert into dws.dws_date (year, month, loan_cnt, total_amount, default_cnt, default_rate)
select dd.year, dd.month, count(*), sum(f.loan_amnt), sum(f.is_default), round(avg(f.is_default), 4)
from dwd.fact_loan f
join dwd.dim_date dd on f.date_key = dd.date_key
group by dd.year, dd.month;

select count(*) from dws.dws_date;
select * from dws.dws_date limit 10;


create table dws.dws_region (
	region_key int primary key,
    loan_cnt int,
    total_amount decimal(12,2),
    default_cnt int,
    default_rate decimal(8,4)
);

insert into dws.dws_region (region_key, loan_cnt, total_amount, default_cnt, default_rate)
select dr.region_key, count(*), sum(f.loan_amnt), sum(f.is_default), round(avg(f.is_default), 4)
from dwd.fact_loan f
join dwd.dim_region dr on f.region_key = dr.region_key
group by dr.region_key;

select count(*) from dws.dws_region;
select * from dws.dws_region limit 10;
