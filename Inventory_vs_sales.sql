-- b. How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?

-- PART 1: IDENTIFY SALES PER PRODUCT LINE AND THEIR LOCATION. 
-- The compay has 6 product lines, each of which is located in one specific warehouse. 
-- Also, they have different amounts of unique items. Some are directly proportional to the revenue generated and some not.
-- I think this is one of the most critical pieces of information, since some product lines have inherent high prices. 
-- This is important to consider if the strategy is to get rid of a couple of product lines in order to make space.

USE mintclassics;
SELECT  w.warehouseName,
	    p.productLine,
        MIN(w_stock.total_warehouse_stock) AS units_stock,
        SUM(od.quantityOrdered) AS units_sold,
        COUNT(DISTINCT p.productCode) AS unique_products,
        ROUND(100.0 * SUM(od.quantityOrdered) / SUM(SUM(od.quantityOrdered)) OVER(), 2) AS pct_of_total_sales,
		ROUND(100.0 * SUM(od.quantityOrdered) / NULLIF(MIN(w_stock.total_warehouse_stock) + SUM(od.quantityOrdered), 0), 1) AS sold_to_stock_ratio,
        FORMAT(MIN((
    SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) 
    FROM products 
    WHERE warehouseCode = w.warehouseCode 
      AND productLine = p.productLine
)),2) AS tied_capital_per_product_line,
        FORMAT(SUM(od.quantityOrdered * od.priceEach), 2) AS total_revenue_generated,
FORMAT(
        COALESCE(
            SUM(od.quantityOrdered * od.priceEach) / NULLIF(SUM(od.quantityOrdered), 0), 
            0
        ), 2
    ) AS average_revenue_per_unit,
    COALESCE(
        ROUND(STDDEV_SAMP(od.priceEach), 2), 
        0
    ) AS revenue_per_unit_stddev
FROM orderdetails od
INNER JOIN products p ON od.productCode = p.productCode
INNER JOIN orders o ON od.orderNumber = o.orderNumber
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
-- Subquery to calculate accurate total stock per warehouse/productline without duplication
INNER JOIN (
    SELECT warehouseCode, 
           productLine, 
           SUM(quantityInStock) AS total_warehouse_stock
    FROM products
    GROUP BY warehouseCode, productLine
) w_stock ON p.warehouseCode = w_stock.warehouseCode AND p.productLine = w_stock.productLine
-- Filter out unshipped orders
WHERE o.`status` IN ('Shipped') 
GROUP BY w.warehouseCode, w.warehouseName, p.productLine
ORDER BY pct_of_total_sales DESC;

-- Find the average revenue per unit for each model, their total revenue, location, stock, and amount sold.
-- In this table I want to find if the least sold items by unit volume are the ones with least revenue.
-- I generated a ranking by ORDER BY total_revenue, calulated by historic priceEach by quantityOrdered. Kind
-- of an average. Then divided it by total_units_sold to create avg_revenue_per_unit.

SELECT 
    p.productCode,
    p.productName,
    w.warehouseName,
    COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold, -- to include zero sales that have zero revenue
    -- Static inventory column (no SUM needed because I group by productCode)
    p.quantityInStock AS in_stock_units,
    COUNT(DISTINCT od.orderNumber) AS total_sales_transactions,
    -- FORMAT applied ONLY to the display, while sorting runs on the raw calculation
    FORMAT(COALESCE(SUM(od.quantityOrdered * od.priceEach), 0), 2) AS total_revenue,
    -- Calculates average revenue per unit and safely avoids division-by-zero
    FORMAT(
        COALESCE(
            SUM(od.quantityOrdered * od.priceEach) / NULLIF(SUM(od.quantityOrdered), 0), 
            0
        ), 2
    ) AS average_revenue_per_unit
FROM products p
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
-- LEFT JOIN ensures products with zero sales or zero revenue are included
LEFT JOIN orderdetails od ON p.productCode = od.productCode
LEFT JOIN orders o ON od.orderNumber = o.orderNumber AND o.`status` NOT IN ('Cancelled')
GROUP BY p.productCode, p.productName, p.quantityInStock, w.warehouseName
-- Sort strictly by the raw mathematical calculation, NOT the formatted text string
ORDER BY COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) ASC;

-- As imagined, unit prices have to do with total revenues, and they are not quite reflected in total sales by volume.
-- total sales (number of orders) is irrelevant for decison making on that matter.
-- It would be a mistake to discard products based on volume of sales only, both variables should be taken into consideration.

-- Compare the 5 most and least-sold items (unit volume) and their revenues. 
-- This is a complicated analysis but very informative for deciding on which items to be eliminated from inventory
-- by having an idea of what itemized sales success looks like (in volume and revenue).
-- I created two tables, LEAST SOLD and MOST SOLD, each with its own sales raking based on quantityOrdered, and then UNION ALL them.
-- I made sure the ranking is sort by unit volume by limiting to 5 before the union, and by forcing ORDER BY total_units_sold
(
    SELECT 
        'LEAST SOLD' AS sales_rank,
        w.warehouseName,
        p.productCode,
        p.productName, 
        p.productLine,
		COALESCE(CAST(MIN(od.priceEach) AS CHAR), 'NaN') AS lowest_price_sold,
		COALESCE(CAST(MAX(od.priceEach) AS CHAR), 'NaN') AS highest_price_sold,
        COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold,
        p.quantityInStock AS in_stock_units,
        FORMAT(COALESCE(SUM(od.quantityOrdered * od.priceEach), 0), 2) AS total_revenue_generated
    FROM products p 
    LEFT JOIN orderdetails od ON p.productCode = od.productCode
    LEFT JOIN warehouses w ON p.warehouseCode = w.warehouseCode
    GROUP BY w.warehouseName, p.productCode, p.productName, p.productLine, p.quantityInstock
    ORDER BY total_units_sold ASC 
    LIMIT 5
)
UNION ALL
(
    SELECT 
        'MOST SOLD' AS sales_rank,
        w.warehouseName,
        p.productCode,
        p.productName, 
        p.productLine,
        COALESCE(CAST(MIN(od.priceEach) AS CHAR), 'NaN') AS lowest_price_sold,
		COALESCE(CAST(MAX(od.priceEach) AS CHAR), 'NaN') AS highest_price_sold,
        COALESCE(SUM(od.quantityOrdered), 0) AS total_units_sold,
		p.quantityInStock AS in_stock_units,
        FORMAT(COALESCE(SUM(od.quantityOrdered * od.priceEach), 0), 2) AS total_revenue_generated
    FROM products p 
    LEFT JOIN orderdetails od ON p.productCode = od.productCode
    LEFT JOIN warehouses w ON p.warehouseCode = w.warehouseCode
    GROUP BY w.warehouseName, p.productCode, p.productName, p.productLine, p.quantityInstock
    ORDER BY total_units_sold DESC 
    LIMIT 5
)
ORDER BY sales_rank DESC, total_units_sold DESC;

