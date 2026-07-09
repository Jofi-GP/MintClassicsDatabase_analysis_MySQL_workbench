-- Provide statistics on regional business operations and financials 
-- like number of customers and offices/sales reps that support them, total revenue, and countries inside those regions

 -- WARNING: this section can only be run after UPDATING offices Where country=Japan, territory=APAC, because in the original data territory. 
 
 -- Count offices per region, their revenue and market share pct
 -- Although it is a low revenue area, I might consider keeping the customer
USE mintclassics;
SELECT
		ofc.territory,
        COUNT(DISTINCT ofc.officeCode) AS offices_in_region,
        FORMAT(SUM(od.quantityOrdered * od.priceEach),2) AS Region_Sales_subtotal,
        FORMAT(SUM(SUM(od.quantityOrdered * od.priceEach)) OVER(),2) AS Grand_Total_Sales,
        ROUND((SUM(od.quantityOrdered * od.priceEach) / SUM(SUM(od.quantityOrdered * od.priceEach)) OVER()) * 100, 0) AS Market_Share_Percent
FROM offices ofc
LEFT JOIN employees e ON e.officeCode = ofc.officeCode
LEFT JOIN customers c ON e.employeeNumber = c.salesRepEmployeeNumber
INNER JOIN orders o ON c.customerNumber = o.customerNumber
INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
GROUP BY ofc.territory;

-- Provide statistics on most sold product lines per region
-- used two CTEs to safely execute operations without collapsing rows. First: CTE ProductSalesBase to calculate 
-- region sales per each product line; Second: CTE called RegionalProductSales to call the first one and with a window function
-- calculate the product line sales per region or territory (total region sales). 
-- Then I applied SELECT to pick the info from these two blueprint tables, calculating percentages and ranking the product lines in the territory

WITH ProductSalesBase AS (
    -- Step 1: calculate sales by Region and Product Line
    SELECT 
        ofc.territory, 
        p.productLine AS Product_Line, 
        SUM(od.quantityOrdered * od.priceEach) AS Product_Sales
    FROM offices ofc 
    INNER JOIN employees e ON ofc.officeCode = e.officeCode 
    INNER JOIN customers c ON c.salesRepEmployeeNumber = e.employeeNumber 
    INNER JOIN orders o ON c.customerNumber = o.customerNumber 
    INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber 
    INNER JOIN products p ON od.productCode = p.productCode 
    GROUP BY 
        ofc.territory,
        p.productLine
),
RegionalProductSales AS (
    SELECT 
        territory,
        Product_Line,
        Product_Sales,
        SUM(Product_Sales) OVER(PARTITION BY territory) AS Total_Region_Sales
    FROM ProductSalesBase
)
SELECT 
    territory, 
    Product_Line, 
    FORMAT(Product_Sales, 2) AS Product_Sales, 
    ROUND((Product_Sales / Total_Region_Sales) * 100, 2) AS Sales_Percentage, 
    DENSE_RANK() OVER(PARTITION BY territory ORDER BY Product_Sales DESC) AS Region_Rank 
FROM RegionalProductSales 
ORDER BY 
    territory, 
    Region_Rank;
    
-- Analyze Regional price gaps
-- this might help redirectioning the flux of items for a particular region 

-- First, calculated the Avg price of each item instead of just adding up priceEach, 
-- because individual sales might have been closed with different negotiated prices. Using conditional aggregation allows 
-- to differentiate averages per region instead of historical per item. I calculated STD and SEM for all AVGs.
-- I used GREATEST() and LEAST() to find the largest and smallest prices in regions to calculate 
-- the max_price_difference between regions. I learned that it allows me to scan columns, instead of rows like MAX and MIN.
-- I combined results using a CTE RegionalAverages. 

WITH RegionalMetrics AS (
    SELECT 
        od.productcode, 
        p.productName, 
        p.productLine,
        
        -- North America (NA) Metrics
        AVG(CASE WHEN ofc.territory = 'NA' THEN od.priceEach END) AS avg_na,
        STDDEV_SAMP(CASE WHEN ofc.territory = 'NA' THEN od.priceEach END) AS std_na,
        COUNT(CASE WHEN ofc.territory = 'NA' THEN od.priceEach END) AS count_na,
        
        -- EMEA Metrics
        AVG(CASE WHEN ofc.territory = 'EMEA' THEN od.priceEach END) AS avg_emea,
        STDDEV_SAMP(CASE WHEN ofc.territory = 'EMEA' THEN od.priceEach END) AS std_emea,
        COUNT(CASE WHEN ofc.territory = 'EMEA' THEN od.priceEach END) AS count_emea,
        
        -- APAC Metrics
        AVG(CASE WHEN ofc.territory = 'APAC' THEN od.priceEach END) AS avg_apac,
        STDDEV_SAMP(CASE WHEN ofc.territory = 'APAC' THEN od.priceEach END) AS std_apac,
        COUNT(CASE WHEN ofc.territory = 'APAC' THEN od.priceEach END) AS count_apac

    FROM orderdetails od 
    JOIN products p ON od.productcode = p.productcode 
    JOIN orders o ON od.ordernumber = o.ordernumber 
    JOIN customers c ON o.customernumber = c.customernumber 
    JOIN employees e ON c.salesrepemployeenumber = e.employeenumber 
    JOIN offices ofc ON e.officecode = ofc.officecode 
    GROUP BY od.productcode, p.productname, p.productLine
)
SELECT 
    productcode, 
    productName, 
    productLine,
    
    -- Rounded Averages
    ROUND(avg_na, 2) AS avg_price_na, 
    ROUND(avg_emea, 2) AS avg_price_emea, 
    ROUND(avg_apac, 2) AS avg_price_apac,
    
    -- Standard Deviations (Measures internal regional price spread)
    ROUND(std_na, 2) AS std_dev_na,
    ROUND(std_emea, 2) AS std_dev_emea,
    ROUND(std_apac, 2) AS std_dev_apac,
    
    -- Standard Errors (Measures error/accuracy of your average calculation: STD / SQRT(N))
    ROUND(std_na / NULLIF(SQRT(count_na), 0), 2) AS std_error_na,
    ROUND(std_emea / NULLIF(SQRT(count_emea), 0), 2) AS std_error_emea,
    ROUND(std_apac / NULLIF(SQRT(count_apac), 0), 2) AS std_error_apac,
    
    -- Maximum Regional Spread
    ROUND(
        GREATEST(COALESCE(avg_na, 0), COALESCE(avg_emea, 0), COALESCE(avg_apac, 0)) - 
        LEAST(COALESCE(avg_na, 999999), COALESCE(avg_emea, 999999), COALESCE(avg_apac, 999999)), 
        2
    ) AS max_price_difference_between_regions

FROM RegionalMetrics 
ORDER BY max_price_difference_between_regions DESC, productcode;

-- I observed there are countries with zero orders. Calculate the proportion of inactive customers (zero orders placed)

SELECT 
    -- Count only customers where the joined order number is missing
    SUM(CASE WHEN o.orderNumber IS NULL THEN 1 ELSE 0 END) AS Total_No_Order_Customers,
    
    -- Divide inactive customers by unique total customers
    ROUND(
        (SUM(CASE WHEN o.orderNumber IS NULL THEN 1 ELSE 0 END) / COUNT(DISTINCT c.customerNumber)) * 100, 
        2
    ) AS Percentage_Of_Total_Customers
FROM customers c
LEFT JOIN orders o ON c.customerNumber = o.customerNumber;

-- Clean the data so only active countries are shown in the map using an inner join from orders to customers instead of a left one

SELECT 
    CASE 
        WHEN c.country IN ('USA', 'Canada', 'Mexico') THEN 'NA'
        WHEN c.country IN ('Australia', 'New Zealand', 'Japan', 'Singapore', 'Hong Kong', 'China', 'India', 'South Korea', 'Philippines', 'Malaysia', 'Taiwan') THEN 'APAC'
        WHEN c.country IN ('UK', 'France', 'Germany', 'Spain', 'Italy', 'Netherlands', 'Belgium', 'Switzerland', 'Austria', 'Sweden', 'Norway', 'Denmark', 'Finland', 'Ireland', 'Portugal', 'Poland', 'Russia', 'South Africa', 'UAE', 'Israel', 'Egypt') THEN 'EMEA'
        ELSE 'Other/Unknown'
    END AS Region,
    c.country,
    COUNT(DISTINCT c.customerNumber) AS Total_Active_Customers,
    COUNT(DISTINCT o.orderNumber) AS Total_Orders
FROM customers c
INNER JOIN orders o ON c.customerNumber = o.customerNumber 
GROUP BY c.country, Region
ORDER BY Region DESC, Total_Orders DESC;


-- I observed there are quite a lot of comments in the orders table. After the comments containing keywords for feedback, we can get an idea on customer 
-- relationships. I learned to use REGEXP after failing usig just LIKE '%keyword%' due to overlapping of some words or other issues
-- like commas or periods. Also, I excluded first positive comments because the wording was confusing ('Cautious optimism", "must be more cautions with client")

WITH CustomerOrderFlags AS (
    -- Step 1: Evaluate every individual order comment for keywords
    SELECT 
        c.customerNumber,
        c.customerName,
        c.country,
        COALESCE(CONCAT(e.firstName, ' ', e.lastName), 'No Rep Assigned') AS Sales_Rep,
        o.orderNumber,
        o.comments,
        CASE 
			-- 1. Explicitly ignore positive/neutral phrases first
			WHEN o.comments REGEXP 'cautious optimism|budget approved|credit cleared' THEN 0
    			-- 2. Catch the actual problem keywords safely
			WHEN o.comments REGEXP 'sales|budget|credit|cautions|damag|missing|mistake|cancel|don' THEN 1
        ELSE 0
        END AS Flagged
    FROM customers c
    -- LEFT JOIN ensures we keep customers who have never placed an order
    LEFT JOIN orders o ON c.customerNumber = o.customerNumber
    LEFT JOIN employees e ON c.salesRepEmployeeNumber = e.employeeNumber
)
-- Step 2: Roll up to the customer level to make a final classification
SELECT 
    country AS Country,
    customerName AS Customer_Name,
    Sales_Rep AS Sales_Representative,
    COUNT(DISTINCT orderNumber) AS Total_Orders_Placed,
    -- If the sum of issue flags is greater than 0, they are marked as difficult
    CASE 
        WHEN COUNT(DISTINCT orderNumber) = 0 THEN 'Inactive (Zero Orders)'
        WHEN SUM(Flagged) > 0 THEN 'Difficult Client'
        ELSE 'Good / Normal Client'
    END AS Client_Status,
    -- Provides context by showing how many of their orders had friction
    CONCAT(SUM(Flagged), ' of ', COUNT(DISTINCT orderNumber)) AS Friction_Ratio,
    -- Pulls all historical comments into one view for easy auditing
    GROUP_CONCAT(DISTINCT comments SEPARATOR ' | ') AS Historical_Comments
FROM CustomerOrderFlags
GROUP BY country, customerNumber, customerName, Sales_Rep
ORDER BY Client_Status DESC, country ASC, Total_Orders_Placed DESC;




