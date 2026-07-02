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
1.	Understanding the data:  
a.	Created an Extended Entity-Relationship (EER) diagram  
b.	Data quality checkup:  
i.	Checked duplicate orders  
ii.	Checked dates formatting and normalize to yyyy-mm-dd  
iii.	Checked missing information (dates, payments, order numbers, contacts)  
iv.	Updated the offices table to include Japan into APAC territory  
c.	Provided relevant statistics on regional sales, customers demographics, shipment details and distribution of product lines  
2.	Analysis formulation:  
a.	Where are items stored and if they were rearranged, could a warehouse be eliminated?  
b.	How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?  
c.	Are we storing items that are not moving? Are any items candidates for being dropped from the product line?  
3.	Insights and conclusions  
a.	Solution  

Results are the SQL files included in this repository

Insights and conclusions  
Key takeaways from the analysis  
•	Roughly 2% of total orders are cancelled and/or disputed, and the reasons are mostly customer financial situation and their satisfaction with the product. 
There is no link between distinct warehouses and cancellations or disputes.  
•	Each warehouse ships to all regions proportionally to the number of customers and revenue. There is no reason to reorganize warehouses according to regional 
preferences.  
•	Classic cars is the product line with the highest revenue, followed by Vintage cars. Ships, trains and planes are the least sold, in that order.  
•	Although there is some difference of preference on products lines, the highest sold and the lowest sold are the same ones between regions, and belong to the 
same product lines with one exception.   
•	There is, however, a substantial difference in warehouse diversity and revenue. East warehouse is the biggest one with least diversity of product lines and 
lowest stock movement, whereas South one is the smallest with the largest amount of product lines and the highest movement of inventory. 
•	North and South are working at 72 and 75% of their capacity, respectively. And the 3 largest warehouses are alarmingly overstocked in low selling products, 
while the most required ones need immediate restock. There might be an issue with repository systems.  
•	There are though 3 clear least-sold models, one of which is absolutely dead (zero sales) and other one with very low revenues. Might consider ditching the bitches.  

Solutions
Following the SQL analysis and conclusions, I propose these actions:
•	If there is an absolute need on reducing cost from facilities (either rent, services, taxes, etc) I suggest closing the South warehouse and distribute its 
product lines as follows: Trains and Ships to North and Trucks and Buses to West. This decision is based only in storage size and overall revenue, because no other
parameters are relevant for the decision (shipping, inventory movement, product line diversity).
•	Primarily: reduce 10% of stock volume for flagged items. This could be achieved by sales events or promotion, to recover the investment on historically 
low-selling products.
•	Eventually eliminate inventory items S18_3233 and S24_3969. Both of them match the conditions of severely overstock (either low sales or dead sales), 
and revenues below 30K. 
•	Observe restock mechanisms and be vigilant on providers.

