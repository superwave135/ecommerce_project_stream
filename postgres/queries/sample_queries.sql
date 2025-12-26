-- Sample Analytical Queries for E-commerce Streaming Analytics
-- These queries demonstrate various analytics use cases

SET search_path TO ecommerce, public;

-- ============================================
-- 1. Revenue Attribution by Traffic Source
-- ============================================
-- Question: Which traffic sources generate the most revenue?

SELECT 
    traffic_source,
    COUNT(*) AS total_conversions,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_order_value,
    ROUND(SUM(revenue) * 100.0 / SUM(SUM(revenue)) OVER (), 2) AS revenue_percentage
FROM attributed_checkouts
GROUP BY traffic_source
ORDER BY total_revenue DESC;


-- ============================================
-- 2. Time to Purchase Analysis
-- ============================================
-- Question: How long does it take users to convert after first click?

SELECT 
    CASE 
        WHEN attribution_window_seconds < 300 THEN '< 5 minutes'
        WHEN attribution_window_seconds < 900 THEN '5-15 minutes'
        WHEN attribution_window_seconds < 1800 THEN '15-30 minutes'
        WHEN attribution_window_seconds < 3600 THEN '30-60 minutes'
        ELSE '> 1 hour'
    END AS time_bucket,
    COUNT(*) AS conversion_count,
    ROUND(AVG(revenue), 2) AS avg_revenue
FROM attributed_checkouts
GROUP BY time_bucket
ORDER BY 
    CASE time_bucket
        WHEN '< 5 minutes' THEN 1
        WHEN '5-15 minutes' THEN 2
        WHEN '15-30 minutes' THEN 3
        WHEN '30-60 minutes' THEN 4
        ELSE 5
    END;


-- ============================================
-- 3. Product Category Performance
-- ============================================
-- Question: Which product categories drive the most conversions?

SELECT 
    attributed_category,
    COUNT(*) AS conversion_count,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_order_value,
    COUNT(DISTINCT user_id) AS unique_customers
FROM attributed_checkouts
GROUP BY attributed_category
ORDER BY total_revenue DESC
LIMIT 10;


-- ============================================
-- 4. Device Type Conversion Analysis
-- ============================================
-- Question: How do conversion rates and revenue differ by device?

WITH device_stats AS (
    SELECT 
        device_type,
        COUNT(*) AS conversions,
        SUM(revenue) AS total_revenue,
        AVG(revenue) AS avg_revenue,
        AVG(attribution_window_seconds) / 60.0 AS avg_minutes_to_purchase
    FROM attributed_checkouts
    GROUP BY device_type
)
SELECT 
    device_type,
    conversions,
    ROUND(total_revenue::NUMERIC, 2) AS total_revenue,
    ROUND(avg_revenue::NUMERIC, 2) AS avg_order_value,
    ROUND(avg_minutes_to_purchase::NUMERIC, 2) AS avg_minutes_to_purchase
FROM device_stats
ORDER BY total_revenue DESC;


-- ============================================
-- 5. Hourly Revenue Trends
-- ============================================
-- Question: What are the peak conversion hours?

SELECT 
    DATE_TRUNC('hour', checkout_timestamp) AS hour,
    COUNT(*) AS conversions,
    SUM(revenue) AS hourly_revenue,
    AVG(revenue) AS avg_order_value
FROM attributed_checkouts
WHERE checkout_timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', checkout_timestamp)
ORDER BY hour DESC;


-- ============================================
-- 6. Customer Segment Performance
-- ============================================
-- Question: How do different customer segments perform?

SELECT 
    u.customer_segment,
    COUNT(DISTINCT a.checkout_id) AS total_orders,
    COUNT(DISTINCT a.user_id) AS active_customers,
    SUM(a.revenue) AS total_revenue,
    AVG(a.revenue) AS avg_order_value,
    SUM(a.revenue) / COUNT(DISTINCT a.user_id) AS revenue_per_customer
FROM attributed_checkouts a
JOIN users u ON a.user_id = u.user_id
GROUP BY u.customer_segment
ORDER BY total_revenue DESC;


-- ============================================
-- 7. Top Converting Products
-- ============================================
-- Question: Which products generate the most conversions?

SELECT 
    attributed_product_id,
    attributed_product_name,
    attributed_category,
    COUNT(*) AS conversion_count,
    SUM(revenue) AS total_attributed_revenue
FROM attributed_checkouts
GROUP BY attributed_product_id, attributed_product_name, attributed_category
ORDER BY conversion_count DESC
LIMIT 20;


-- ============================================
-- 8. Click-to-Conversion Funnel
-- ============================================
-- Question: What's the conversion rate from clicks to checkouts?

WITH click_counts AS (
    SELECT COUNT(DISTINCT event_id) AS total_clicks
    FROM raw_clicks
    WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
),
checkout_counts AS (
    SELECT COUNT(DISTINCT event_id) AS total_checkouts
    FROM raw_checkouts
    WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
)
SELECT 
    cc.total_clicks,
    ck.total_checkouts,
    ROUND((ck.total_checkouts::NUMERIC / NULLIF(cc.total_clicks, 0) * 100), 2) AS conversion_rate
FROM click_counts cc, checkout_counts ck;


-- ============================================
-- 9. Multi-Touch Attribution Analysis
-- ============================================
-- Question: How many clicks occurred before each checkout?

WITH click_counts_per_checkout AS (
    SELECT 
        checkout_id,
        user_id,
        COUNT(*) AS total_clicks_in_window
    FROM (
        SELECT 
            co.event_id AS checkout_id,
            co.user_id,
            cl.event_id AS click_id
        FROM raw_checkouts co
        JOIN raw_clicks cl 
            ON co.user_id = cl.user_id
            AND cl.event_timestamp <= co.event_timestamp
            AND cl.event_timestamp >= co.event_timestamp - INTERVAL '1 hour'
    ) clicks_before_checkout
    GROUP BY checkout_id, user_id
)
SELECT 
    CASE 
        WHEN total_clicks_in_window = 1 THEN '1 click'
        WHEN total_clicks_in_window BETWEEN 2 AND 3 THEN '2-3 clicks'
        WHEN total_clicks_in_window BETWEEN 4 AND 6 THEN '4-6 clicks'
        ELSE '7+ clicks'
    END AS click_bucket,
    COUNT(*) AS checkout_count
FROM click_counts_per_checkout
GROUP BY click_bucket
ORDER BY 
    CASE click_bucket
        WHEN '1 click' THEN 1
        WHEN '2-3 clicks' THEN 2
        WHEN '4-6 clicks' THEN 3
        ELSE 4
    END;


-- ============================================
-- 10. Real-time Streaming Metrics
-- ============================================
-- Question: What's the current streaming pipeline health?

SELECT 
    'Clicks (Last Hour)' AS metric,
    COUNT(*) AS value
FROM raw_clicks
WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Checkouts (Last Hour)' AS metric,
    COUNT(*) AS value
FROM raw_checkouts
WHERE event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Attributed Checkouts (Last Hour)' AS metric,
    COUNT(*) AS value
FROM attributed_checkouts
WHERE checkout_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour'

UNION ALL

SELECT 
    'Total Revenue (Last Hour)' AS metric,
    ROUND(COALESCE(SUM(revenue), 0)::NUMERIC, 2) AS value
FROM attributed_checkouts
WHERE checkout_timestamp >= CURRENT_TIMESTAMP - INTERVAL '1 hour';
