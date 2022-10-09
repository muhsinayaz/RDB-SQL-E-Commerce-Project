--Analyze the data by finding the answers to the questions below--

--1.Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, “prod_dimen”, “shipping_dimen”, 
-->Create a new table, named as “combined_table”.

select	a.*, b.Sales,b.Discount,b.Order_Quantity,b.Product_Base_Margin,
		c.*, d.*, e.Ship_ID, e.Ship_Mode, CONVERT(date, Ship_Date, 5) as Ship_Date
into combined_table
from cust_dimen a, market_fact b, orders_dimen c, prod_dimen d, shipping_dimen e
where	a.Cust_ID = b.Cust_ID
		and c.Ord_ID = b.Ord_ID
		and d.Prod_ID = b.Prod_ID
		and e.Ship_ID = b.Ship_ID
;

--2.Find the top 3 customers who have the maximum count of orders.


select distinct top 3  Cust_ID, Customer_Name
			, sum(Order_Quantity) over (partition by Cust_ID) as Sum_Quantity
from combined_table
order by 3 desc;

--3.Create a new column at combined_table as DaysTakenForShipping that contains the date difference of Order_Date and Ship_Date


alter table combined_table2
add DaysTakenForShipping2 as  datediff(day, Order_Date, Ship_Date )

select *
from combined_table;

select * from combined_table2

--4.Find the customer whose order took the maximum time to get shipping.

select top 1 Cust_ID, Customer_Name, DaysTakenForShipping
from combined_table
order by 3 desc;

--5.Count the total number of unique customers in January and 
-->how many of them came back every month over the entire year in 2011.

select * from combined_table;

with t1 as
(
select distinct Cust_ID
from combined_table
where Order_Date between '2011-01-01' and '2011-01-31'
)
select	datename(month, DateAdd( month ,month(a.Order_Date), 0 ) - 1 ) as month_2011
		, count(DISTINCT a.Cust_ID) as customer_count
from combined_table a, t1
where a.Cust_ID = t1.Cust_ID
and year(Order_Date) = 2011 
group by month(a.Order_Date);



-- 6.Write a query to return for each user the time elapsed between the first purchasing 
-- and the third purchasing, in ascending order by Customer ID.


with t1 as
(
select distinct Customer_Name, Cust_ID, Ord_ID, Order_Date
from combined_table
where Cust_ID in
	(select Cust_ID
	from combined_table
	group by Cust_ID
	having COUNT(distinct Ord_ID) > 2)
), t2 as

(select *, row_number() over(partition by Cust_ID order by Order_Date) as row_num
from t1), t3 as

(select	distinct Cust_ID, Customer_Name
		,FIRST_VALUE(Order_Date) over (partition by Cust_ID order by Order_Date) as first_order
		,FIRST_VALUE(Order_Date) over (partition by Cust_ID order by Order_Date desc) as third_order
from t2
where row_num = 1 or row_num=3)

select	Cust_ID, Customer_Name,
		DATEDIFF(DAY,first_order, third_order) day_betwn_order
from t3;


--7.Write a query that returns customers who purchased both product 11 and product 14,
--as well as the ratio of these products to the total number of products purchased by the customer.

with t1 as
(
select Cust_ID from combined_table
where Prod_ID = 'Prod_14'and Cust_ID in
				(select Cust_ID from combined_table
				where Prod_ID = 'Prod_11' )
), t2 as
(
select	distinct a.Customer_Name, a.Cust_ID, a.Order_Quantity, a.Prod_ID
		, sum(a.Order_Quantity) over (partition by a.Cust_ID) as Sum_Quantity
from combined_table a, t1
where a.Cust_ID = t1.Cust_ID
),t3 as
(
select	distinct Customer_Name, Cust_ID, Sum_Quantity
		, sum(Order_Quantity) over (partition by Cust_ID) as Prod_Sum_Quantity
from t2
where Prod_ID = 'Prod_11' or Prod_ID = 'Prod_14'
)
select *, cast (round( 100.0 * Prod_Sum_Quantity/Sum_Quantity, 2) as numeric (4,2)) as percent_sum
from t3
order by 5 desc;



--Customer Segmentation--

/*
Categorize customers based on their frequency of visits. 
The following steps will guide you. If you want, you can track your own way.*/

 

--Müþterilerin ziyaret günlüklerini, ilk ve son sipariþ tarihlerini tutan bir “görünüm"(view) oluþturudum.  


create view visit_logs
as
select distinct  Cust_ID, Order_Date
				,first_value(Order_Date) over (partition by Cust_ID order by Order_Date) as first_order
				,first_value(Order_Date) over (partition by Cust_ID order by Order_Date desc) as last_order
from combined_table;


select * from visit_logs;


-- Her müþteri ziyareti için,  bir sonraki ziyaretini ayrý bir sütun olarak oluþturdum. 
-- Tek sipariþi olanlar ve ilk sipariþler Null döndü.


select * 
		,lag(Order_Date) over (partition by Cust_ID order by Order_Date) as consecutive_order
from visit_logs
order by 1,2,3;


-- Ardýþýk ziyaretlerdeki ay farkýný "month_gap_betwn" sütununa,
-- müþteriye göre ziyaretler arasý farkýn toplam ortalamasýný da "month_avg_ord" sütununa ekledim.

create view visit_logs_2
as
with t1 as
(
select * 
		,lag(Order_Date) over (partition by Cust_ID order by Order_Date) as consecutive_order
from visit_logs
) 

select *, datediff(month, consecutive_order, Order_Date) month_gap_betwn
		, avg(datediff(month, consecutive_order, Order_Date)) over (partition by Cust_ID) month_avg_ord
		--, datediff(month, last_order, '2012-12-31') last_gap_betwn_13
from t1;



select * from visit_logs_2;


-- son sipariþinden itibaren 2013 e kadar kaç ay geçtiðini "last_gap_betwn_13" sütununa
-- son sipariþ ile 2013 e kadar geçen süreyi ortalamaya dahil etmek için 
-- month_avg_ord sütununda null olan deðerleri  last_gap_betwn_13 ile doldurup ortalamaya ekledim ve ortalama aldým.

create view visit_time
as

with t1 as
(
select *
		, datediff(month, last_order, '2012-12-31') last_gap_betwn_13
from visit_logs_2
)
select * 
		,coalesce(month_gap_betwn, last_gap_betwn_13)
		,avg(coalesce(month_gap_betwn, last_gap_betwn_13)) over (partition by Cust_ID) month_avg_ord_13
from t1


select * from visit_time order by 1,2;


--View ý sadeleþtirdim 

create view visit_avg
as
select distinct Cust_ID, first_order, last_order, month_avg_ord, 
		last_gap_betwn_13, month_avg_ord_13
from visit_time ;

select distinct * from visit_avg order by 1,2;



/*
Þirket faliyetine 2009-01-01 tarihinder baþlamýþtýr.
Rapor 2009-01-01 ve 2012-12-31 tarihleri arasýný kapsamaktadýr.
Müþteri sipariþlerine baktýðýmýzda çok yoðun bir trafiðe sahip olmayan bir web sitesi.
Müþteri segmentasyonu için;

Rapor 2012 aralýk ayýnda alýndýðýný düþünürsek;

Raporlamada;
- Ortalamaya göre çýkarým yapacaðýmdan,
- Müþterinin davranýþýnda þimdiki zamanýn ve son ziyaretin etkisini korumasý adýna
2012-12-31 tarihi için sipariþ vermiþ olarak girdi saðladým

1- Ýlk sipariþi 2012 haziran ayýndan sonra ise; "Yeni Müþteri" (first_order > 2012-06-30)
2- 2013 e kadar olan sürede sipriþ aralýðý ortalama 12-24 ay ise; "Kazanýlmasý Gereken Müþteri"  (month_avg_ord_13 between 12 and 24) cust_1047,1420
3- Tek sipariþi veya daha fazla sipariþi olup 2013 e kadar geçen süre 24 aydan çok ise; "Kayýp Müþteri" (month_avg_ord_13 > 24)  cust-1073
4- Ortalama 6-12 ayda bir sipariþ veriyorsa; "Normal Müþteri"
5- Ortalama 6 ay ve daha aþaðý ise; "Sadýk Müþteri"


*/
create view customer_segmentation
as
select *
		,case
		when first_order > '2012-06-30' then 'New Customer'
		when month_avg_ord_13 > 24 then 'Lost Customer'
		when month_avg_ord_13 between 12 and 24 then 'Customer to Win' 
		when month_avg_ord_13 between 6 and 12 then 'Regular Customer' 
		when month_avg_ord_13 < 6 then 'Loyal Customer'
		end as customer_categorise

from visit_avg;


--Month-Wise Retention Rate
--Find month-by-month customer retention ratei since the start of the business.

-- Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month

select	cast (
				(100.0 * (select count(distinct Cust_ID) from 
				customer_segmentation
				where customer_categorise != 'Lost Customer')
				/
				(select count(distinct Cust_ID) from cust_dimen)) 
as numeric (4,2)
				) as Retention_Rate ;
