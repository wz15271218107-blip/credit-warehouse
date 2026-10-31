create table ads.ads_overview(
	total_loans int,
    total_amount decimal(14,2),
    default_cnt int,
    overall_default_rate decimal(8,4),
    weighted_avg_rate decimal(8,4),
    avg_loan decimal(12,2)
);

drop table ads.ads_overview;
DELETE FROM ads.ads_overview;
insert into ads.ads_overview (total_loans, total_amount, default_cnt, overall_default_rate, weighted_avg_rate, avg_loan)
select	sum(dc.loan_cnt),
		sum(dc.total_amount),
        sum(dc.default_cnt),
		round(sum(dc.default_cnt)/sum(dc.loan_cnt),4),
        round(sum(df.loan_amnt*df.int_rate)/SUM(df.loan_amnt),4),
        round(sum(dc.total_amount)/sum(dc.loan_cnt),2)
from dws.dws_customer dc
join dwd.fact_loan df on dc.customer_key = df.customer_key;

select * from ads.ads_overview;


create table ads.ads_region_default(
	state_code varchar(20) primary key,
    loan_cnt int,
    default_cnt int,
    default_rate decimal(8,4)
);

truncate table ads.ads_region_default;
insert into ads.ads_region_default
select	di.state_code,
		dd.loan_cnt,
        dd.default_cnt,
        dd.default_rate
from dws.dws_region dd
join dwd.dim_region di on dd.region_key = di.region_key
where dd.loan_cnt >= 50
order by default_rate desc;
select * from ads.ads_region_default limit 5;

SELECT state_code, loan_cnt, default_rate
FROM ads.ads_region_default
WHERE loan_cnt < 50;


create table ads.ads_month_trend (
	year int,
    month int,
    loan_cnt int,
    default_cnt int,
    default_rate decimal(8,4),
    primary key (year, month)
);
insert into ads.ads_month_trend
select year,
	month,
    loan_cnt,
    default_cnt,
    default_rate
from dws.dws_date;
select * from ads.ads_month_trend limit 5;