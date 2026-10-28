select loan_status, count(*) as cnt
from ods.loan_ods
group by loan_status
order by cnt desc;

select id, count(*) as cnt
from ods.loan_ods
group by id
having count(*) > 1;

drop table if exists dwd.loan_dwd;
create table dwd.loan_dwd as
select
	id,
    loan_amnt,
    case when trim(int_rate) = '' then NULL
		else cast(replace(trim(int_rate), '%', '') as decimal(6,4)) / 100
	end as int_rate,
    term,
    installment,
    annual_inc,
    case when emp_title is NULL or trim(emp_title) = '' then 'Unknown'
		else trim(emp_title)
	end as emp_title,
    emp_length,
    home_ownership,
    addr_state,
    STR_TO_DATE(CONCAT(issue_d, '-01'), '%b-%Y-%d') as issue_d,
    replace(loan_status, '  ', ' ') as loan_status,
    case when replace(loan_status, '  ', ' ') in ('Charged Off', 'Default', 'Does not meet the credit policy. Status:Charged Off')
		then 1 else 0 end as is_default
from ods.loan_ods
where id <> ''
	and replace(loan_status, '  ', ' ') in ('Fully Paid', 'Charged Off', 'Default',
                      'Does not meet the credit policy. Status:Fully Paid',
                      'Does not meet the credit policy. Status:Charged Off');
                      
select count(*) from dwd.loan_dwd;
select is_default, count(*) from dwd.loan_dwd group by is_default;
select issue_d, int_rate, emp_title from dwd.loan_dwd limit 5;
select count(*) from dwd.loan_dwd where issue_d is NULL;
select min(int_rate), max(int_rate), avg(int_rate) from dwd.loan_dwd;

select count(*) as total, count(distinct id) as distinct_id from dwd.loan_dwd;

