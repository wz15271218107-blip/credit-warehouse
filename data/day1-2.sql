create database if not exists ods;
create database if not exists dwd;
create database if not exists dws;
create database if not exists ads;


create table ods.loan_ods like src.loan_raw;
alter table ods.loan_ods add column dt date, add column etl_time datetime;
insert into ods.loan_ods select *, current_date, now() from src.loan_raw;

select count(*) from ods.loan_ods;
select * from ods.loan_ods limit 3;