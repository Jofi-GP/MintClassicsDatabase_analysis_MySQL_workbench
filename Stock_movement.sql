-- c. Are we storing items that are not moving? Are any items candidates for being dropped from the product line?

-- To find out the stock health status and identify items that are either dead-stock (zero historical sales), severe overstocked
-- (items which stock units outnumber the total units sold), or severe understocked, I compared total sold items with total stored items 
-- establishing two thresholds: if total sold is 1 times less than total stored, immediate restock is needed. If total sold is 5 times more
-- than total stored, then overstock. Other cases are balanced.

USE mintclassics;
SELECT 
    w.warehouseName,
    p.productCode,
    p.productName,
    p.productLine,
    p.quantityInStock AS current_stock,
    COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold_lifetime,
    -- Calculates the dollar value of inventory sitting on shelves
    FORMAT(p.quantityInStock * p.buyPrice, 2) AS capital_tied_up_usd,
    -- Expanded status to catch overstock, normal levels, and understock
    CASE 
        WHEN SUM(od.quantityOrdered) IS NULL OR SUM(od.quantityOrdered) = 0 THEN 'Absolute Dead (0 Sales)'
        WHEN p.quantityInStock > (SUM(od.quantityOrdered) * 3) THEN 'Severely Overstock'
        WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 1) AND SUM(od.quantityOrdered) > 0 THEN 'Restock needed'
        ELSE 'Balanced'
    END AS stock_health_status
FROM products p
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
LEFT JOIN orderdetails od ON p.productCode = od.productCode
LEFT JOIN orders o ON od.orderNumber = o.orderNumber
WHERE o.`status` NOT IN ('Cancelled', 'On hold', 'In progress')
GROUP BY w.warehouseName, p.productCode, p.productName, p.productLine, p.quantityInStock, p.buyPrice
-- Removed the strict filter so you can see a complete health report of all items
ORDER BY total_units_sold_lifetime ASC;

-- There is a model that is not sold and it's overstocked, whereas high sold item lacks availability. 
-- Conclusion: there might be a repository issue that affects all warehouses. Probable causes are
-- delays from providers selling those items, or them being rare, or re-ordering delays. 
-- Actionable insight: check re-ordering stocks (other databases).

-- Gathered the info on stock health and presented it as percentages to compare between warehouses
-- Used a CTE ProductInventoryHealth 

WITH ProductInventoryHealth AS (
    -- Step 1: Calculate the raw metrics and status for every individual product
    SELECT 
        p.warehouseCode,
        w.warehouseName,
        p.productCode,
        p.quantityInStock AS current_stock,
        COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold_lifetime,
        CASE 
            WHEN SUM(od.quantityOrdered) IS NULL OR SUM(od.quantityOrdered) = 0 THEN 'Absolute Dead'
            WHEN p.quantityInStock > (SUM(od.quantityOrdered) * 3) THEN 'Severe Overstock'
            WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 0.7) THEN 'Severe Understock'
            ELSE 'Normal Balance'
        END AS stock_health_status
    FROM products p
    INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
    LEFT JOIN orderdetails od ON p.productCode = od.productCode
    GROUP BY p.warehouseCode, w.warehouseName, p.productCode, p.quantityInStock
)
-- Step 2: Roll up individual product data into percentage metrics per warehouse
SELECT 
    warehouseName,
    COUNT(*) AS total_distinct_products,
    
    -- Calculate percentage of Severe Understock items
    ROUND((SUM(CASE WHEN stock_health_status = 'Severe Understock' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS severe_understock_pct,
    
    -- Calculate percentage of Normal Balance items
    ROUND((SUM(CASE WHEN stock_health_status = 'Normal Balance' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS normal_balance_pct,
    
    -- Calculate percentage of Severe Overstock items
    ROUND((SUM(CASE WHEN stock_health_status = 'Severe Overstock' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS severe_overstock_pct,
    
    -- Calculate percentage of Absolute Dead items (0 sales)
    ROUND((SUM(CASE WHEN stock_health_status = 'Absolute Dead' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS dead_sales_pct
FROM ProductInventoryHealth
GROUP BY warehouseCode, warehouseName
ORDER BY warehouseName;


-- FIND WHICH WAREHOUSES HAVE LEAST RATE OF MOVEMENT OF INVENTORY AND REVENUE

-- This might be reflected by the ratio of sold items vs stock per warehouse. Since we might have an inventory of items that is not being ordered/sold,
-- it means they are occupying space without bringign revenues to the company. By analyzing these items and the warehouses they belong, independently
-- of the product lines, we might make space for reorganizing valuable stock and reducing stagnant volumes.

WITH WarehouseMetrics AS (
    SELECT 
        w.warehouseCode,
        w.warehouseName,
        -- 1. Inventory Movement Components
        SUM(od.quantityOrdered) AS Total_Units_Sold,
        SUM(p.quantityInStock) AS Total_Current_Stock,
        -- 2. Revenue Component
        SUM(od.quantityOrdered * od.priceEach) AS Total_Revenue
    FROM warehouses w
    INNER JOIN products p ON w.warehouseCode = p.warehouseCode
    -- LEFT JOIN handles warehouses with stock but potentially zero sales
    LEFT JOIN orderdetails od ON p.productCode = od.productCode
    LEFT JOIN orders o ON od.ordernumber = o.ordernumber
    WHERE o.`status` NOT IN ('On Hold', 'Cancelled', 'In Process')
    GROUP BY w.warehouseCode, w.warehouseName
),
CalculatedMetrics AS (
    SELECT 
        WarehouseCode,
        WarehouseName,
        Total_Units_Sold,
        Total_Current_Stock,
        Total_Revenue,
        -- Calculate the Movement %
        ROUND((Total_Units_Sold / NULLIF(Total_Current_Stock, 0)) * 100, 2) AS Movement_Percentage
    FROM WarehouseMetrics
)
SELECT 
    WarehouseCode,
    WarehouseName,
    FORMAT(Total_Units_Sold, 0) AS Units_Sold,
    FORMAT(Total_Current_Stock, 0) AS Current_Stock,
    Movement_Percentage,
    FORMAT(Total_Revenue, 2) AS Total_Revenue,
    -- Rank by Movement to answer "which has the highest"
    DENSE_RANK() OVER(ORDER BY Movement_Percentage DESC) AS Movement_Rank,
    -- Rank by Revenue to see if they correlate
    DENSE_RANK() OVER(ORDER BY Total_Revenue DESC) AS Revenue_Rank
FROM CalculatedMetrics
ORDER BY Movement_Percentage DESC;

-- As we previously found out, a high proportion of items are overstock. Next question is: can some of them be dropped
-- from the product line? 
-- The answer is yes: item S18_3233 has no records on sales. This product should not be included in the product line Classic Cars.

-- Other possible action is reduction of inventory. Since this issue is important in the case East and West warehouses are merged, 
-- I only calculated a 20% Inventory reduction applied to these two storages. Perhaps it can be applied to the other warehouses.

SELECT 
    w.warehouseName,
    p.productCode,
    p.productName,
    p.productLine,
    COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold_lifetime,
    p.quantityInStock AS current_stock,
    -- 1. Calculate exactly what 20% of the current stock looks like
      -- 1. If lifetime sales are 0, target a 100% reduction. Otherwise, target 20%.
    CASE 
        WHEN COALESCE(SUM(od.quantityOrdered), 0) = 0 THEN p.quantityInStock
        ELSE FLOOR(p.quantityInStock * 0.20)
    END AS target_reduction_units,
      -- 2. Subtract the dynamic target reduction from current stock to get the new remaining stock
    CASE 
        WHEN COALESCE(SUM(od.quantityOrdered), 0) = 0 THEN 0
        ELSE COALESCE(p.quantityInStock - FLOOR(p.quantityInStock * 0.20), 0)
    END AS remaining_stock,
    
    CASE 
        WHEN SUM(od.quantityOrdered) IS NULL OR SUM(od.quantityOrdered) = 0 THEN 'Absolute Dead (0 Sales)'
        WHEN p.quantityInStock > (SUM(od.quantityOrdered) * 3) THEN 'Severely Overstock'
        WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 1) AND SUM(od.quantityOrdered) > 0 THEN 'Restock needed'
        ELSE 'Balanced'
    END AS stock_health_status
FROM products p
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
LEFT JOIN orderdetails od ON p.productCode = od.productCode
LEFT JOIN orders o ON od.orderNumber = o.orderNumber
WHERE 
    -- 2. Filter strictly for East and West warehouses
    (w.warehouseName LIKE '%East%' OR w.warehouseName LIKE '%West%')
    AND (o.`status` NOT IN ('Cancelled', 'On hold', 'In progress') OR o.`status` IS NULL)
GROUP BY w.warehouseName, p.productCode, p.productName, p.productLine, p.quantityInStock, p.buyPrice

-- 3. Filter aggregated data to only show "Severely Overstock" (or dead stock)
HAVING stock_health_status IN ('Severely Overstock', 'Absolute Dead (0 Sales)')
ORDER BY total_units_sold_lifetime ASC, current_stock DESC;

-- The actual reduction in inventory for each warehouse was 21.8% for East and 18.6% for West.

-- SOME ITEMS ARE UNDERSTOCK. Calculate restock capacity on selected items to accurately simulate a balanced stock in the rearranged warehouses. 
-- For this, I reverse the above logic, taking into consideration that a balanced inventory is 2 times the total unit solds in a lifetime.

SELECT 
    w.warehouseName,
    p.productCode,
    p.productName,
    p.productLine,
    COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold_lifetime,
    p.quantityInStock AS current_stock,
    
    -- 1. Define target stock baseline (e.g., 2x lifetime sales)
    (SUM(od.quantityOrdered) * 2) AS healthy_target_stock,
    
    -- 2. Calculate required restock units to bridge the gap
    CASE 
        WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 2) 
        THEN (SUM(od.quantityOrdered) * 2) - p.quantityInStock
        ELSE 0
    END AS required_restock_units,
    
    -- 3. Calculate the estimated procurement cost to buy these restock units
    FORMAT(
        CASE 
            WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 2) 
            THEN ((SUM(od.quantityOrdered) * 2) - p.quantityInStock) * p.buyPrice
            ELSE 0
        END, 2
    ) AS estimated_procurement_cost_usd,
    
    CASE 
        WHEN SUM(od.quantityOrdered) IS NULL OR SUM(od.quantityOrdered) = 0 THEN 'Absolute Dead (0 Sales)'
        WHEN p.quantityInStock > (SUM(od.quantityOrdered) * 3) THEN 'Severely Overstock'
        WHEN p.quantityInStock < (SUM(od.quantityOrdered) * 1) AND SUM(od.quantityOrdered) > 0 THEN 'Restock needed'
        ELSE 'Balanced'
    END AS stock_health_status
FROM products p
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
LEFT JOIN orderdetails od ON p.productCode = od.productCode
LEFT JOIN orders o ON od.orderNumber = o.orderNumber
WHERE 
   (o.`status` NOT IN ('Cancelled', 'On hold', 'In progress') OR o.`status` IS NULL)
GROUP BY w.warehouseName, p.productCode, p.productName, p.productLine, p.quantityInStock, p.buyPrice

-- 4. Filter strictly for items flagged as "Restock needed"
HAVING stock_health_status = 'Restock needed'
-- 5. Sort by the highest required units first so you see your most critical shortages immediately
ORDER BY required_restock_units DESC;

