SELECT COUNT(*) AS Raw_Row_Count FROM ncr_ride_bookings;
SELECT * FROM ncr_ride_bookings LIMIT 10;

-- creating staging table

DROP TABLE IF EXISTS uber_rides_staging;
CREATE TABLE uber_rides_staging LIKE ncr_ride_bookings;


INSERT INTO uber_rides_staging 
SELECT *
FROM ncr_ride_bookings;

SELECT * FROM uber_rides_staging;

SELECT COUNT(*) AS Staging_Initial_Count 
FROM uber_rides_staging;
-- -------------------------------------------------------------
-- DATA CLEANING STARTS HERE
-- -------------------------------------------------------------
-- 1. REMOVING BLANK/NULL BOOKING IDS
-- -------------------------------------------------------------
SET SQL_SAFE_UPDATES = 0;

DELETE FROM uber_rides_staging
WHERE `Booking ID` IS NULL OR TRIM(`Booking ID`) = '';

-- 2. CHECKING FOR DUPLICATE BOOKING IDS

SELECT `Booking ID`, COUNT(*) AS Duplicate_Count
FROM  uber_rides_staging
GROUP BY `Booking ID`
HAVING COUNT(*) > 1;

# this shows same booking id but other clms dont have same info (not 'TRUE DUPLICATES' )

SELECT *
FROM uber_rides_staging
WHERE `Booking ID` LIKE '%CNR2687237%';

SELECT *,
ROW_NUMBER() OVER(
PARTITION BY `Date`, `Time`, `Booking ID`, `Booking Status`, `Customer ID`, `Vehicle Type`, `Pickup Location`, `Drop Location`, `Avg VTAT`,`Avg CTAT`, `Cancelled Rides by Customer`, `Reason for cancelling by Customer` ,`Cancelled Rides by Driver`, `Driver Cancellation Reason`, `Incomplete Rides`, `Incomplete Rides Reason`, `Booking Value`, `Ride Distance`, `Driver Ratings`, `Customer Rating`, `Payment Method`) AS row_num
FROM uber_rides_staging;
# THIS SHOWS ALL ROW_NUM COUNTED ONCE ( 1 )
# NOW I NEED WHRE THE COUNT IS > 1

SET SQL_SAFE_UPDATES = 1;
-- --------------------------------------------------------
# checks all clms for duplicates

WITH duplicate_cte AS 
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY `Date`, `Time`, `Booking ID`, `Booking Status`, `Customer ID`, `Vehicle Type`, `Pickup Location`, `Drop Location`, `Avg VTAT`,`Avg CTAT`, `Cancelled Rides by Customer`, `Reason for cancelling by Customer` ,`Cancelled Rides by Driver`, `Driver Cancellation Reason`, `Incomplete Rides`, `Incomplete Rides Reason`, `Booking Value`, `Ride Distance`, `Driver Ratings`, `Customer Rating`, `Payment Method`) AS row_num
FROM uber_rides_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;
-- ---------------------------------------------------------
# all duplicates info

SELECT *
FROM (
    SELECT *, COUNT(*) OVER(PARTITION BY `Booking ID`) AS Duplicate_Count
    FROM uber_rides_staging
) AS duplicate_check

WHERE Duplicate_Count > 1
ORDER BY `Booking ID`;
-- ---------------------------------------------------
# duplicate check all clms

SELECT *,
       COUNT(*) AS Duplicate_Count
FROM uber_rides_staging
GROUP BY
    `Date`,
    `Time`,
    `Booking ID`,
    `Booking Status`,
    `Customer ID`,
    `Vehicle Type`,
    `Pickup Location`,
    `Drop Location`,
    `Avg VTAT`,
    `Avg CTAT`,
    `Cancelled Rides by Customer`,
    `Reason for cancelling by Customer`,
    `Cancelled Rides by Driver`,
    `Driver Cancellation Reason`,
    `Incomplete Rides`,
    `Incomplete Rides Reason`,
    `Booking Value`,
    `Ride Distance`,
    `Driver Ratings`,
    `Customer Rating`,
    `Payment Method`
HAVING COUNT(*) > 1;

-- ---------------------------

DESCRIBE uber_rides_staging;

SELECT `Date`
FROM uber_rides_staging
WHERE `Date` IS NOT NULL
  AND TRIM(`Date`) <> ''
  AND STR_TO_DATE(`Date`, '%Y-%m-%d') IS NULL;

ALTER TABLE uber_rides_staging
MODIFY COLUMN `Date` DATE;

DESCRIBE uber_rides_staging;

-- checking time format
SELECT DISTINCT `Time`
FROM uber_rides_staging
ORDER BY `Time`
LIMIT 100;

-- changing time format from text to sql TIME
SELECT `Time`
FROM uber_rides_staging
WHERE `Time` IS NOT NULL
  AND TRIM(`Time`) <> ''
  AND (
      TIME_FORMAT(
          STR_TO_DATE(`Time`, '%H:%i:%s'),
          '%H:%i:%s'
      ) IS NULL
      OR TIME_FORMAT(
          STR_TO_DATE(`Time`, '%H:%i:%s'),
          '%H:%i:%s'
      ) <> `Time`
  );
  
ALTER TABLE uber_rides_staging
MODIFY COLUMN `Time` TIME;

DESCRIBE uber_rides_staging;

SELECT
    `Avg VTAT`,
    `Avg CTAT`,
    `Cancelled Rides by Customer`,
    `Cancelled Rides by Driver`,
    `Incomplete Rides`,
    `Booking Value`,
    `Ride Distance`,
    `Driver Ratings`,
    `Customer Rating`
FROM uber_rides_staging
LIMIT 20;

-- this explains how many values are missing in each column.
SELECT
    COUNT(*) AS Total_Rows,

    SUM(`Avg VTAT` IS NULL OR TRIM(`Avg VTAT`) = '') AS Missing_Avg_VTAT,

    SUM(`Avg CTAT` IS NULL OR TRIM(`Avg CTAT`) = '') AS Missing_Avg_CTAT,

    SUM(`Cancelled Rides by Customer` IS NULL OR TRIM(`Cancelled Rides by Customer`) = '') AS Missing_Customer_Cancellations,

    SUM(`Cancelled Rides by Driver` IS NULL OR TRIM(`Cancelled Rides by Driver`) = '') AS Missing_Driver_Cancellations,

    SUM(`Incomplete Rides` IS NULL OR TRIM(`Incomplete Rides`) = '') AS Missing_Incomplete_Rides,

    SUM(`Booking Value` IS NULL OR TRIM(`Booking Value`) = '') AS Missing_Booking_Value,

    SUM(`Ride Distance` IS NULL OR TRIM(`Ride Distance`) = '') AS Missing_Ride_Distance,

    SUM(`Driver Ratings` IS NULL OR TRIM(`Driver Ratings`) = '') AS Missing_Driver_Ratings,

    SUM(`Customer Rating` IS NULL OR TRIM(`Customer Rating`) = '') AS Missing_Customer_Ratings

FROM uber_rides_staging;

SELECT `Booking Status`, COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Booking Status`
ORDER BY Total_Bookings DESC;

-- 
SELECT `Booking Status`, COUNT(*) AS Total_Bookings,
	SUM(
        `Cancelled Rides by Customer` IS NOT NULL
        AND TRIM(`Cancelled Rides by Customer`) <> ''
    ) AS Customer_Cancellation_Values,

    SUM(
        `Cancelled Rides by Driver` IS NOT NULL
        AND TRIM(`Cancelled Rides by Driver`) <> ''
    ) AS Driver_Cancellation_Values,

    SUM(
        `Incomplete Rides` IS NOT NULL
        AND TRIM(`Incomplete Rides`) <> ''
    ) AS Incomplete_Ride_Values

FROM uber_rides_staging
GROUP BY `Booking Status`
ORDER BY Total_Bookings DESC;




-- Check for unexpected non-numeric text (regex) --> N/A, Unknown, 12km, ₹250, 12,500

SELECT
    `Avg VTAT`,
    `Avg CTAT`,
    `Booking Value`,
    `Ride Distance`,
    `Driver Ratings`,
    `Customer Rating`,
    `Cancelled Rides by Customer`,
    `Cancelled Rides by Driver`,
    `Incomplete Rides`
FROM uber_rides_staging
WHERE
    -- Decimal columns
    (`Avg VTAT` IS NOT NULL AND TRIM(`Avg VTAT`) <> ''
        AND TRIM(`Avg VTAT`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

 OR (`Avg CTAT` IS NOT NULL AND TRIM(`Avg CTAT`) <> ''
        AND TRIM(`Avg CTAT`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

 OR (`Booking Value` IS NOT NULL AND TRIM(`Booking Value`) <> ''
        AND TRIM(`Booking Value`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

 OR (`Ride Distance` IS NOT NULL AND TRIM(`Ride Distance`) <> ''
        AND TRIM(`Ride Distance`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

 OR (`Driver Ratings` IS NOT NULL AND TRIM(`Driver Ratings`) <> ''
        AND TRIM(`Driver Ratings`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

 OR (`Customer Rating` IS NOT NULL AND TRIM(`Customer Rating`) <> ''
        AND TRIM(`Customer Rating`) NOT REGEXP '^[0-9]+(\\.[0-9]+)?$')

    -- Whole-number columns
 OR (`Cancelled Rides by Customer` IS NOT NULL
        AND TRIM(`Cancelled Rides by Customer`) <> ''
        AND TRIM(`Cancelled Rides by Customer`) NOT REGEXP '^[0-9]+$')

 OR (`Cancelled Rides by Driver` IS NOT NULL
        AND TRIM(`Cancelled Rides by Driver`) <> ''
        AND TRIM(`Cancelled Rides by Driver`) NOT REGEXP '^[0-9]+$')

 OR (`Incomplete Rides` IS NOT NULL
        AND TRIM(`Incomplete Rides`) <> ''
        AND TRIM(`Incomplete Rides`) NOT REGEXP '^[0-9]+$')
LIMIT 50;

-- negative value checking
SELECT *
FROM uber_rides_staging
WHERE
    (NULLIF(TRIM(`Avg VTAT`), '') IS NOT NULL
        AND CAST(`Avg VTAT` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Avg CTAT`), '') IS NOT NULL
        AND CAST(`Avg CTAT` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Booking Value`), '') IS NOT NULL
        AND CAST(`Booking Value` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Ride Distance`), '') IS NOT NULL
        AND CAST(`Ride Distance` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Driver Ratings`), '') IS NOT NULL
        AND CAST(`Driver Ratings` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Customer Rating`), '') IS NOT NULL
        AND CAST(`Customer Rating` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Cancelled Rides by Customer`), '') IS NOT NULL
        AND CAST(`Cancelled Rides by Customer` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Cancelled Rides by Driver`), '') IS NOT NULL
        AND CAST(`Cancelled Rides by Driver` AS DECIMAL(10,2)) < 0)
 OR (NULLIF(TRIM(`Incomplete Rides`), '') IS NOT NULL
        AND CAST(`Incomplete Rides` AS DECIMAL(10,2)) < 0)
LIMIT 50;

-- checking driver rating, customer rating
SELECT
    MIN(CAST(NULLIF(TRIM(`Driver Ratings`), '') AS DECIMAL(5,2))) AS Min_Driver_Rating,
    MAX(CAST(NULLIF(TRIM(`Driver Ratings`), '') AS DECIMAL(5,2))) AS Max_Driver_Rating,
    MIN(CAST(NULLIF(TRIM(`Customer Rating`), '') AS DECIMAL(5,2))) AS Min_Customer_Rating,
    MAX(CAST(NULLIF(TRIM(`Customer Rating`), '') AS DECIMAL(5,2))) AS Max_Customer_Rating
FROM uber_rides_staging;

-- checking booking value, ride distance
SELECT
    MIN(CAST(NULLIF(TRIM(`Booking Value`), '') AS DECIMAL(10,2))) AS Min_Booking_Value,
    MAX(CAST(NULLIF(TRIM(`Booking Value`), '') AS DECIMAL(10,2))) AS Max_Booking_Value,
    MIN(CAST(NULLIF(TRIM(`Ride Distance`), '') AS DECIMAL(10,2))) AS Min_Ride_Distance,
    MAX(CAST(NULLIF(TRIM(`Ride Distance`), '') AS DECIMAL(10,2))) AS Max_Ride_Distance
FROM uber_rides_staging;

-- how many rides have ride distance above 30?  (unit not specified) -- just a random check

SELECT COUNT(*) AS Rides_Above_30
FROM uber_rides_staging
WHERE CAST(`Ride Distance` AS DECIMAL(10,2)) > 30;

-- TOTAL RIDES GROUP BY DISTANCE RANGE
SELECT
    CASE
        WHEN CAST(`Ride Distance` AS DECIMAL(10,2)) <= 10 THEN '1-10'
        WHEN CAST(`Ride Distance` AS DECIMAL(10,2)) <= 20 THEN '11-20'
        WHEN CAST(`Ride Distance` AS DECIMAL(10,2)) <= 30 THEN '21-30'
        WHEN CAST(`Ride Distance` AS DECIMAL(10,2)) <= 40 THEN '31-40'
        ELSE '41-50'
    END AS Distance_Range,
    COUNT(*) AS Total_Rides
FROM uber_rides_staging
WHERE `Ride Distance` IS NOT NULL
  AND TRIM(`Ride Distance`) <> ''
GROUP BY Distance_Range
ORDER BY MIN(CAST(`Ride Distance` AS DECIMAL(10,2)));

-- BOOKING VALUE DISTRIBUTION (cost/money range on rides)

SELECT
    CASE
        WHEN CAST(`Booking Value` AS DECIMAL(10,2)) <= 500 THEN '0-500'
        WHEN CAST(`Booking Value` AS DECIMAL(10,2)) <= 1000 THEN '501-1000'
        WHEN CAST(`Booking Value` AS DECIMAL(10,2)) <= 2000 THEN '1001-2000'
        WHEN CAST(`Booking Value` AS DECIMAL(10,2)) <= 3000 THEN '2001-3000'
        ELSE '3001-4277'
    END AS Booking_Value_Range,
    COUNT(*) AS Total_Bookings
FROM uber_rides_staging
WHERE `Booking Value` IS NOT NULL
  AND TRIM(`Booking Value`) <> ''
GROUP BY Booking_Value_Range
ORDER BY MIN(CAST(`Booking Value` AS DECIMAL(10,2)));


SELECT
    COUNT(*) AS Total_Rows,

    SUM(LOWER(TRIM(CAST(`Date` AS CHAR))) = 'null') AS Null_Date,
    SUM(LOWER(TRIM(CAST(`Time` AS CHAR))) = 'null') AS Null_Time,
    SUM(LOWER(TRIM(`Booking ID`)) = 'null') AS Null_Booking_ID,
    SUM(LOWER(TRIM(`Booking Status`)) = 'null') AS Null_Booking_Status,
    SUM(LOWER(TRIM(`Customer ID`)) = 'null') AS Null_Customer_ID,
    SUM(LOWER(TRIM(`Vehicle Type`)) = 'null') AS Null_Vehicle_Type,
    SUM(LOWER(TRIM(`Pickup Location`)) = 'null') AS Null_Pickup,
    SUM(LOWER(TRIM(`Drop Location`)) = 'null') AS Null_Drop,

    SUM(LOWER(TRIM(`Avg VTAT`)) = 'null') AS Null_VTAT,
    SUM(LOWER(TRIM(`Avg CTAT`)) = 'null') AS Null_CTAT,

    SUM(LOWER(TRIM(`Cancelled Rides by Customer`)) = 'null') AS Null_Customer_Cancellations,
    SUM(LOWER(TRIM(`Reason for cancelling by Customer`)) = 'null') AS Null_Customer_Reason,

    SUM(LOWER(TRIM(`Cancelled Rides by Driver`)) = 'null') AS Null_Driver_Cancellations,
    SUM(LOWER(TRIM(`Driver Cancellation Reason`)) = 'null') AS Null_Driver_Reason,

    SUM(LOWER(TRIM(`Incomplete Rides`)) = 'null') AS Null_Incomplete_Rides,
    SUM(LOWER(TRIM(`Incomplete Rides Reason`)) = 'null') AS Null_Incomplete_Reason,

    SUM(LOWER(TRIM(`Booking Value`)) = 'null') AS Null_Booking_Value,
    SUM(LOWER(TRIM(`Ride Distance`)) = 'null') AS Null_Ride_Distance,
    SUM(LOWER(TRIM(`Driver Ratings`)) = 'null') AS Null_Driver_Rating,
    SUM(LOWER(TRIM(`Customer Rating`)) = 'null') AS Null_Customer_Rating,
    SUM(LOWER(TRIM(`Payment Method`)) = 'null') AS Null_Payment_Method

FROM uber_rides_staging;

SELECT
    COUNT(*) AS Total_Rows,
    SUM(TRIM(`Avg VTAT`) = '') AS Blank_Avg_VTAT,
    SUM(TRIM(`Avg CTAT`) = '') AS Blank_Avg_CTAT,
    SUM(TRIM(`Cancelled Rides by Customer`) = '') AS Blank_Customer_Cancellations,
    SUM(TRIM(`Cancelled Rides by Driver`) = '') AS Blank_Driver_Cancellations,
    SUM(TRIM(`Incomplete Rides`) = '') AS Blank_Incomplete_Rides,
    SUM(TRIM(`Booking Value`) = '') AS Blank_Booking_Value,
    SUM(TRIM(`Ride Distance`) = '') AS Blank_Ride_Distance,
    SUM(TRIM(`Driver Ratings`) = '') AS Blank_Driver_Ratings,
    SUM(TRIM(`Customer Rating`) = '') AS Blank_Customer_Ratings
FROM uber_rides_staging;

SELECT @@SESSION.sql_mode;

-- Convert text to the numeric columns
ALTER TABLE uber_rides_staging
    MODIFY COLUMN `Avg VTAT` DECIMAL(10,2),
    MODIFY COLUMN `Avg CTAT` DECIMAL(10,2),
    MODIFY COLUMN `Cancelled Rides by Customer` INT,
    MODIFY COLUMN `Cancelled Rides by Driver` INT,
    MODIFY COLUMN `Incomplete Rides` INT,
    MODIFY COLUMN `Booking Value` DECIMAL(10,2),
    MODIFY COLUMN `Ride Distance` DECIMAL(10,2),
    MODIFY COLUMN `Driver Ratings` DECIMAL(3,2),
    MODIFY COLUMN `Customer Rating` DECIMAL(3,2);

-- Check categorical columns for blank values
SELECT
    COUNT(*) AS Total_Rows,
    SUM(TRIM(`Booking ID`) = '') AS Blank_Booking_ID,
    SUM(TRIM(`Booking Status`) = '') AS Blank_Booking_Status,
    SUM(TRIM(`Customer ID`) = '') AS Blank_Customer_ID,
    SUM(TRIM(`Vehicle Type`) = '') AS Blank_Vehicle_Type,
    SUM(TRIM(`Pickup Location`) = '') AS Blank_Pickup_Location,
    SUM(TRIM(`Drop Location`) = '') AS Blank_Drop_Location,
    SUM(TRIM(`Reason for cancelling by Customer`) = '') AS Blank_Customer_Reason,
    SUM(TRIM(`Driver Cancellation Reason`) = '') AS Blank_Driver_Reason,
    SUM(TRIM(`Incomplete Rides Reason`) = '') AS Blank_Incomplete_Reason,
    SUM(TRIM(`Payment Method`) = '') AS Blank_Payment_Method
FROM uber_rides_staging;

-- checks the vehicle categories for inconsistent spellings or capitalization
SELECT
    SUM(`Booking ID` <> TRIM(`Booking ID`)) AS Booking_ID_Spaces,
    SUM(`Booking Status` <> TRIM(`Booking Status`)) AS Booking_Status_Spaces,
    SUM(`Customer ID` <> TRIM(`Customer ID`)) AS Customer_ID_Spaces,
    SUM(`Vehicle Type` <> TRIM(`Vehicle Type`)) AS Vehicle_Type_Spaces,
    SUM(`Pickup Location` <> TRIM(`Pickup Location`)) AS Pickup_Location_Spaces,
    SUM(`Drop Location` <> TRIM(`Drop Location`)) AS Drop_Location_Spaces,
    SUM(`Reason for cancelling by Customer` <> TRIM(`Reason for cancelling by Customer`)) AS Customer_Reason_Spaces,
    SUM(`Driver Cancellation Reason` <> TRIM(`Driver Cancellation Reason`)) AS Driver_Reason_Spaces,
    SUM(`Incomplete Rides Reason` <> TRIM(`Incomplete Rides Reason`)) AS Incomplete_Reason_Spaces,
    SUM(`Payment Method` <> TRIM(`Payment Method`)) AS Payment_Method_Spaces
FROM uber_rides_staging;


-- booking count group by vehicle type 

SELECT `Vehicle Type`, COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Vehicle Type`
ORDER BY Total_Bookings DESC;

-- Payment Method counts
SELECT `Payment Method`, COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Payment Method`
ORDER BY Total_Bookings DESC;

-- null payment methods count (48000)
SELECT COUNT(*) AS Missing_Payment_Method
FROM uber_rides_staging
WHERE `Payment Method` IS NULL;

-- pick up location grouped 
SELECT `Pickup Location`, COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Pickup Location`
ORDER BY Total_Bookings DESC;

-- count the drop off locations grouped 
SELECT `Drop Location`, COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Drop Location`
ORDER BY Total_Bookings DESC;

-- count cancellation reasons by customer
SELECT
    `Reason for cancelling by Customer`,
    COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Reason for cancelling by Customer`
ORDER BY Total_Bookings DESC;

-- count cancellation reasons by drivers
SELECT
    `Driver Cancellation Reason`,
    COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Driver Cancellation Reason`
ORDER BY Total_Bookings DESC;

-- count incomplete ride reasons
SELECT
    `Incomplete Rides Reason`,
    COUNT(*) AS Total_Bookings
FROM uber_rides_staging
GROUP BY `Incomplete Rides Reason`
ORDER BY Total_Bookings DESC;

SELECT COUNT(*) AS Final_Row_Count
FROM uber_rides_staging;

- -------------------------------------------------------------
-- 1. HEADLINE KPIs: HOW BIG IS THE PROBLEM?
-- -------------------------------------------------------------
SELECT
    COUNT(*) AS Total_Bookings,
    SUM(`Booking Status` = 'Completed') AS Completed_Rides,
    ROUND(100 * SUM(`Booking Status` = 'Completed') / COUNT(*), 1) AS Completion_Rate_Pct,
    ROUND(100 * SUM(`Booking Status` <> 'Completed') / COUNT(*), 1) AS Failure_Rate_Pct,
    ROUND(SUM(CASE WHEN `Booking Status` = 'Completed' THEN `Booking Value` END), 0) AS Total_Revenue,
    ROUND(AVG(CASE WHEN `Booking Status` = 'Completed' THEN `Booking Value` END), 1) AS Avg_Fare
FROM uber_rides_staging;

# Vlues: 150000, 93000, 62.0, 38.0, 47260574, 508.2
# Revenue = Completed rides only (Incomplete rides carry a fare but are not earned)

-- -------------------------------------------------------------
-- 2. BOOKING STATUS COUNT INTO PERCENTAGE BREAKDOWN
-- -------------------------------------------------------------
SELECT
    `Booking Status`, COUNT(*) AS Total_Bookings,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS Pct_Of_Total
FROM uber_rides_staging
GROUP BY `Booking Status`
ORDER BY Total_Bookings DESC;
# Values: 62.0 / 18.0 / 7.0 / 7.0 / 6.0
# TOTAL FAILURES: 27000 (dr) + 10500 (no dr) + 10500 (cust) + 9000 (incomp) = 57000
# Driver cancellations = 27000 of 57000 failures (about 47%)
# ((27000/57000)*100 = 47% rounded)


-- -------------------------------------------------------------
-- 3. IS ANY SPECIFIC VEHICLE TYPE THE PROBLEM?
-- -------------------------------------------------------------
SELECT
    `Vehicle Type`,
    COUNT(*) AS Total_Bookings,
    ROUND(100 * AVG(`Booking Status` <> 'Completed'), 1) AS Failure_Rate_Pct
FROM uber_rides_staging
GROUP BY `Vehicle Type`
ORDER BY Failure_Rate_Pct DESC;
# Value explanation: every vehicle between 37.4 and 38.6 (flat = not vehicle-specific)


-- -------------------------------------------------------------
-- 4. DEMAND AND FAILURES BY HOUR OF DAY
-- -------------------------------------------------------------
SELECT
    HOUR(`Time`) AS Ride_Hour,
    COUNT(*) AS Total_Bookings,
    ROUND(100 * AVG(`Booking Status` <> 'Completed'), 1) AS Failure_Rate_Pct,
    ROUND(AVG(`Avg VTAT`), 1) AS Avg_Wait_Min
FROM uber_rides_staging
GROUP BY HOUR(`Time`)
ORDER BY Ride_Hour;
# Values: peak at 18:00 (12397), 17 - 19 HOUR = PEAK HOUR
# second peak at 20:00 (9630), third peak at 10:00 (9577),
# about 1300-1400 per hour at night; failure rate about 36-39 in every hour


-- -------------------------------------------------------------
-- 5. WHY DO RIDES GET CANCELLED?
-- -------------------------------------------------------------
SELECT
    'Customer' AS Cancelled_By,
    `Reason for cancelling by Customer` AS Reason,
    COUNT(*) AS Cancellations
FROM uber_rides_staging
WHERE `Booking Status` = 'Cancelled by Customer'
GROUP BY `Reason for cancelling by Customer`

UNION ALL

SELECT
    'Driver',
    `Driver Cancellation Reason`,
    COUNT(*)
FROM uber_rides_staging
WHERE `Booking Status` = 'Cancelled by Driver'
GROUP BY `Driver Cancellation Reason`
ORDER BY Cancelled_By, Cancellations DESC;

# Customer side: Wrong Address 2362, Change of plans 2353,
# Driver is not moving towards pickup location 2335, Driver asked to cancel 2295, AC is not working 1155
# Expected driver side: Customer related issue 6837, coughing/sick 6751,
# Personal & Car related issues 6726, More than permitted people 6686


-- -------------------------------------------------------------
-- 6. WHICH PICKUP AREAS FAIL MOST? (WATCH LIST)
-- -------------------------------------------------------------
SELECT
    `Pickup Location`,
    COUNT(*) AS Total_Bookings,
    ROUND(100 * AVG(`Booking Status` <> 'Completed'), 1) AS Failure_Rate_Pct,
    ROUND(100 * AVG(`Booking Status` = 'No Driver Found'), 1) AS No_Driver_Pct
FROM uber_rides_staging
GROUP BY `Pickup Location`
HAVING COUNT(*) >= 800
ORDER BY Failure_Rate_Pct DESC
LIMIT 10;
# Values top: Vinobapuri 45.3, Akshardham 43.9, Chhatarpur 41.9, Badshahpur 41.7, Pragati Maidan 41.5
# Each area has only about 800-950 bookings, so treat as a watch list, not proof

-- -------------------------------------------------------------
-- 7. PAYMENT MIX (COMPLETED RIDES ONLY)
-- -------------------------------------------------------------
SELECT
    `Payment Method`, COUNT(*) AS From_Total_Rides,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS Pct_Of_Rides,
    ROUND(SUM(`Booking Value`), 0) AS Revenue
FROM uber_rides_staging
WHERE `Booking Status` = 'Completed'
GROUP BY `Payment Method`
ORDER BY Revenue DESC;
# Values: UPI 41834 (45.0%, 21274591), Cash 23114 (24.9%), Uber Wallet 11206 (12.0%),
# Credit Card 9320 (10.0%), Debit Card 7526 (8.1%)


-- -------------------------------------------------------------
-- 8. IS THE BUSINESS GROWING? (MONTHLY TREND)
-- -------------------------------------------------------------
WITH monthly_cte AS
(
SELECT
    MONTH(`Date`) AS Ride_Month,
    COUNT(*) AS Total_Bookings,
    SUM(`Booking Status` = 'Completed') AS Completed_Rides,
    SUM(CASE WHEN `Booking Status` = 'Completed' THEN `Booking Value` END) AS Revenue
FROM uber_rides_staging
GROUP BY MONTH(`Date`)
)
SELECT
    Ride_Month,
    Total_Bookings,
    Completed_Rides,
    ROUND(100 * Completed_Rides / Total_Bookings, 1) AS Completion_Rate_Pct,
    Revenue,
    ROUND(100 * (Total_Bookings - LAG(Total_Bookings) OVER (ORDER BY Ride_Month))
          / LAG(Total_Bookings) OVER (ORDER BY Ride_Month), 1) AS MoM_Growth_Pct
FROM monthly_cte
ORDER BY Ride_Month;
# Values: lowest Feb (11927), highest Jul (12897), completion about 61.5-62.6 (flat year)


-- -------------------------------------------------------------
-- 9. ESTIMATED REVENUE LOST (ASSUMPTION: AVERAGE FARE)
-- -------------------------------------------------------------
SELECT
    SUM(`Booking Status` IN ('Cancelled by Driver', 'Cancelled by Customer', 'No Driver Found')) AS Lost_Bookings,
    ROUND(AVG(CASE WHEN `Booking Status` = 'Completed' THEN `Booking Value` END), 1) AS Avg_Fare,
    ROUND(SUM(`Booking Status` IN ('Cancelled by Driver', 'Cancelled by Customer', 'No Driver Found'))
          * AVG(CASE WHEN `Booking Status` = 'Completed' THEN `Booking Value` END), 0) AS Est_Lost_Revenue
FROM uber_rides_staging;
# values: 48000, 508.2, about 24.4 million
# This is an ESTIMATE: not every lost booking would have converted


-- -------------------------------------------------------------
-- 10. VIEW FOR POWER BI (HELPER COLUMNS, TABLE STAYS UNTOUCHED)
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW uber_rides_view AS
SELECT
    r.*,
    HOUR(`Time`) AS Ride_Hour,
    DATE_FORMAT(`Date`, '%Y-%m') AS Month_Label,
    CASE
        WHEN `Booking Status` = 'Completed' THEN NULL
        ELSE COALESCE(`Reason for cancelling by Customer`, `Driver Cancellation Reason`,
                      `Incomplete Rides Reason`, 'No driver available')
    END AS Failure_Reason
FROM uber_rides_staging r;

SELECT * FROM uber_rides_view 
LIMIT 10;














































