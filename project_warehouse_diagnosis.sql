WITH Order_Base_Metrics AS (
    SELECT 
        `Order ID`,
        `Plant Code`,
        `Unit quantity`,
        `Ship Late Day count`,
        CASE WHEN `Ship Late Day count` > 0 THEN 1 ELSE 0 END AS Is_Late_Delivery
    FROM OrderList
),
Warehouse_Aggregates AS (
    SELECT 
        ob.`Plant Code`,
        COUNT(DISTINCT ob.`Order ID`) AS Total_Orders_Processed,
        SUM(ob.`Unit quantity`) AS Total_Units_Handled,
        SUM(ob.Is_Late_Delivery) AS Total_Late_Orders,
        CAST(SUM(ob.Is_Late_Delivery) AS REAL) / COUNT(ob.`Order ID`) AS Late_Delivery_SLA_Ratio
    FROM Order_Base_Metrics ob
    GROUP BY ob.`Plant Code`
),
Network_Financials AS (
    SELECT 
        wa.`Plant Code`,
        wa.Total_Orders_Processed,
        wa.Total_Units_Handled,
        wa.Total_Late_Orders,
        ROUND(wa.Late_Delivery_SLA_Ratio * 100, 2) AS SLA_Failure_Rate_Pct,
        cap.`Daily Capacity`,
        ROUND(wa.Total_Units_Handled * cost.`Cost/unit`, 2) AS Gross_Operating_Cost
    FROM Warehouse_Aggregates wa
    JOIN WhCosts cost ON wa.`Plant Code` = cost.`WH`
    JOIN WhCapacities cap ON wa.`Plant Code` = cap.`Plant ID`
)
SELECT 
    `Plant Code`,
    Total_Orders_Processed,
    Total_Units_Handled,
    Gross_Operating_Cost,
    `Daily Capacity`,
    SLA_Failure_Rate_Pct,
    ROUND((Total_Units_Handled / (`Daily Capacity` * 30.0)) * 100, 2) AS Monthly_Capacity_Utilization_Pct,
    DENSE_RANK() OVER (ORDER BY Gross_Operating_Cost DESC) AS Financial_Cost_Rank,
    ROUND((Gross_Operating_Cost / SUM(Gross_Operating_Cost) OVER ()) * 100, 2) AS Network_Spend_Contribution_Pct
FROM Network_Financials
ORDER BY Gross_Operating_Cost DESC;