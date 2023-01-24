-- 1.1. Data type of columns in a table

SELECT
  table_name
  ,column_name
  ,data_type
FROM
  `BC01_TargetDataSet.INFORMATION_SCHEMA.COLUMNS`
;

-- 1.2. Time period for which the data is given

SELECT
  table_name
  ,column_name
  ,data_type
FROM
  `BC01_TargetDataSet.INFORMATION_SCHEMA.COLUMNS`
WHERE
  data_type = 'TIMESTAMP'
;

SELECT
  MIN(order_purchase_timestamp) AS StartDate
  ,MAX(order_purchase_timestamp) AS EndDate
FROM
  `BC01_TargetDataSet.orders`
;

-- 1.3. Cities and States of customers ordered during the given period
/*
SELECT DISTINCT
  customer_state
  ,customer_city
FROM
  `BC01_TargetDataSet.customers`
ORDER BY customer_state
;
*/

SELECT DISTINCT
  C.customer_state
  ,C.customer_city
FROM
  `BC01_TargetDataSet.customers` C
INNER JOIN `BC01_TargetDataSet.orders` O ON C.customer_id = O.customer_id
ORDER BY C.customer_state
;

-- 2.1. Is there a growing trend on e-commerce in Brazil? How can we describe a complete scenario? Can we see some seasonality with peaks at specific months?
--CREATE VIEW BC01_TargetDataSet.MonthWiseOrders AS (
  WITH Temp1 AS (
    SELECT
      order_id
      ,customer_id
      ,DATE(order_purchase_timestamp) DateDetail
    FROM `BC01_TargetDataSet.orders`
    ),
  Temp2 AS (
    SELECT
      COUNT(T1.order_id) Counter
      ,EXTRACT(YEAR FROM T1.DateDetail) Year
      ,EXTRACT(MONTH FROM T1.DateDetail) Month
    FROM Temp1 T1
    GROUP BY EXTRACT(YEAR FROM T1.DateDetail),EXTRACT(MONTH FROM T1.DateDetail)
    )
  SELECT
    *
  FROM
    Temp2 T2
  ORDER BY T2.YEAR,T2.Month
--)
;


SELECT * FROM `BC01_TargetDataSet.MonthWiseOrders`;

-- 2.2. What time do Brazilian customers tend to buy (Dawn, Morning, Afternoon or Night)?
/*
00:00 - 05:59  -- Dawn
06:00 - 11:59  -- Morning
12:00 - 17:59  -- Afternoon
18:00 - 11:59  -- Night
*/

WITH Temp1 AS (
  SELECT
    order_id
    ,customer_id
    ,EXTRACT(TIME FROM order_purchase_timestamp) TimeDetail
  FROM `BC01_TargetDataSet.orders`
  ),
Temp2 AS (
  SELECT
    T1.order_id
    ,T1.customer_id
    ,CASE
      WHEN T1.TimeDetail BETWEEN '00:00:00' AND '05:59:00'
        THEN 'Dusk'
      WHEN T1.TimeDetail BETWEEN '06:00:00' AND '11:59:00'
        THEN 'Morning'
      WHEN T1.TimeDetail BETWEEN '12:00:00' AND '17:59:00'
        THEN 'Afternoon'
      WHEN T1.TimeDetail BETWEEN '18:00:00' AND '23:59:00'
        THEN 'Night'
      END AS TimeSlot
  FROM
    Temp1 T1
  )

SELECT DISTINCT
  COUNT(order_id) OVER(PARTITION BY TimeSlot) CountByTime
  ,TimeSlot
FROM
  Temp2
WHERE TimeSlot IS NOT NULL
;

-- 3.1. Get month on month orders by states

WITH Temp1 AS (
  SELECT
    O.order_id
    ,O.customer_id
    ,DATE(O.order_purchase_timestamp) DateDetail
    ,C.customer_state
  FROM `BC01_TargetDataSet.orders` O
  INNER JOIN `BC01_TargetDataSet.customers` C ON O.customer_id = C.customer_id
  ),
Temp2 AS (
  SELECT
    COUNT(T1.order_id) CountByMonthByState
    ,EXTRACT(YEAR FROM T1.DateDetail) Year
    ,EXTRACT(MONTH FROM T1.DateDetail) Month
    ,T1.customer_state
  FROM Temp1 T1
  GROUP BY EXTRACT(YEAR FROM T1.DateDetail),EXTRACT(MONTH FROM T1.DateDetail),T1.customer_state
  )
SELECT
  *
FROM
  Temp2 T2
ORDER BY T2.Year,T2.Month,T2.customer_state
;

-- 3.2. Distribution of customers across the states in Brazil

SELECT DISTINCT
  customer_state
  ,COUNT(customer_id) OVER(PARTITION BY customer_state) CountByState
FROM
  `BC01_TargetDataSet.customers`
ORDER BY CountByState DESC
;

-- 4.1 Get % increase in cost of orders from 2017 to 2018 (include months between Jan to Aug only) - You can use “payment_value” column in payments table

-- 4.1
/*
Steps to use straight-line percent change
Use growth rate formula: It is necessary to know the original value and divide the absolute change with it. The formula is Growth rate = Absolute change / Previous value

Calculate growth rate with these steps:
1. Calculate the absolute change: Knowing the original value and the new value is essential for finding the absolute change. The formula is Absolute change = New value - Previous value
2. Use the original value for dividing the absolute change: You can get growth rate by dividing the absolute change by the previous value. The formula is Growth rate = Absolute change / Previous value
3. Find percent of change: To get the percent of change, you can use this formula the formula of Percent of change = Growth rate x 100
*/

WITH Temp1 AS (
  SELECT
    P.order_id
    ,P.payment_value
    ,EXTRACT(MONTH FROM O.order_purchase_timestamp) Month
    ,EXTRACT(YEAR FROM O.order_purchase_timestamp) Year
  FROM
    `BC01_TargetDataSet.payments` P
  INNER JOIN `BC01_TargetDataSet.orders` O ON P.order_id = O.order_id
  ORDER BY Year,Month
),
Temp2 AS (
  SELECT DISTINCT
    Year
    ,Month
    ,ROUND(SUM(payment_value) OVER(PARTITION BY Year,Month ORDER BY Year,Month),2) CurrentMonthSale
  FROM Temp1
),
Temp3 AS (
  SELECT
    Year
    ,Month
    ,CurrentMonthSale
    ,LAG(CurrentMonthSale,1) OVER(ORDER BY Year,Month) PreviousMonthSale
    ,ROUND(CurrentMonthSale - LAG(CurrentMonthSale,1) OVER(ORDER BY Year,Month),2) AbsChange
  FROM
    Temp2
  ORDER BY Year,Month
)
SELECT
  Year
  ,Month
  ,CurrentMonthSale
  ,PreviousMonthSale
  ,AbsChange
  ,ROUND(((AbsChange / PreviousMonthSale) * 100),2) PercentageChange
FROM
  Temp3
WHERE
  (Year BETWEEN 2017 AND 2018)
AND
  (Month BETWEEN 1 AND 8)
;

-- 4.2 Mean & Sum of price and freight value by customer state

WITH Temp1 AS (
  SELECT DISTINCT
    ROUND(SUM(OI.price) OVER(PARTITION BY C.customer_state),2) TotalPriceByState
    ,ROUND(AVG(OI.price) OVER(PARTITION BY C.customer_state),2) AvgPriceByState
    ,ROUND(SUM(OI.freight_value) OVER(PARTITION BY C.customer_state),2) TotalFreightByState
    ,ROUND(AVG(OI.freight_value) OVER(PARTITION BY C.customer_state),2) AvgFreightByState
    ,C.customer_state
  FROM
    `BC01_TargetDataSet.order_items` OI
  INNER JOIN `BC01_TargetDataSet.orders` O on OI.order_id = O.order_id
  INNER JOIN `BC01_TargetDataSet.customers` C on O.customer_id = C.customer_id
  ORDER BY C.customer_state
)
SELECT
  TotalPriceByState
  ,AvgPriceByState
  ,TotalFreightByState
  ,AvgFreightByState
  ,ROUND((TotalPriceByState + TotalFreightByState),2) TotalCostByState
  ,ROUND((AvgPriceByState + AvgFreightByState),2) AvgCostByState
  ,customer_state
FROM
  Temp1
ORDER BY TotalPriceByState DESC,AvgFreightByState ASC
;

-- 5.1. Calculate days between purchasing, delivering and estimated delivery

SELECT DISTINCT
  order_id
  ,DATE_DIFF(order_delivered_customer_date,order_purchase_timestamp,DAY) DaysToDeliver
  ,DATE_DIFF(order_estimated_delivery_date,order_purchase_timestamp,DAY) DaysEstimated
FROM
  `BC01_TargetDataSet.orders`
WHERE
  order_status = 'delivered'
;

-- 5.2. Find time_to_delivery & diff_estimated_delivery. Formula for the same given below:
/*
time_to_delivery = order_purchase_timestamp-order_delivered_customer_date
diff_estimated_delivery = order_estimated_delivery_date-order_delivered_customer_date
*/

SELECT DISTINCT
  order_id
  ,DATE_DIFF(order_delivered_customer_date,order_purchase_timestamp,DAY) time_to_delivery
  ,DATE_DIFF(order_estimated_delivery_date,order_delivered_customer_date,DAY) diff_estimated_delivery
FROM
  `BC01_TargetDataSet.orders`
WHERE
  order_status = 'delivered'
;

-- 5.3. Group data by state, take mean of freight_value, time_to_delivery, diff_estimated_delivery
WITH Temp1 AS (
  SELECT DISTINCT
    OI.freight_value
    ,C.customer_state
    ,DATE_DIFF(O.order_delivered_customer_date,O.order_purchase_timestamp,DAY) time_to_delivery
    ,DATE_DIFF(O.order_estimated_delivery_date,O.order_delivered_customer_date,DAY) diff_estimated_delivery
  FROM
    `BC01_TargetDataSet.orders` O
  INNER JOIN `BC01_TargetDataSet.order_items` OI ON O.order_id = OI.order_id
  INNER JOIN `BC01_TargetDataSet.customers` C ON O.customer_id = C.customer_id
  WHERE
    order_status = 'delivered'
)
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(freight_value) OVER(PARTITION BY customer_state),2) mean_freight_value_by_state
  ,ROUND(AVG(time_to_delivery) OVER(PARTITION BY customer_state),2) mean_time_to_delivery_by_state
  ,ROUND(AVG(diff_estimated_delivery) OVER(PARTITION BY customer_state),2) mean_diff_estimated_delivery_by_state
FROM
  Temp1
ORDER BY mean_diff_estimated_delivery_by_state DESC
;

-- 5.4. Sort the data to get the following:
--   a. Top 5 states with highest/lowest average freight value - sort in desc/asc limit 5
--   b. Top 5 states with highest/lowest average time to delivery
--   c. Top 5 states where delivery is really fast/ not so fast compared to estimated date
/*
CREATE VIEW `BC01_TargetDataSet.FreightAndDeliveryInfo` AS (
  SELECT DISTINCT
    OI.freight_value
    ,C.customer_state
    ,DATE_DIFF(O.order_delivered_customer_date,O.order_purchase_timestamp,DAY) time_to_delivery
    ,DATE_DIFF(O.order_estimated_delivery_date,O.order_delivered_customer_date,DAY) diff_estimated_delivery
  FROM
    `BC01_TargetDataSet.orders` O
  INNER JOIN `BC01_TargetDataSet.order_items` OI ON O.order_id = OI.order_id
  INNER JOIN `BC01_TargetDataSet.customers` C ON O.customer_id = C.customer_id
  WHERE
    order_status = 'delivered'
);
*/
-- a.i. Top 5 states with highest average freight value - sort in desc/asc limit 5
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(freight_value) OVER(PARTITION BY customer_state),2) mean_freight_value_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_freight_value_by_state DESC
LIMIT 5
;

-- a.ii. Top 5 states with lowest average freight value - sort in desc/asc limit 5
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(freight_value) OVER(PARTITION BY customer_state),2) mean_freight_value_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_freight_value_by_state ASC
LIMIT 5
;

-- b.i. Top 5 states with highest average time to delivery
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(time_to_delivery) OVER(PARTITION BY customer_state),2) mean_time_to_delivery_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_time_to_delivery_by_state DESC
LIMIT 5
;

-- b.ii. Top 5 states with lowest average time to delivery
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(time_to_delivery) OVER(PARTITION BY customer_state),2) mean_time_to_delivery_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_time_to_delivery_by_state ASC
LIMIT 5
;

-- c.i. Top 5 states where delivery is really fast compared to estimated date
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(diff_estimated_delivery) OVER(PARTITION BY customer_state),2) mean_diff_estimated_delivery_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_diff_estimated_delivery_by_state ASC
LIMIT 5
;

-- c.ii. Top 5 states where delivery is not so fast compared to estimated date
SELECT DISTINCT
  customer_state
  ,ROUND(AVG(diff_estimated_delivery) OVER(PARTITION BY customer_state),2) mean_diff_estimated_delivery_by_state
FROM
  `BC01_TargetDataSet.FreightAndDeliveryInfo`
ORDER BY mean_diff_estimated_delivery_by_state DESC
LIMIT 5
;


-- 6. Payment type analysis: 
--   1. Month over Month count of orders for different payment types
--   2. Count of orders based on the no. of payment installments
/*
CREATE VIEW `BC01_TargetDataSet.PaymentAnalysis` AS (
  SELECT DISTINCT
    P.order_id
    ,P.payment_type
    ,P.payment_installments
    ,EXTRACT(YEAR FROM O.order_purchase_timestamp) order_year
    ,EXTRACT(MONTH FROM O.order_purchase_timestamp) order_month
  FROM
    `BC01_TargetDataSet.payments` P
  INNER JOIN `BC01_TargetDataSet.orders` O ON P.order_id = O.order_id
  ORDER BY order_year,order_month
)
;
*/

-- 6.1. Month over Month count of orders for different payment types

SELECT DISTINCT
  --COUNT(order_id) OVER(PARTITION BY payment_type,order_year,order_month) order_count
  COUNT(order_id) OVER(PARTITION BY payment_type) order_count
  ,payment_type
--  ,order_year
--  ,order_month
FROM
  `BC01_TargetDataSet.PaymentAnalysis`
ORDER BY payment_type ASC,order_count DESC
;

-- 6.2. Count of orders based on the no. of payment installments

SELECT DISTINCT
  --COUNT(order_id) OVER(PARTITION BY payment_installments,order_year,order_month) order_count
  COUNT(order_id) OVER(PARTITION BY payment_installments) order_count
  ,payment_installments
--  ,order_year
--  ,order_month
FROM
  `BC01_TargetDataSet.PaymentAnalysis`
ORDER BY payment_installments DESC, order_count ASC
;