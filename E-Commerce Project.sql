


--SQL Project Solution
--E-Commerce Data and Customer Retention Analysis with SQL



--////////////////////////////////////////////////////////////////////////////////////
-- Analysis of Data
--************************************************************


-- 1. Find the top 3 customers who have the maximum count of orders.


SELECT	TOP 3 Cust_ID, COUNT(Ord_ID)
FROM	 e_commerce_data
GROUP BY
		Cust_ID
ORDER BY 2 DESC



-- 2. Find the customer whose order took the maximum time to get shipping.


SELECT	Cust_ID, Ord_ID, DaysTakenForShipping
FROM	e_commerce_data
ORDER BY DaysTakenForShipping DESC



SELECT	Cust_ID, Ord_ID, DaysTakenForShipping
FROM	e_commerce_data
WHERE	DaysTakenForShipping = (
								SELECT	MAX(DaysTakenForShipping)
								FROM	e_commerce_data
								)


-- 3. Count the total number of unique customers in January and 
-- how many of them came back every month over the entire year in 2011.

WITH T1 AS (
			SELECT	Cust_ID
			FROM	e_commerce_data
			WHERE	YEAR(Order_Date) = 2011
			AND		MONTH (Order_Date) = 1
) 
SELECT	MONTH (ORDER_DATE) as ord_month, COUNT(DISTINCT A.Cust_ID) cnt_cust
FROM	e_commerce_data AS A
		INNER JOIN
		T1 AS B
		ON A.Cust_ID = B.Cust_ID
WHERE	YEAR(Order_Date) = 2011
GROUP BY 
		MONTH(Order_Date)





-- 4. Write a query to return for each user the time elapsed between the first purchasing 
-- and the third purchasing, in ascending order by Customer ID.


WITH T1 AS (
			SELECT	Cust_ID, Ord_ID, Order_Date,
					DENSE_RANK() OVER (PARTITION BY cust_ID ORDER BY Order_Date) num_of_orders
			FROM	e_commerce_data
			)
, T2 AS		(
			SELECT	Cust_ID, Ord_ID, Order_Date,
					DENSE_RANK() OVER (PARTITION BY cust_ID ORDER BY Order_Date) num_of_orders
			FROM	e_commerce_data
			)
SELECT	DISTINCT T1.cust_ID, T1.Order_Date, T2.Cust_ID, T2.Order_date, 
		DATEDIFF(day, T1.Order_Date, T2.Order_date) datediff_from_1_and_3
FROM	T1 INNER JOIN T2 ON T1.Cust_ID = T2.Cust_ID

WHERE	T1.num_of_orders = 1 AND T2.num_of_orders = 3



------------------


----------------------------------------------------------------------------
-- 5. Write a query that returns customers who purchased both product 11 and product 14, 
-- as well as the ratio of these products to the total quantity of products purchased by the customer.

WITH T1 AS (
SELECT	Cust_ID, 
		SUM(Order_Quantity) total_orders,
		SUM(CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END) P_11_quantity,
		SUM(CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity  ELSE 0 END) P_14_quantity
FROM e_commerce_data
GROUP BY
		Cust_ID
HAVING 
		SUM(CASE WHEN Prod_ID = 'Prod_11' THEN 1 END) IS NOT NULL
		AND
		SUM(CASE WHEN Prod_ID = 'Prod_14' THEN 1 END) IS NOT NULL
)
SELECT *, CAST(1.0*P_11_quantity/total_orders AS decimal(3,2))  AS P11_RATIO , 
			CAST(1.0*P_14_quantity/total_orders AS DECIMAL(3,2))AS P_14_RATIO
FROM T1




--////////////////////////////////////////////////////////////////////////////////////

-- Customer Segmentation
--************************************************************

-- Categorize customers based on their frequency of visits.

-- 1. Create a “view” that keeps visit logs of customers on a monthly basis. 
-- (For each log, three field is kept: Cust_id, Year, Month)


-- 2. Create a “view” that keeps the number of monthly visits by users. 
--(Show separately all months from the beginning business)


GO;

CREATE VIEW monthy_visit_logs AS
SELECT	Cust_ID, 
		YEAR(Order_Date) ord_year, 
		MONTH(Order_Date) ord_month,
		COUNT(*) cnt_log
FROM	e_commerce_data
GROUP BY 
		Cust_ID, YEAR(Order_Date), MONTH(Order_Date)
GO



-- 3. For each visit of customers, create the next month of the visit as a separate column.

-- 4. Calculate the monthly time gap between two consecutive visits by each customer.

go
CREATE VIEW time_gaps AS
WITH T1 AS (
			SELECT *,
					DENSE_RANK() OVER (ORDER BY ord_year, ord_month) current_month
		
			FROM	monthy_visit_logs
			)
SELECT *, 
		LEAD(current_month) OVER (PARTITION BY cust_ID ORDER BY current_month) next_month,
		LEAD(current_month) OVER (PARTITION BY cust_ID ORDER BY current_month) - current_month AS time_gap
FROM	T1
go


-- 5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.

WITH T1 AS (
			SELECT	Cust_ID, AVG(time_gap) AVG_MONTHLY_GAP
			FROM time_gaps
			GROUP BY Cust_ID
			)
SELECT	Cust_ID,
		CASE WHEN AVG_MONTHLY_GAP IS NULL THEN 'Churn'
				WHEN AVG_MONTHLY_GAP <= 3 THEN 'regular'
				WHEN AVG_MONTHLY_GAP > 3 THEN 'irregular'
		END AS customer_label_by_visit
FROM	T1


----------------


-- Month-Wise Retention Rate
--************************************************************

-- Find month-by-month customer retention rate since the start of the business.


--ayýn toplam müþteri sayýsý / önceki aydan gelen müþterilerin sayýsý


SELECT *
FROM 	time_gaps



WITH T1 AS (
SELECT	current_month, 
		COUNT(DISTINCT Cust_ID) total_customer,
		COUNT(CASE WHEN time_gap = 1 THEN 1 END) AS cust_from_prev
FROM	time_gaps
GROUP BY current_month
)
SELECT	current_month, total_customer, cust_from_prev, 
		LAG (cust_from_prev) OVER (ORDER BY current_month) prev_cust,
		CAST (1.0*LAG (cust_from_prev) OVER (ORDER BY current_month) / total_customer AS decimal(3,2))
FROM T1












