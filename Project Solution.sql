

--E-Commerce Project Solution


--1. Join all the tables and create a new table called combined_table. 
--(market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)




SELECT *
INTO
combined_table
FROM
(
SELECT 
mf.Ord_ID, cd.Cust_ID, mf.Prod_ID, sd.Ship_ID, od.Order_Date, sd.Ship_Date, cd.Customer_Name, cd.Province, cd.Region, cd.Customer_Segment, 
mf.Sales, mf.Discount, mf.Order_Quantity, mf.Product_Base_Margin, od.Order_Priority,
pd.Product_Category, pd.Product_Sub_Category, sd.Ship_Mode
FROM market_fact mf
INNER JOIN cust_dimen cd ON mf.Cust_ID = cd.Cust_ID
INNER JOIN orders_dimen od ON od.Ord_ID = mf.Ord_ID
INNER JOIN prod_dimen pd ON pd.Prod_ID = mf.Prod_ID
INNER JOIN shipping_dimen sd ON sd.Ship_ID = mf.Ship_ID
) A;



SELECT *
FROM combined_table
ORDER BY 1


--///////////////////////


--2. Find the top 3 customers who have the maximum count of orders.


SELECT	TOP 3 Cust_ID,  COUNT(DISTINCT Ord_ID) cnt_order
FROM	combined_table
GROUP BY	
		Cust_ID
ORDER BY 
		2 DESC


--/////////////////////////////////



--3.Create a new column at combined_table as DaysTakenForShipping that contains the date difference of Order_Date and Ship_Date.
--Use "ALTER TABLE", "UPDATE" etc.


ALTER TABLE combined_table ADD DaysTakenForShipping INT 


SELECT *, DATEDIFF(DAY, Order_Date, Ship_Date)
FROM combined_table


UPDATE combined_table
SET DaysTakenForShipping = DATEDIFF(DAY, Order_Date, Ship_Date)



SELECT *
FROM	combined_table



--ALTER TABLE dbo.combined_table
--ADD DaysTakenForShipping AS  DATEDIFF (DAY, order_date, ship_date)



--////////////////////////////////////


--4. Find the customer whose order took the maximum time to get shipping.
--Use "MAX" or "TOP"

SELECT TOP 1 Customer_Name
FROM combined_table
ORDER BY 
		DaysTakenForShipping DESC



select	Customer_Name,DaysTakenForShipping
from	combined_table
where	DaysTakenForShipping = (select max(DaysTakenForShipping) from combined_table)


--////////////////////////////////



--5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
--You can use such date functions and subqueries








SELECT	DISTINCT Cust_ID
FROM	combined_table
WHERE	YEAR(Order_Date) = 2011
AND		MONTH(Order_Date) = 1



1	94
2	10
3	5



SELECT	MONTH(Order_Date) ORD_MONTH , COUNT (DISTINCT Cust_ID) CNT_CUST
FROM	combined_table A
WHERE	EXISTS	(
						SELECT	1
						FROM	combined_table B
						WHERE	YEAR(Order_Date) = 2011
						AND		MONTH(Order_Date) = 1
						AND		A.Cust_ID = B.Cust_ID
					)
AND		YEAR(Order_Date) = 2011
GROUP BY 
		MONTH(Order_Date)
ORDER BY
		1

--////////////////////////////////////////////


--6. write a query to return for each user the time elapsed between the first purchasing and the third purchasing, 
--in ascending order by Customer ID



WITH T1 AS
(
SELECT	 Cust_ID, Ord_ID, Order_Date,
		MIN (Order_Date) OVER (PARTITION BY Cust_ID) first_order,
		DENSE_RANK() OVER (PARTITION BY Cust_ID ORDER BY Order_Date, Ord_ID) ORDER_NUM
FROM	combined_table
) 
SELECT Cust_ID, Ord_ID, Order_Date, first_order, Order_num,
		DATEDIFF(DAY, first_order, order_date)
FROM	T1
WHERE	ORDER_NUM = 3

--------//////////////


--7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratios of these products to the total quantity of products purchased by the customer.



Ali 100	20 10



WITH T1 AS
(
SELECT	Cust_ID,
		SUM (CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END) prod_11,
		SUM (CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity ELSE 0 END) prod_14,
		SUM (Order_Quantity) total_product
FROM	combined_table
GROUP  BY 
		Cust_ID
HAVING
		SUM (CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END) > 0
		AND
		SUM (CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity ELSE 0 END) > 0
)
SELECT  cust_ID, 
		CAST(1.0*prod_11/total_product AS NUMERIC (3,2))as prod_11_ratio,
		CAST (1.0*prod_14/total_product AS NUMERIC (3,2)) as prod_14_ratio
		
FROM	T1


-----------


--/////////////////



--CUSTOMER SEGMENTATION


Ali 
1	5	1
2	6	2
3	8	2
4	10



CREATE VIEW cust_logs AS
SELECT	Cust_ID, YEAR(Order_Date) ord_year, MONTH(Order_Date) ord_month, 
		COUNT (*) logs
FROM	combined_table
GROUP BY 
		Cust_ID, YEAR(Order_Date), MONTH(Order_Date)




CREATE VIEW time_gaps as
WITH T1 AS 
(
select *, 
		DENSE_RANK() OVER (order by ord_year, ord_month) data_month
from cust_logs
)
SELECT *, LAG (data_month) OVER (PARTITION BY cust_ID ORDER BY data_month) prev_month,
		data_month - LAG (data_month) OVER (PARTITION BY cust_ID ORDER BY data_month) time_gap
FROM T1




SELECT	Cust_ID, 
		CASE WHEN AVG (time_gap) IS NULL THEN 'CHURN'
				WHEN AVG (time_gap) BETWEEN 1 AND 2 THEN 'REGULAR'
					WHEN AVG (time_gap) > 2  THEN 'IRREGULAR'
		END CUST_SEGMENT
FROM	time_gaps
GROUP BY 
		Cust_ID



--MONTH-WISE RETENTION RATE


--Find month-by-month customer retention rate  since the start of the business.



WITH T1 AS
(
SELECT *, COUNT (Cust_ID) over (PARTITION BY data_month) CNT_RETAINED_CUST
FROM	time_gaps
WHERE	time_gap = 1
) , T2 AS
(
SELECT *, COUNT (Cust_ID) over (PARTITION BY data_month) TOTAL_CUST
FROM	time_gaps
) 
SELECT	DISTINCT T1.Ord_year, T1.ord_month, T1.data_month, CNT_RETAINED_CUST, TOTAL_CUST,
		CAST(1.0*CNT_RETAINED_CUST / TOTAL_CUST AS NUMERIC (3,2)) AS RETENTION_RATE
FROM	T1, T2
WHERE	T1.data_month = T2.data_month




