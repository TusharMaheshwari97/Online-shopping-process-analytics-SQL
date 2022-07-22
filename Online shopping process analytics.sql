create database marketplace;

use marketplace;
show tables;
set sql_safe_updates=0;


select* from market_fact;
select * from orders_dimen;
select * from cust_dimen;
select * from prod_dimen;
select * from shipping_dimen;


-- 1.1.	Join all the tables and create a new table called combined_table.(market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)
create table combined_table as select mf.*,
cd.Customer_Name,cd.Province,cd.Region,cd.Customer_Segment,
od.Order_ID,od.Order_Date,od.Order_Priority, 
pd.Product_Category,pd.Product_Sub_Category,
sd.Ship_Mode,sd.Ship_Date
from market_fact as mf join orders_dimen as od on mf.ord_id=od.ord_id 
inner join cust_dimen as cd on mf.cust_id=cd.cust_id
inner join prod_dimen as pd on mf.prod_id=pd.prod_id
inner join shipping_dimen as sd on mf.ship_id=sd.ship_id;
select * from combined_table;


-- 2.	Find the top 3 customers who have the maximum number of orders
select distinct cust_id,customer_name,count(order_quantity) over(partition by cust_id) total_order 
from combined_table order by total_order desc limit 3 ;


-- 3. Create a new column DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

update combined_table 
set Order_Date=str_to_date(Order_Date,"%d-%m-%Y");
alter table combined_table modify Order_Date date;

update combined_table set Ship_Date=str_to_date(Ship_Date,"%d-%m-%Y");

alter table combined_table modify Ship_Date date;

alter table combined_table add DaysTakenForDelivery int;

update combined_table set DaysTakenForDelivery = datediff(Ship_Date,Order_Date);

select * from combined_table;




-- 4. Find the customer whose order took the maximum time to get delivered

select cust_id,customer_name,DaysTakenForDelivery 
from combined_table order by DaysTakenForDelivery desc limit 1;


-- 5.Retrieve total sales made by each product from the data (use Windows function)

select distinct prod_id,sum(sales) over(partition by prod_id) as total 
from combined_table order by prod_id;


-- 6. Retrieve total profit made from each product from the data (use windows function)

select distinct prod_id,sum(profit) over(partition by prod_id) as `total profit` 
from combined_table;


-- 7. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

select count(*) 'Total uniques customers' 
from (select distinct cust_id,customer_name from combined_table where month(order_date)=1 and year(order_date)=2011)t;

-- 8.	Retrieve month-by-month customer retention rate since the start of the business.(using views)

#Tips: 
#1: Create a view where each user’s visits are logged by month, allowing for the possibility that these will have 
#occurred over multiple # years since whenever business started operations
# 2: Identify the time lapse between each visit. So, for each person and for each month, we see when the next visit is.
# 3: Calculate the time gaps between visits
# 4: categorise the customer with time gap 1 as retained, >1 as irregular and NULL as churned
# 5: calculate the retention month wise


create or replace view retention_rate
as
select distinct month as m1,count(cust_id) over(partition by month) as retention_no,status from (
select *,
(case 
	when abs(month(next_v)-month(visit))=1 then "Regular" 
	when abs(month(next_v)-month(visit))>1 then "irregular" 
	else "one time" 
end) as status from
(select cust_id,customer_name,order_date as visit,lead(order_date) over (partition by cust_id order by order_date) as next_v ,
month(order_date) as month 
from combined_table 
order by cust_id)t)t2 where status="regular";


select * from retention_rate;
