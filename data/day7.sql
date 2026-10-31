-- 整体违约率 = 所有月份违约笔数之和 ÷ 所有月份笔数之和
select sum(default_cnt) / sum(loan_cnt) as overall_default_rate
from dws.dws_date;
 
select ddw.region_key, ddi.state_code, (default_cnt) / sum(loan_cnt) as region_default_rate
from dws.dws_region ddw
join dwd.dim_region ddi on ddi.region_key = ddw.region_key
group by ddw.region_key
order by region_default_rate desc;

select year, month, sum(default_cnt) / sum(loan_cnt) as month_default_rate
from dws.dws_date
group by year, month
order by month_default_rate desc;

select avg(int_rate) as agv_rate
from dwd.fact_loan;

SELECT COUNT(*) AS loan_cnt,                -- 38,979
       SUM(loan_amnt) AS total_amount,      -- 417052675.00
       ROUND(AVG(loan_amnt), 2) AS avg_loan -- 10699.42
FROM dwd.fact_loan;