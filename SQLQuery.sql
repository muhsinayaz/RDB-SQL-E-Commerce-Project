--Analyze the data by finding the answers to the questions below--

--1.Using the columns of �market_fact�, �cust_dimen�, �orders_dimen�, �prod_dimen�, �shipping_dimen�, 
-->Create a new table, named as �combined_table�.

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

 

--M��terilerin ziyaret g�nl�klerini, ilk ve son sipari� tarihlerini tutan bir �g�r�n�m"(view) olu�turudum.  


create view visit_logs
as
select distinct  Cust_ID, Order_Date
				,first_value(Order_Date) over (partition by Cust_ID order by Order_Date) as first_order
				,first_value(Order_Date) over (partition by Cust_ID order by Order_Date desc) as last_order
from combined_table;


select * from visit_logs;


-- Her m��teri ziyareti i�in,  bir sonraki ziyaretini ayr� bir s�tun olarak olu�turdum. 
-- Tek sipari�i olanlar ve ilk sipari�ler Null d�nd�.


select * 
		,lag(Order_Date) over (partition by Cust_ID order by Order_Date) as consecutive_order
from visit_logs
order by 1,2,3;


-- Ard���k ziyaretlerdeki ay fark�n� "month_gap_betwn" s�tununa,
-- m��teriye g�re ziyaretler aras� fark�n toplam ortalamas�n� da "month_avg_ord" s�tununa ekledim.

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


-- son sipari�inden itibaren 2013 e kadar ka� ay ge�ti�ini "last_gap_betwn_13" s�tununa
-- son sipari� ile 2013 e kadar ge�en s�reyi ortalamaya dahil etmek i�in 
-- month_avg_ord s�tununda null olan de�erleri  last_gap_betwn_13 ile doldurup ortalamaya ekledim ve ortalama ald�m.

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


--View � sadele�tirdim 

create view visit_avg
as
select distinct Cust_ID, first_order, last_order, month_avg_ord, 
		last_gap_betwn_13, month_avg_ord_13
from visit_time ;

select distinct * from visit_avg order by 1,2;



/*
�irket faliyetine 2009-01-01 tarihinder ba�lam��t�r.
Rapor 2009-01-01 ve 2012-12-31 tarihleri aras�n� kapsamaktad�r.
M��teri sipari�lerine bakt���m�zda �ok yo�un bir trafi�e sahip olmayan bir web sitesi.
M��teri segmentasyonu i�in;

Rapor 2012 aral�k ay�nda al�nd���n� d���n�rsek;

Raporlamada;
- Ortalamaya g�re ��kar�m yapaca��mdan,
- M��terinin davran���nda �imdiki zaman�n ve son ziyaretin etkisini korumas� ad�na
2012-12-31 tarihi i�in sipari� vermi� olarak girdi sa�lad�m

1- �lk sipari�i 2012 haziran ay�ndan sonra ise; "Yeni M��teri" (first_order > 2012-06-30)
2- 2013 e kadar olan s�rede sipri� aral��� ortalama 12-24 ay ise; "Kazan�lmas� Gereken M��teri"  (month_avg_ord_13 between 12 and 24) cust_1047,1420
3- Tek sipari�i veya daha fazla sipari�i olup 2013 e kadar ge�en s�re 24 aydan �ok ise; "Kay�p M��teri" (month_avg_ord_13 > 24)  cust-1073
4- Ortalama 6-12 ayda bir sipari� veriyorsa; "Normal M��teri"
5- Ortalama 6 ay ve daha a�a�� ise; "Sad�k M��teri"


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
