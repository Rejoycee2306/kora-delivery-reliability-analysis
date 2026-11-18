-- quick validation checks---------------
SELECT COUNT(*) FROM branches;
SELECT COUNT(*) FROM customers;
SELECT COUNT(DISTINCT customer_id) FROM customers;
SELECT COUNT(*) FROM deliveries;
SELECT COUNT(DISTINCT delivery_id) FROM deliveries;
SELECT COUNT(*) FROM order_lines;
SELECT COUNT(order_line_id) FROM order_lines;
SELECT COUNT(*) FROM orders;
SELECT COUNT(order_id) FROM orders;
SELECT COUNT(*) FROM products;
SELECT COUNT(product_id) FROM products;
SELECT COUNT(*) FROM regions;
SELECT COUNT(region_id) FROM regions;
SELECT SUM(shipping_cost_ngn) FROM deliveries;
SELECT SUM(gross_order_value_ngn) FROM order_lines;
SELECT SUM(net_order_value_ngn) FROM order_lines;
SELECT SUM(discount_value_ngn) FROM order_lines;
-- -------------------------------------------data cleaning----------------
-- Check for nulls and blanks
SELECT status,
	COUNT(*) AS status_count,
    SUM(CASE WHEN delivered_date IS NULL THEN 1 ELSE 0 END) AS missing_delivered_date,
    SUM(CASE WHEN promised_delivery_date IS NULL THEN 1 ELSE 0 END) AS missing_promise_date,
    SUM(CASE WHEN shipping_cost_ngn = '' THEN 1 ELSE 0 END) AS missing_cost
FROM deliveries
GROUP BY status; -- non delivered statuses had missing delivery date, meaning the parcels never arrived, hasn't arrived, or hasn't been sent out yet.

SELECT status, COUNT(*) AS blank_cost
FROM deliveries
WHERE shipping_cost_ngn = '' -- they are set to zero instead of blanks
GROUP BY status;

SELECT * FROM deliveries
WHERE shipping_cost_ngn = ''; -- they're all for scheduled parcels.

-- duplicates
SELECT * FROM(
	SELECT *,
		ROW_NUMBER() OVER(PARTITION BY order_id, branch_id, carrier, promised_delivery_date, dispatch_date,
				delivered_date, status, shipping_cost_ngn, exception_reason ORDER BY delivery_id) as rn
	FROM deliveries
)t WHERE rn > 1;

SELECT * FROM(
	SELECT *,
		ROW_NUMBER() OVER(PARTITION BY order_date, branch_id, customer_id, promised_delivery_date, channel,
				status, cancellation_reason ORDER BY order_id) as rn
	FROM orders
)t WHERE rn > 1;

WITH order_summary AS (
	SELECT o.order_id, o.order_date, o.branch_id, o.customer_id, o.promised_delivery_date, o.channel, o.status, 
		COUNT(ol.order_line_id) AS line_count,
		SUM(ol.net_order_value_ngn) AS order_value
    FROM orders o 
    JOIN order_lines ol 
		USING (order_id)
	GROUP BY o.order_id, o.order_date, o.branch_id, o.customer_id, o.promised_delivery_date, o.channel, o.status
)
SELECT *
FROM (
	SELECT *,
		ROW_NUMBER() OVER(PARTITION BY order_date, branch_id, customer_id, promised_delivery_date, channel,
				status, line_count, order_value ORDER BY order_id) as rn
	FROM order_summary
)t WHERE rn > 1; -- zero rows beacuse 2 real orders rarely have the same naira value.


-- dates check 
SELECT MIN(order_date), MAX(order_date) FROM orders;
SELECT MIN(promised_delivery_date), MAX(promised_delivery_date) FROM deliveries;
SELECT MIN(delivered_date), MAX(delivered_date) FROM deliveries;
SELECT * FROM deliveries
WHERE status = 'Delivered' AND dispatch_date > delivered_date; -- none 

-- To understand Delivery time
SELECT d.delivery_id, d.order_id, o.order_date, d.dispatch_date, 
		d.promised_delivery_date, d.delivered_date, d.exception_reason, o.status as orderStatus, d.status as dstatus,
		DATEDIFF(d.dispatch_date, o.order_date) AS branch_delays_days, -- time before parcel left
		DATEDIFF(d.delivered_date, d.dispatch_date) AS transit_days, -- time on the road
		DATEDIFF(d.promised_delivery_date, d.dispatch_date) AS days_promised,
		DATEDIFF(d.delivered_date, d.promised_delivery_date) AS days_late
FROM deliveries d 
JOIN orders o 
USING (order_id)
WHERE d.status = 'Delivered';

-- exception reason for deliveries
SELECT 
	SUM(delivered_date > promised_delivery_date AND exception_reason IS NULL) AS late_with_no_reason, -- dirty data
    SUM(delivered_date > promised_delivery_date AND exception_reason IS NOT NULL) AS late_with_reason, -- good
    SUM(delivered_date <= promised_delivery_date AND exception_reason IS NULL) AS early_with_no_reason, -- good
    SUM(delivered_date <= promised_delivery_date AND exception_reason IS NOT NULL) AS early_with_reason -- dirty data
FROM deliveries
WHERE status = 'Delivered';
		
SELECT DISTINCT exception_reason FROM deliveries;

-- Orders status and delivery status
SELECT o.status AS orderStatus, 
		d.status AS parcel_status, 
		COUNT(*) AS parcels
FROM deliveries d 
JOIN orders o 
	USING (order_id)
GROUP BY o.status, d.status
ORDER BY o.status, d.status;

SELECT o.status,
	COUNT(delivery_id) AS parcels,
    COUNT(order_id) AS orders
FROM orders o 
LEFT JOIN deliveries d 
	USING (order_id)
GROUP BY o.status; 

SELECT DISTINCT status FROM orders;
SELECT DISTINCT status FROM deliveries;
SELECT COUNT(DISTINCT order_id) FROM orders;
SELECT COUNT(DISTINCT order_id) FROM deliveries;
SELECT DISTINCT exception_reason FROM deliveries;

-- Questions answered
-- 1. Analyze Delivered, Failed, In transit and Scheduled consignments. 
-- The idea is to keep failed and unresolved work visible.
SELECT status, 
	COUNT(DISTINCT order_id) AS Order_count,
    COUNT(*) AS no_of_parcels,
    ROUND(SUM(shipping_cost_ngn), 2) AS shipping_cost,
    AVG(DATEDIFF(delivered_date, dispatch_date)) AS avg_transit_days,
    AVG(DATEDIFF(promised_delivery_date, dispatch_date)) AS avg_days_promised,
    AVG(DATEDIFF(delivered_date, promised_delivery_date)) AS avg_days_late,
    AVG(CASE WHEN status IN ('In transit', 'Scheduled') THEN DATEDIFF('2025-12-31', promised_delivery_date) END) 
			AS avg_days_late_Unresolved
FROM deliveries
GROUP BY status; 

SELECT 
	COUNT(DISTINCT order_id) AS Order_count,
    COUNT(*) AS no_of_parcels,
    ROUND(SUM(shipping_cost_ngn), 2) AS shipping_cost,
    AVG(DATEDIFF(delivered_date, dispatch_date)) AS avg_transit_days,
    AVG(DATEDIFF(promised_delivery_date, dispatch_date)) AS avg_days_promised,
    AVG(DATEDIFF(delivered_date, promised_delivery_date)) AS avg_days_late,
    AVG(CASE WHEN status IN ('In transit', 'Scheduled') THEN DATEDIFF('2025-12-31', promised_delivery_date) END) 
			AS avg_days_late_Unresolved
FROM deliveries;
 
SELECT *
FROM deliveries
WHERE status = 'Failed'; -- identify which branches/carriers though not their fault cos customers are unavailable
-- all failed deliveries were dispatched but were not delivered (null delivery date) mostly bcos customers were unavailable (a few were due to capacity delay?  

-- 2. Calculate on-time delivery rate among Delivered consignments, overall and by branch, carrier and any other dimension you deem important.
SELECT 
	SUM(delivered_date <= promised_delivery_date) AS on_time_deliveries,
    COUNT(*) as no_of_deliveries,
    ROUND(SUM(delivered_date <= promised_delivery_date) / COUNT(*) * 100, 2) AS On_time_delivery_rate
FROM deliveries 
WHERE status = 'Delivered';

SELECT carrier,
	SUM(delivered_date <= promised_delivery_date) AS on_time_deliveries,
    COUNT(*) as no_of_deliveries,
    ROUND(SUM(delivered_date <= promised_delivery_date) / COUNT(*) * 100, 2) AS On_time_delivery_rate
FROM deliveries 
WHERE status = 'Delivered'
GROUP BY carrier;

SELECT branch_id,
	SUM(delivered_date <= promised_delivery_date) AS on_time_deliveries,
    COUNT(*) as no_of_deliveries,
    ROUND(SUM(delivered_date <= promised_delivery_date) / COUNT(*) * 100, 2) AS On_time_delivery_rate
FROM deliveries 
WHERE status = 'Delivered'
GROUP BY branch_id;

SELECT DATE_FORMAT(promised_delivery_date, '%Y-%m') AS Month,
	SUM(delivered_date <= promised_delivery_date) AS on_time_deliveries,
    COUNT(*) as no_of_deliveries,
    ROUND(SUM(delivered_date <= promised_delivery_date) / COUNT(*) * 100, 2) AS On_time_delivery_rate
FROM deliveries 
WHERE status = 'Delivered'
GROUP BY Month;

-- 3. Among unresolved consignments, which were already overdue before the data snapshot was taken?
-- snapshot is 31 Dec 2025

SELECT 
	SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) AS overdue_consignments_before_snapshot,
    SUM(CASE WHEN promised_delivery_date = '2025-12-31' THEN 1 ELSE 0 END) AS due_on_snapshot_day,
	SUM(CASE WHEN promised_delivery_date > '2025-12-31' THEN 1 ELSE 0 END) AS still_has_time,
    COUNT(*) AS total_unresolved_consignments,
    ROUND(SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_overdue
FROM deliveries
WHERE status IN ('In transit', 'Scheduled'); 

SELECT status,
	SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) AS overdue_consignments_before_snapshot,
    COUNT(*) AS total_unresolved_consignments
FROM deliveries
WHERE status IN ('In transit', 'Scheduled')
GROUP BY status; -- parcels that are not yet delivered and whose promised delivery date is before 31 dec 2025

SELECT branch_id, carrier,
	SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) AS overdue_consignments_before_snapshot,
    COUNT(*) AS total_unresolved_consignments,
    ROUND(SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_overdue
FROM deliveries
WHERE status IN ('In transit', 'Scheduled')
GROUP BY branch_id, carrier
ORDER BY branch_id;

SELECT branch_id,
	SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) AS overdue_consignments_before_snapshot,
    COUNT(*) AS total_unresolved_consignments,
    ROUND(SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_overdue
FROM deliveries
WHERE status IN ('In transit', 'Scheduled')
GROUP BY branch_id
ORDER BY branch_id;

SELECT carrier,
	SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) AS overdue_consignments_before_snapshot,
    COUNT(*) AS total_unresolved_consignments,
    ROUND(SUM(CASE WHEN promised_delivery_date < '2025-12-31' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_overdue
FROM deliveries
WHERE status IN ('In transit', 'Scheduled')
GROUP BY carrier
ORDER BY overdue_consignments_before_snapshot DESC;

-- 4. Compare recorded shipping cost by branch and status. 
-- Explain why total cost and cost per delivered consignment answer different questions.
SELECT 
	SUM(shipping_cost_ngn) AS total_shipping_cost,
    COUNT(*) AS total_consignments,
    ROUND(SUM(shipping_cost_ngn) / COUNT(NULLIF(shipping_cost_ngn, 0)), 2) AS cost_per_consignment, -- to remove scheduled zero cost
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_consignments,
    ROUND(SUM(shipping_cost_ngn) / SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END), 2) AS cost_per_delivered_consignment
FROM deliveries;

SELECT status,
	SUM(shipping_cost_ngn) AS total_shipping_cost,
    COUNT(*) AS total_consignments,
    ROUND(SUM(shipping_cost_ngn) / COUNT(NULLIF(shipping_cost_ngn, 0)), 2) AS cost_per_consignment,
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_consignments
FROM deliveries
GROUP BY status;

SELECT branch_id,
	SUM(shipping_cost_ngn) AS total_shipping_cost,
    COUNT(*) AS total_consignments,
    ROUND(SUM(shipping_cost_ngn) / COUNT(NULLIF(shipping_cost_ngn, 0)), 2) AS cost_per_consignment,
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_consignments,
    ROUND(SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*) *100, 2) AS delivered_pct,
    ROUND(SUM(shipping_cost_ngn) / SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END), 2) AS cost_per_delivered_consignment
FROM deliveries
GROUP BY branch_id;

SELECT branch_id, status,
	SUM(shipping_cost_ngn) AS total_shipping_cost,
    COUNT(*) AS total_consignments,
    ROUND(SUM(shipping_cost_ngn) / COUNT(NULLIF(shipping_cost_ngn, 0)), 2) AS cost_per_consignment,
    SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_consignments,
    ROUND(SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*) *100, 2) AS delivered_pct,
    ROUND(SUM(shipping_cost_ngn) / SUM(CASE WHEN status = 'Delivered' THEN 1 ELSE 0 END), 2) AS cost_per_delivered_consignment
FROM deliveries
GROUP BY branch_id, status
ORDER BY branch_id;

-- 5. Find the ten latest Delivered consignments by “days late”.
SELECT *,
	DATEDIFF(delivered_date, promised_delivery_date) AS days_late,
    DATEDIFF(promised_delivery_date, dispatch_date) AS days_dispatched_after_promise
FROM deliveries
WHERE status = 'Delivered'
ORDER BY days_late DESC
LIMIT 10; -- branch 3 seems like the likelier cause of the delay cos all 10 connects to it theough 3 carriers (In house 8, Northline and Swift 1 each)

SELECT branch_id, exception_reason,
	COUNT(*) AS total_consignments,
    ROUND(AVG(DATEDIFF(promised_delivery_date, dispatch_date)), 1) AS avg_days_promised,
	ROUND(AVG(DATEDIFF(delivered_date, dispatch_date)), 1) AS avg_transit_days
FROM deliveries
WHERE status = 'Delivered' AND exception_reason = 'Capacity delay'
GROUP BY branch_id, exception_reason;

