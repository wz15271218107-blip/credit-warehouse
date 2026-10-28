select loan_status, count(*) as cnt
from ods.loan_ods
group by loan_status
order by cnt desc;

select id, count(*) as cnt
from ods.loan_ods
group by id
having count(*) > 1;
