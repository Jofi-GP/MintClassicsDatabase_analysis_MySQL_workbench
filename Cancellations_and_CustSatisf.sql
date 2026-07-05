-- Product quality & Customer satisfaction
 
 -- Provide statistics of orders status from the orders table -percentage of orders processed, cancelled, on hold or disputed. 

SELECT 
    o.status AS order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage_of_total
FROM orders o
GROUP BY o.`status`
ORDER BY total_orders DESC;
  
 -- From this analysis, I found that some orders were cancelled or disputed.
 -- CAN THE COMMENT SECTION GIVE ME A HINT ON WHY ITEMS DID NOT SHIP?

-- This is a complex query because I neededd to compile a lot of data. Perhaphs I might have used a CTE. 
-- To make the table easier to read, I grouped the affected product lines and warehouses in single columns using GROUP_CONCAT
-- filtering the orders.
-- I used REGEXP to filter comments with keywords, it was hard to filter messages because very similar words were used in positive
-- and negative feedback

SELECT  o.orderNumber,
		o.customerNumber,
        c.country,
        -- Calculates unique product lines affected per order without duplicates
         GROUP_CONCAT(DISTINCT p.productLine SEPARATOR ', ') AS affected_product_lines,
         GROUP_CONCAT(DISTINCT w.warehouseName SEPARATOR ', ') AS affected_warehouses,
         SUM(CASE WHEN o.`status` = 'Cancelled' THEN od.quantityOrdered ELSE 0 END) AS total_items_cancelled,
        o.`status`,
        CASE 
            WHEN o.comments REGEXP 'sales|budget|credit|offer' THEN 'Budgeting Issues'
            WHEN o.comments REGEXP 'wrong|defect|complaint|color|scale|dispute' THEN 'Product Quality Issue'
            WHEN o.comments REGEXP 'damag|missing' THEN 'Shipping issues'
            WHEN o.comments REGEXP 'mistake' THEN 'Mistaken order'
            WHEN o.comments IS NULL OR TRIM(o.comments) = '' THEN 'No Reason Provided'
            ELSE 'Other Reasons'
        END AS Reasons_Comments
FROM orders o
LEFT JOIN orderdetails od ON o.orderNumber = od.orderNumber
LEFT JOIN products p ON od.productCode = p.productCode
LEFT JOIN warehouses w ON p.warehouseCode = w.warehouseCode
LEFT JOIN customers c ON o.customerNumber = c.customerNumber
WHERE o.`status` IN ('Disputed', 'Cancelled','Resolved')
GROUP BY o.orderNumber, o.customernumber, c.country, o.`status`, o.comments
ORDER BY reasons_comments;

-- From that table, 5 orders (10253, 10386, 10367, 10415 and 10417) were cancelled or disputed because of product quality issues
-- and customer dissatisfaction. Although it is a low proportion of orders, it might give a hint on products we can take out of our inventory.
-- Do all orders affected by comments on product quality include the same items? 
-- Here, I show that they do not.

SELECT
	  p.productName,
      COUNT(p.productCode) AS times_disputed,
      GROUP_CONCAT(o.orderNumber SEPARATOR ',') AS orders_involved
FROM orders o
INNER JOIN orderdetails od ON o.orderNumber = od.orderNumber
INNER JOIN products p ON od.productCode = p.productCode
WHERE o.orderNumber IN (10415, 10417, 10253, 10386, 10367)
GROUP BY p.productName
ORDER BY times_disputed DESC;
