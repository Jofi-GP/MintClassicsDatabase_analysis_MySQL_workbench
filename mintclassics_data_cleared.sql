-- CLEAN THE DATA 
USE mintclassics;

-- DATA CLEARING PART 1: normalize dates formats in orders table
UPDATE orders
SET 
    orderDate = CASE 
        WHEN STR_TO_DATE(orderDate, '%d-%m-%Y') IS NOT NULL THEN DATE_FORMAT(STR_TO_DATE(orderDate, '%d-%m-%Y'), '%Y-%m-%d')
        ELSE NULL 
    END,
    
    requiredDate = CASE 
        WHEN STR_TO_DATE(requiredDate, '%d-%m-%Y') IS NOT NULL THEN DATE_FORMAT(STR_TO_DATE(requiredDate, '%d-%m-%Y'), '%Y-%m-%d')
        ELSE NULL 
    END,
    
    shippedDate = CASE 
        WHEN STR_TO_DATE(shippedDate, '%d-%m-%Y') IS NOT NULL THEN DATE_FORMAT(STR_TO_DATE(shippedDate, '%d-%m-%Y'), '%Y-%m-%d')
        ELSE NULL 
    END
WHERE 
    -- Bypasses Error 1175 by referencing an indexed key (replace 'id' with your actual PK column name)
    orderNumber > 0 
    AND (
        -- Targets rows where at least one date does NOT match the YYYY-MM-DD regex pattern
        orderDate NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' 
        OR requiredDate NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' 
        OR shippedDate NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    );

-- DATA QUALITY PART 2: check for duplicates in order numbers or product codes

SELECT 
    'Product Code' AS duplicate_type,
    productCode AS identifier,
    COUNT(*) AS duplicate_count
FROM products 
GROUP BY productCode
HAVING COUNT(*) > 1 
UNION ALL
SELECT 
    'Order Number' AS duplicate_type,
    CAST(orderNumber AS CHAR) AS identifier, 
    COUNT(*) AS duplicate_count
FROM orders 
GROUP BY orderNumber
HAVING COUNT(*) > 1;
  
-- DATA QUALITY PART 5: find missing payments if exist
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN CustomerNumber IS NULL THEN 1 ELSE 0 END) AS missing_customers,
       SUM(CASE WHEN checkNumber IS NULL THEN 1 ELSE 0 END) AS missing_check_number,
       SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS missing_amount
       FROM payments;

-- DATA QUALITY PART 6: check how many orders have missing ordering dates, required dates and/or order Dates

SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN orderDate IS NULL THEN 1 ELSE 0 END) AS missing_order_date,
       SUM(CASE WHEN requiredDate IS NULL THEN 1 ELSE 0 END) AS missing_required_date
       FROM orders;
       
-- DATA QUALITY: check missing sales representatives contacts

SELECT COUNT(*) AS total_rows,
		SUM(CASE WHEN salesRepEmployeeNumber IS NULL THEN 1 ELSE 0 END) AS missing_sales_Rep,
        SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS missing_city,
        SUM(CASE WHEN customerNumber IS NULL THEN 1 ELSE 0 END) AS missing_customer,
        SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS missing_country
        FROM customers;

-- DATA QUALITY: check office territories
SELECT officeCode, city, country, territory 
FROM offices 
ORDER BY territory, country;

-- I decided to update offices table to include Japan in APAC territory. Even if I could bypass updating it, it was really complex code and
-- had to ask AI all the time. Since I am in safe mode, I found a way to overcome this is by updating the table temporarily (changes won't commit)
UPDATE offices 
SET territory = 'APAC' 
WHERE officeCode IN (
    SELECT officeCode 
    FROM (SELECT officeCode FROM offices WHERE country = 'Japan') AS temp
);


