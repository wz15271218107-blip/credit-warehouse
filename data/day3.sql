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
    int_rate,
    term,
    installment,
    annual_inc,
    emp_title,
    emp_length,
    home_ownership,
    addr_state,
    issue_d,
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
select * from dwd.loan_dwd limit 5;
