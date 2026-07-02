-- Where are items stored and if they were rearranged, could a warehouse be eliminated?

-- FOR WAREHOUSE REDUCTION: 
-- In this script, I used the warehouse percentage of occupation (PctCap) to calculate each warehouse's total capacity. 
-- The goal is to optimize the use of space in warehouses, looking for a) the warehouse with most empty space (not being fully used) and the ones with
-- enough space to hold extra items


-- To calculate the space available in each warehouse:
-- With products table, I calculated the number of total products per warehousecode and then associated it with the corresponding name in warehouses table. 
-- If the total of products = the current PctCap of the warehouse, calculate the theoretical total capacity by dividing that sum by the percentage occupation
-- calculate also the remaining slots

USE mintclassics;
SELECT 
    w.warehouseCode,
    w.warehouseName,
    w.warehousePctCap,
    SUM(p.quantityInStock) AS current_item_count,
    -- Calculates 100% theoretical storage capacity limit
    ROUND(SUM(p.quantityInStock) / (w.warehousePctCap / 100), 0) AS theoretical_capacity,
    -- Calculates exactly how many empty spaces are left on shelves
    ROUND((SUM(p.quantityInStock) / (w.warehousePctCap / 100)) - SUM(p.quantityInStock), 0) AS remaining_empty_slots,
	DENSE_RANK() OVER (
        ORDER BY CASE WHEN w.warehousePctCap > 0 THEN SUM(p.quantityInStock) / (w.warehousePctCap / 100) ELSE 0 END DESC
    ) AS capacity_rank
FROM warehouses w
INNER JOIN products p ON w.warehouseCode = p.warehouseCode
GROUP BY w.warehouseCode, w.warehouseName, w.warehousePctCap
ORDER BY capacity_rank ASC;

-- PART 3 Is the warehouse inventory distribution diverse enough?

-- Distribution of product lines between warehouses can help deciding the easiest movement of products and the logistics associated with them.
-- This analysis is limited because I am lacking the geographycal location of the warehouse and the shipping distance.
-- I calculated unique products sold per warehouse, the product lines they belong to and the representation in the company overall catalog of
-- retail cars. 

SELECT 
    w.warehouseCode, 
    w.warehouseName, 
    COUNT(DISTINCT p.productCode) AS unique_items_sold,
    GROUP_CONCAT(DISTINCT p.productLine SEPARATOR ', ') AS product_lines_sold,
    ROUND((COUNT(p.productCode) / (SELECT COUNT(*) FROM products)) * 100, 1) AS percent_of_company_catalog
FROM products p
LEFT JOIN warehouses w ON p.warehouseCode = w.warehouseCode
GROUP BY w.warehouseCode, w.warehouseName
ORDER BY unique_items_sold ASC;


-- CREATE A WHAT IF SCENARIO
-- WHAT HAPPENS IF THE UNSOLD AND LOW SELL ITEMS ARE REMOVED FROM THE WAREHOUSE EAST? HOW MUCH SPACE IS FREED?
-- I used AI to help me mock scenarios 

-- 1) Calculate the original warehouses stock, capital tied and revenue.
SELECT 
    w.warehouseCode AS `Code`,
    w.warehouseName AS `Warehouse name`,
    COALESCE(inv.ProductLines, 'None') AS `Product Lines`,
    FORMAT(COALESCE(inv.total_stock, 0), 0) AS `Current Stock`,
    FORMAT(COALESCE(inv.total_inventory_cost, 0), 2) AS `Tied Capital`,
    FORMAT(COALESCE(rev.total_revenue, 0), 2) AS `Historical Revenue`,
    w.warehousePctCap AS `Occupied capacity%`
FROM warehouses w
-- Subquery 1: Calculate stock, costs, and unique product lines
LEFT JOIN (
    SELECT 
        warehouseCode,
        SUM(quantityInStock) AS total_stock,
        SUM(quantityInStock * buyprice) AS total_inventory_cost,
        GROUP_CONCAT(DISTINCT productLine ORDER BY productLine SEPARATOR ', ') AS ProductLines
    FROM products
    GROUP BY warehouseCode
) inv ON w.warehouseCode = inv.warehouseCode
-- Subquery 2: Calculate historical revenue per warehouse
LEFT JOIN (
    SELECT 
        p.warehouseCode,
        SUM(od.quantityOrdered * od.priceEach) AS total_revenue
    FROM orderdetails od
    INNER JOIN products p ON od.productCode = p.productCode
    INNER JOIN orders o ON od.orderNumber = o.orderNumber
    WHERE o.`status` NOT IN ('On Hold', 'Cancelled', 'In Process')
    GROUP BY p.warehouseCode
) rev ON w.warehouseCode = rev.warehouseCode;

-- 2) take the items in warehouse South and rearrange them in North and West
-- Simulate the product line reallocation and consolidated warehouse capacities

SELECT 
    SimulatedData.`Warehouse Code`,
    SimulatedData.`Simulated Warehouse`,
    SimulatedData.`New Product Lines`,
    FORMAT(SimulatedData.RawStock, 0) AS `Simulated Stock Qty`,
    FORMAT(SimulatedData.RawCapital, 2) AS `Simulated Tied Capital ($)`,
    FORMAT(SimulatedData.RawRevenue, 2) AS `Simulated Shipped Revenue ($)`,
    -- Formats the new capacity percentage to 1 decimal place with a % symbol
    CONCAT(FORMAT(SimulatedData.RawPctCap, 1), '%') AS `Simulated Capacity (%)`
FROM (
    -- NORTH WAREHOUSE CONSOLIDATION
    SELECT 
        w.warehouseCode AS `Warehouse Code`,
        'North (Consolidated)' AS `Simulated Warehouse`,
        'Motorcycles, Planes, Trucks and Buses' AS `New Product Lines`,
        -- Original North Stock + South's Trucks & Buses Stock
        (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
        (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE productLine = 'Trucks and Buses') AS RawStock,
        -- Original North Capital + South's Trucks & Buses Capital
        (SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
        (SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) FROM products WHERE productLine = 'Trucks and Buses') AS RawCapital,
        -- Original North Revenue + South's Trucks & Buses Revenue
        (SELECT COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) 
         FROM orderdetails od 
         JOIN orders o ON od.orderNumber = o.orderNumber 
         JOIN products p ON od.productCode = p.productCode
         WHERE p.warehouseCode = w.warehouseCode AND o.status = 'Shipped') +
        (SELECT COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) 
         FROM orderdetails od 
         JOIN orders o ON od.orderNumber = o.orderNumber 
         JOIN products p ON od.productCode = p.productCode
         WHERE p.productLine = 'Trucks and Buses' AND o.status = 'Shipped') AS RawRevenue,
         
        -- NEW CAPACITY CALCULATION (North)
        (
            ((SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
             (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE productLine = 'Trucks and Buses'))
            / NULLIF((SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode), 0)
        ) * w.warehousePctCap AS RawPctCap

    FROM warehouses w
    WHERE w.warehouseName = 'North'

    UNION ALL

    -- WEST WAREHOUSE CONSOLIDATION
    SELECT 
        w.warehouseCode AS `Warehouse Code`,
        'West (Consolidated)' AS `Simulated Warehouse`,
        'Vintage Cars, Ships, Trains' AS `New Product Lines`,
        -- Original West Stock + South's Ships & Trains Stock
        (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
        (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE productLine IN ('Ships', 'Trains')) AS RawStock,
        -- Original West Capital + South's Ships & Trains Capital
        (SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
        (SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) FROM products WHERE productLine IN ('Ships', 'Trains')) AS RawCapital,
        -- Original West Revenue + South's Ships & Trains Revenue
        (SELECT COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) 
         FROM orderdetails od 
         JOIN orders o ON od.orderNumber = o.orderNumber 
         JOIN products p ON od.productCode = p.productCode
         WHERE p.warehouseCode = w.warehouseCode AND o.status = 'Shipped') +
        (SELECT COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) 
         FROM orderdetails od 
         JOIN orders o ON od.orderNumber = o.orderNumber 
         JOIN products p ON od.productCode = p.productCode
         WHERE p.productLine IN ('Ships', 'Trains' ) AND o.status = 'Shipped') AS RawRevenue,
         
        -- NEW CAPACITY CALCULATION (West)
        (
            ((SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode) +
             (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE productLine IN ('Ships', 'Trains')))
            / NULLIF((SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode), 0)
        ) * w.warehousePctCap AS RawPctCap

    FROM warehouses w
    WHERE w.warehouseName = 'West'

    UNION ALL

    -- EAST WAREHOUSE (UNCHANGED)
    SELECT 
        w.warehouseCode AS `Warehouse Code`,
        'East' AS `Simulated Warehouse`,
        'Classic Cars' AS `New Product Lines`,
        (SELECT COALESCE(SUM(quantityInStock), 0) FROM products WHERE warehouseCode = w.warehouseCode) AS RawStock,
        (SELECT COALESCE(SUM(quantityInStock * buyPrice), 0) FROM products WHERE warehouseCode = w.warehouseCode) AS RawCapital,
        (SELECT COALESCE(SUM(od.quantityOrdered * od.priceEach), 0) 
         FROM orderdetails od 
         JOIN orders o ON od.orderNumber = o.orderNumber 
         JOIN products p ON od.productCode = p.productCode
         WHERE p.warehouseCode = w.warehouseCode AND o.status = 'Shipped' ) AS RawRevenue,
         
        -- NEW CAPACITY CALCULATION (East remains exactly original)
        w.warehousePctCap AS RawPctCap
    FROM warehouses w
    WHERE w.warehouseName = 'East'
) AS SimulatedData;
