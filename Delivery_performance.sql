-- Map warehouse to region shipping
-- to see if there is a preference of shipping regions to stored items in warehouses, I need to know how many orders arrive to what region from 
-- which warehouse. Take a look at the table on most sold product lines per region to rearrange if needed.
-- WARNING: for this script to work properly, first execute mintclassics_data_cleared.

SELECT 
    ofc.territory AS destination_region,
    COUNT(DISTINCT o.orderNumber) AS total_orders_shipped,
    SUM(CASE WHEN w.warehousename = 'North' THEN od.quantityordered ELSE 0 END) AS From_North,
    SUM(CASE WHEN w.warehousename = 'East' THEN od.quantityordered ELSE 0 END) AS From_East,
    SUM(CASE WHEN w.warehousename = 'West' THEN od.quantityordered ELSE 0 END) AS From_West,
    SUM(CASE WHEN w.warehousename = 'South' THEN od.quantityordered ELSE 0 END) AS From_South,
    SUM(od.quantityordered) AS grand_total_units
FROM warehouses w
JOIN products p ON w.warehousecode = p.warehousecode
JOIN orderdetails od ON p.productcode = od.productcode
JOIN orders o ON od.ordernumber = o.orderNumber
JOIN customers c ON o.customernumber = c.customernumber
INNER JOIN employees e ON c.salesRepEmployeeNumber = e.employeenumber
JOIN offices ofc ON e.officeCode = ofc.officeCode
WHERE o.shippedDate IS NOT NULL
GROUP BY ofc.territory
ORDER BY grand_total_units DESC;

-- Provide statistics on shipping times
-- Limitations on this analysis: I do not have data on the actual time of arrival of products to destination offices, 
-- so I cannot predict if the shipping was late or not compared to historical shipping times. 
-- Instead, I set rules for shipping according to orderDate, requiredDate and shippedDate:
		-- if the shipped day was 4 days before the required date, then 'Early"
        -- if the shipped day was after the required date, then 'Late'
        -- Else, 'On time'

SELECT 
    CASE 
        WHEN o.shippedDate IS NULL THEN 'Not shipped'
        WHEN DATEDIFF(o.requiredDate, o.shippedDate) >=5 THEN 'Early'
        WHEN DATEDIFF(o.requiredDate, o.shippedDate) < 0 THEN 'Late'
        ELSE 'On time'
    END AS delivery_performance,
    COUNT(*) AS total_orders,
     IFNULL(CAST(ROUND(AVG(DATEDIFF(o.shippedDate, o.orderdate)), 0) AS CHAR), 'NA') AS avg_days_to_ship
FROM orders o
GROUP BY 
    CASE 
		WHEN o.shippedDate IS NULL THEN 'Not shipped'
        WHEN DATEDIFF(o.requiredDate, o.shippedDate) >=5 THEN 'Early'
        WHEN DATEDIFF(o.requiredDate, o.shippedDate) < 0 THEN 'Late'
        ELSE 'On time'
    END;     

-- Get the details on the shipping orders per country, following warehouse departures

SELECT
		COUNT(o.ordernumber) AS number_of_orders,
        ROUND(AVG(DATEDIFF(o.shippedDate, o.orderdate)),0) AS avg_days_to_ship,
        c.country,
        group_concat(DISTINCT w.warehouseName SEPARATOR ',') AS warehouses_affected
FROM orders o
INNER JOIN customers c ON o.customerNumber = c.customerNumber
INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
INNER JOIN products p ON od.productCode = p.productCode
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
WHERE o.shippeddate IS NOT NULL
GROUP BY c.country
ORDER BY avg_days_to_ship DESC;
    
-- It did not make sense that singapore had 17 days of shipping whereas Japan had 7. Maybe the late order was shipped to Singapore
-- and that changed the average.
-- Find the orders with longest shipping delays and trace the comments.

SELECT o.orderNumber,
	   o.orderDate,
       o.shippedDate,
       c.country,
       DATEDIFF(o.shippedDate, o.orderDate) AS ship_days,
       GROUP_CONCAT(DISTINCT w.warehouseName SEPARATOR ', ') AS affected_warehouses,
       CASE 
            WHEN o.comments REGEXP 'budget|credit|offer|hold' THEN 'Previously on hold'
            WHEN o.comments REGEXP 'complaint|color|scale|dispute' THEN 'Previously disputed'
            WHEN o.comments REGEXP 'damag|missing' THEN 'Shipping issues'
            WHEN o.comments REGEXP 'mistake' THEN 'Mistaken order'
            WHEN o.comments REGEXP 'on hold' THEN 'Previously on hold'
            WHEN o.comments IS NULL OR TRIM(o.comments) = '' THEN 'No comment'
            ELSE 'Irrelevant comments'
        END AS Reasons_Comments
FROM orders o
INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
INNER JOIN customers c ON o.customerNumber = c.customerNumber
INNER JOIN products p ON od.productCode = p.productCode
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
WHERE shippedDate IS NOT NULL
GROUP BY o.orderNumber
ORDER BY ship_days DESC;

-- corrected the avg days to ship per country, discarding order 10165

SELECT
		COUNT(o.ordernumber) AS number_of_orders,
        ROUND(AVG(DATEDIFF(o.shippedDate, o.orderdate)),0) AS avg_days_to_ship,
        c.country,
        group_concat(DISTINCT w.warehouseName SEPARATOR ',') AS warehouses_affected
FROM orders o
INNER JOIN customers c ON o.customerNumber = c.customerNumber
INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
INNER JOIN products p ON od.productCode = p.productCode
INNER JOIN warehouses w ON p.warehouseCode = w.warehouseCode
WHERE o.shippeddate IS NOT NULL AND o.orderNumber <> '10165'
GROUP BY c.country
ORDER BY avg_days_to_ship DESC;
