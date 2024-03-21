--Sample SQL to demonstrate my ability to join tables and use common table expressions to answer questions about datasets

Use m_windler
go

-- List the name and truckid for every driver that has made a shipment, along each driver’s average shipment weight.
SELECT 
    DriverName, 
    Truck.TruckID, 
    AVG(ShipWeight) AS "Average ShipWeight"
FROM 
    Truck
JOIN 
    Shipment ON Truck.TruckID = Shipment.TruckID
GROUP BY 
    DriverName, Truck.TruckID;

-- What are the names of customers who have sent packages (shipments) to Honolulu?
SELECT 
    CustName
FROM 
    Customer
JOIN 
    Shipment ON Customer.CustID = Shipment.CustID
JOIN 
    City ON Shipment.CityID = City.CityID
WHERE 
    CityName = 'Honolulu';

-- Who are the customers (id, name, and cityname) either: 1) have over $2 million in annual revenue 
-- and have sent shipments weighing over 900 pounds or 2) have sent a shipment to Lubbock. 
-- No duplicates please, and alphabetize the city name backwards (Z to A).
SELECT DISTINCT 
    Customer.CustID, 
    CustName, 
    CityName
FROM 
    Customer
JOIN 
    Shipment ON Customer.CustID = Shipment.CustID
JOIN 
    City ON Shipment.CityID = City.CityID
WHERE 
    AnnualRevenue > 2000000 AND ShipWeight > 900 
    OR CityName = 'Lubbock'
ORDER BY 
    CityName DESC;

-- Who are the drivers (by name) who have delivered shipments for customers with annual 
-- revenue over $2 million to cities with populations over 4 million?
SELECT 
    DriverName
FROM 
    Truck
JOIN 
    Shipment ON Truck.TruckID = Shipment.TruckID
JOIN 
    Customer ON Shipment.CustID = Customer.CustID
JOIN 
    City ON Shipment.CityID = City.CityID
WHERE 
    AnnualRevenue > 2000000 
    OR CityPop > 4000000;

-- To what cities have customers with revenue less than $300,000 sent packages?
SELECT DISTINCT 
    CityName
FROM 
    City
JOIN 
    Shipment ON City.CityID = Shipment.CityID
JOIN 
    Customer ON Shipment.CustID = Customer.CustID
WHERE 
    AnnualRevenue < 300000;
