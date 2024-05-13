SELECT *
FROM dbo.e_commerce;

--1. Find the top 3 customers who have the maximum count of orders.
SELECT TOP 3 Cust_ID, Customer_Name, COUNT(Ord_ID) AS Count_Orders
FROM dbo.e_commerce
GROUP BY Cust_ID, Customer_Name
ORDER BY  Count_Orders DESC;



--2. Find the customer whose order took the maximum time to get shipping.
SELECT TOP 1 Cust_ID, Customer_Name, DaysTakenForShipping
FROM dbo.e_commerce
--WHERE DaysTakenForShipping = (SELECT MAX(DaysTakenForShipping) FROM dbo.e_commerce) (OPSIYONEL OLARAK)
ORDER BY DaysTakenForShipping DESC;


--3. Count the total number of unique customers in January and how many of them came back again in the each one months of 2011.
SELECT COUNT( DISTINCT A.Cust_ID)
FROM dbo.e_commerce AS A
WHERE YEAR(A.Order_Date) = 2011 
AND MONTH(A.Order_Date) = 1;

SELECT DISTINCT A.Cust_ID, A.Customer_Name
FROM dbo.e_commerce AS A
WHERE YEAR(A.Order_Date) = 2011 
AND MONTH(A.Order_Date) = 1
AND A.Cust_ID IN (  SELECT B.Cust_ID
					FROM dbo.e_commerce AS B
					WHERE YEAR(B.Order_Date) = 2011 
					AND MONTH(B.Order_Date) > 1);

SELECT DISTINCT A.Cust_ID, A.Customer_Name
FROM dbo.e_commerce AS A
WHERE YEAR(A.Order_Date) = 2011 
    AND MONTH(A.Order_Date) = 1
    AND EXISTS ( SELECT 1
                 FROM dbo.e_commerce AS B
                 WHERE 
                 YEAR(B.Order_Date) = 2011 
                 AND MONTH(B.Order_Date) > 1
                 AND A.Cust_ID = B.Cust_ID );  --EXIST DE BU SON BAGLAMA GEREKLI!!

--4. Write a query to return for each user the time elapsed between the first purchasing and
--the third purchasing, in ascending order by Customer ID.
WITH CustomerPurchases AS (
							SELECT Cust_ID, Order_Date,
							LEAD(Order_Date, 2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS ThirdPurchaseDate
							FROM dbo.e_commerce
							)
              
SELECT    Cust_ID, DATEDIFF(day, Order_Date, ThirdPurchaseDate) AS ElapsedDays
FROM      CustomerPurchases
WHERE     ThirdPurchaseDate IS NOT NULL
ORDER BY  Cust_ID;

--5. Write a query that returns customers who purchased both product 11 and product 14,
--as well as the ratio of these products to the total number of products purchased by the customer.

SELECT *
FROM dbo.e_commerce;

SELECT Cust_ID,
    SUM(CASE WHEN Prod_ID = 'Prod_11' THEN 1 ELSE 0 END) + SUM(CASE WHEN Prod_ID = 'Prod_14' THEN 1 ELSE 0 END) AS Total_Prod11_14,
	COUNT(*) AS Total_count,
	ROUND(CAST(SUM(CASE WHEN Prod_ID = 'Prod_11' THEN 1 ELSE 0 END) + SUM(CASE WHEN Prod_ID = 'Prod_14' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*), 2)AS Ratio
FROM dbo.e_commerce
WHERE Cust_ID IN (
				  SELECT Cust_ID FROM dbo.e_commerce
				  WHERE Prod_ID IN ('Prod_11', 'Prod_14')
				  GROUP BY Cust_ID
				  HAVING COUNT(DISTINCT Prod_ID) = 2 )

GROUP BY Cust_ID;

/* Categorize customers based on their frequency of visits. The following steps 
will guide you. If you want, you can track your own way.
 */
--1. Create a “view” that keeps visit logs of customers on a monthly basis. (For 
--each log, three field is kept: Cust_id, Year, Month)

CREATE VIEW MonthlyVisit AS
SELECT Cust_ID,
    YEAR(Order_Date) AS Year,
    MONTH(Order_Date) AS Month
FROM       dbo.e_commerce
GROUP BY   Cust_ID, YEAR(Order_Date), MONTH(Order_Date);

--2. Create a “view” that keeps the number of monthly visits by users. (Show 
--separately all months from the beginning business)
SELECT [Month], COUNT(Cust_ID) AS Count
FROM MonthlyVisit
GROUP BY [Month];

--3. For each visit of customers, create the previous or next month of the visit as a 
--separate column.
CREATE VIEW VisitWithNextMonth AS
SELECT 
    Cust_ID,
    Order_Date AS VisitDate,
    LEAD(MONTH(Order_Date)) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS NextMonth
FROM 
    dbo.e_commerce;

--4. Calculate the monthly time gap between two consecutive visits by each customer.
CREATE VIEW MonthlyTimeGap AS
SELECT 
    Cust_ID,
    Order_Date AS VisitDate,
    LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) AS PreviousVisitDate,
    DATEDIFF(MONTH, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS MonthlyTimeGap
FROM 
    dbo.e_commerce;

--5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.
CREATE VIEW CustomerCategories AS
SELECT Cust_ID,
    CASE 
        WHEN AVG(TimeGap) <= 100 THEN 'Regular'
		WHEN AVG(TimeGap) > 100 AND AVG(TimeGap) <= 365 THEN 'Occasional'
		WHEN AVG(TimeGap) > 365 THEN 'Churned'
        ELSE 'One time visit'
    END AS Category
FROM   (SELECT Cust_ID,
		DATEDIFF(day, LAG(Order_Date) OVER (PARTITION BY Cust_ID ORDER BY Order_Date), Order_Date) AS TimeGap
		FROM  dbo.e_commerce)
		AS TimeGaps
GROUP BY 
    Cust_ID;

/*Month-Wise Retention Rate
Find month-by-month customer retention rate since the start of the business.
There are many different variations in the calculation of Retention Rate. But we will 
try to calculate the month-wise retention rate in this project.
So, we will be interested in how many of the customers in the previous month could 
be retained in the next month.
Proceed step by step by creating “views”. You can use the view you got at the end of 
the Customer Segmentation section as a source. */

-- 1. Find the number of customers retained month-wise. (You can use time gaps)
SELECT *
FROM dbo.e_commerce
ORDER BY Cust_ID;


WITH T1 AS (
    SELECT 
        Cust_ID, Order_Date,
        MONTH(Order_Date) AS PreviousMonth,
        LEAD(MONTH(Order_Date)) OVER (PARTITION BY Cust_ID  ORDER BY Order_Date) AS NextMonth
    FROM  dbo.e_commerce),

T2 AS (SELECT *,
	CASE WHEN (NextMonth - PreviousMonth) = 1 OR NextMonth - PreviousMonth = -11 THEN 1
			 ELSE 0
	END AS RetainedInNextMonth
	FROM 
		T1)
/*SELECT *
FROM T2
WHERE RetainedInNextMonth = '1'
ORDER BY Cust_ID, Order_Date;*/

SELECT COUNT(DISTINCT Cust_ID)
FROM T2
WHERE RetainedInNextMonth = 1;


-- 2. Calculate the month-wise retention rate.
WITH T1 AS (
    SELECT 
        Cust_ID, Order_Date,
        MONTH(Order_Date) AS PreviousMonth,
        LEAD(MONTH(Order_Date)) OVER (PARTITION BY Cust_ID  ORDER BY Order_Date) AS NextMonth
    FROM  dbo.e_commerce),

T2 AS (SELECT *,
	CASE WHEN (NextMonth - PreviousMonth) = 1 OR NextMonth - PreviousMonth = -11 THEN 1
			 ELSE 0
	END AS RetainedInNextMonth
	FROM 
		T1),
T3 AS (SELECT 
        PreviousMonth,
        COUNT(DISTINCT Cust_ID) AS TotalCustomers,
        SUM(RetainedInNextMonth) AS RetainedCustomers
    FROM  T2
    GROUP BY PreviousMonth)

SELECT PreviousMonth,
       RetainedCustomers * 1.0 / TotalCustomers AS RetentionRate
FROM   T3;

























			     
				













