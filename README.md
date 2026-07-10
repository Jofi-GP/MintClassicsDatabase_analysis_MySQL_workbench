
SQL scripts repository used for this report are organized as follows:
1.	Data cleared: critical step to ensure correct formatting of dates, and updated Japan into APAC region
2.	Background analysis: queries used to describe the overall business organization (regional sales and price gaps, customers demographics and active accounts, flagged customers)
3.	Cancellations and customer satisfaction: queries to answer if comments on orders table could help in determining warehouse connections to cancellations and disputes
4.	Delivery performance: queries used to find out the average days to ship per country or region and map the warehouse-to-region shipping.
5.	Inventory vs sales: queries for calculating the most and least sold items, average revenue per unit and total revenue of product lines.
6.	Stock movement: SQL queries for observing the stock health per warehouse (how many items were sold compared to stored) and recalculating the inventory reduction and restock
7.	Warehouse rearrangement: SQL queries to determine capacity ranks, product diversity, original distribution of product lines and what if scenarios.


Analysis Report for Mint Classics Model Cars

Project Scenario\
  Mint Classics Company, a retailer of classic model cars and other vehicles, is looking at closing one of their storage facilities.\
To support a data-based business decision, they are looking for suggestions and recommendations for reorganizing or reducing inventory, while still maintaining timely service to their customers.

Objectives
1. Explore products currently in inventory.
2. Determine important factors that may influence inventory reorganization/reduction.
3. Provide analytic insights and data-driven recommendations.

Skills demonstrated 

1. Import an existing database using MySQL Workbench and creating an EER (Extension.  
2. Become familiarized with business and its data by reviewing a relational model diagram and exploring tables of data in MySQL Workbench. 
3. Analyze inventory data using SQL queries in MySQL Workbench that retrieve data from a multiple-table relational database using SQL commands. 
4. Develop recommendations and suggestions for solving a business need/problem based on data analysis. 
5. Support your recommendations and suggestions for inventory reduction in the form of scripted queries. 
  
Summary

Mint Classics retail business operates through 7 offices in some of the most important cities around the globe. EMEA and NA are their largest customers, each taking around 40% of the market share. Their cured inventory of classic and vintage model cars, motorcycles and other specialized vehicles, is distributed across four warehouses (North, East, South, West), each hosting 1-3 product lines. Storage facilities are not organized by territory, and they are active in every country proportionally to their stock volume.\
To optimize their storage facilities capacities and align inventory with sales figures and objectives, I conducted a deep analysis of their business dynamics, 
identifying cold product stocks and low-sales product lines, to come up with a complete reorganization while considering their customers' voices. 

Approach
Step-by-step
1.	Explore products currently in inventory:  
  a.	Imported mintclassics database to MySQL Workbench  
  b.	Create an Extended Entity-Relationship (EER) diagram and investigate inter and intra table relationships (foreign keys, primary keys)  
  c.	Data quality checkup using SQL:  
    i.	Check dates formatting and normalize to yyyy-mm-dd  
    ii.	Check missing or duplicated information and update tables if necessary  
  d.	Use SQL to retrieve information from multi-table relationships and provide relevant statistics  
2.	Determine important factors that may influence inventory reorganization/reduction:  
  a.	What is the role of storage facilities regarding global shipping? Are some warehouses more efficient than others?  
  b.	Where are items stored and if they were rearranged, could a warehouse be eliminated?  
  c.	How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?  
  d.	Are we storing items that are not moving? Are any items candidates for being dropped from the product line?  	
3.	Formulate suggestions and recommendations for solving the business problem:  
  a.	Provide analytic insights and data-driven recommendations  
  b.	Create what-if scenarios  
4.	Final conclusions  

Insights and conclusions    
 
Key takeaways   

•	No evident link was found between warehouses and orders cancellations or disputes.
•	There is no reason to reorganize warehouses by regions, since there are no correlations on product lines revenues with regional shipping. 
•	East warehouse is the number one in ranking capacity and holds the higher revenue, even though its stock is slow-moving; South is the smallest in size and revenue, working almost at its full capacity, but has a healthy stock with items moving frequently; and West is the second largest facility, working at half capacity and probably experiencing delays in shipping. 
•	The 3 largest warehouses are alarmingly overstocked in low-selling products, while the most sold products need immediate restock. There might be an issue with repository or suppliers.
•	Delivery performance is similar between warehouses; however, the average number of days from ordering to shipping could be improved.  
•	Taking into consideration the high volatility on revenue per unit shown in the charts above, dropping items from the product line  or even calculating revenue per warehouse based just on volume sales is not appropriate; each model must be analyzed separately.  

Solutions  
Following the SQL analysis and conclusions, I propose these actions:  
•	There are two possible options for closing a storage facility:   
1.	Closing the South warehouse and distributing its product lines as follows: Trains and Ships to North and Trucks and Buses to West. This decision is based solely on stock volume and capacity on the remaining storages, since this facility is in overall good shape.  
2.	Close West warehouse and move items to East. West is a large facility, therefore more expensive, and is working at 50% of capacity. Moreover, it is associated with slow deliveries and severe overstock.   
	However, East warehouse cannot absorb the entire West inventory, because its capacity would be saturated.   
	Splitting a product line in several warehouses is not a good idea either; it can introduce complications with suppliers and post-sales operations
•	To overcome these issues, I suggest:  
o	Reducing 20% of each overstock volume in East and West warehouses and eliminating product S18_3233 from the product line before the closure of West.   
o	This could be achieved by sales events or promotions.   
 

