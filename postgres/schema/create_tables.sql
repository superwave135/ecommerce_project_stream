-- E-commerce Streaming Analytics Database Schema
-- Creates tables for raw events and attributed checkouts

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS ecommerce;

-- Set search path
SET search_path TO ecommerce, public;

-- ============================================
-- Table: raw_clicks
-- Stores all click events from the stream
-- ============================================
DROP TABLE IF EXISTS raw_clicks CASCADE;

CREATE TABLE raw_clicks (
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(100) UNIQUE NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    product_category VARCHAR(50),
    referrer VARCHAR(50),
    device_type VARCHAR(20),
    event_timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for query optimization
    INDEX idx_raw_clicks_user_id (user_id),
    INDEX idx_raw_clicks_event_timestamp (event_timestamp),
    INDEX idx_raw_clicks_product_id (product_id),
    INDEX idx_raw_clicks_referrer (referrer)
);

-- Add table comment
COMMENT ON TABLE raw_clicks IS 'Stores all click events from Kinesis stream';

-- ============================================
-- Table: raw_checkouts
-- Stores all checkout events from the stream
-- ============================================
DROP TABLE IF EXISTS raw_checkouts CASCADE;

CREATE TABLE raw_checkouts (
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(100) UNIQUE NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50),
    event_timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for query optimization
    INDEX idx_raw_checkouts_user_id (user_id),
    INDEX idx_raw_checkouts_event_timestamp (event_timestamp),
    INDEX idx_raw_checkouts_total_amount (total_amount)
);

-- Add table comment
COMMENT ON TABLE raw_checkouts IS 'Stores all checkout events from Kinesis stream';

-- ============================================
-- Table: attributed_checkouts
-- Stores checkouts with first-click attribution
-- ============================================
DROP TABLE IF EXISTS attributed_checkouts CASCADE;

CREATE TABLE attributed_checkouts (
    id SERIAL PRIMARY KEY,
    checkout_id VARCHAR(100) UNIQUE NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    checkout_timestamp TIMESTAMP NOT NULL,
    attributed_click_id VARCHAR(100) NOT NULL,
    attributed_product_id VARCHAR(50) NOT NULL,
    attributed_product_name VARCHAR(200),
    attributed_category VARCHAR(50),
    traffic_source VARCHAR(50),
    device_type VARCHAR(20),
    first_click_timestamp TIMESTAMP NOT NULL,
    revenue DECIMAL(10, 2) NOT NULL,
    attribution_window_seconds INTEGER,
    processed_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for query optimization
    INDEX idx_attr_user_id (user_id),
    INDEX idx_attr_checkout_timestamp (checkout_timestamp),
    INDEX idx_attr_traffic_source (traffic_source),
    INDEX idx_attr_category (attributed_category),
    INDEX idx_attr_revenue (revenue),
    INDEX idx_attr_processed_at (processed_at)
);

-- Add table comment
COMMENT ON TABLE attributed_checkouts IS 'Stores checkouts with first-click attribution analysis';

-- ============================================
-- Table: users (dimension table)
-- Stores user profile information
-- ============================================
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY,
    email VARCHAR(100),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    registration_date TIMESTAMP,
    customer_segment VARCHAR(20),
    lifetime_value DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_users_email (email),
    INDEX idx_users_segment (customer_segment)
);

-- Add table comment
COMMENT ON TABLE users IS 'User dimension table for enrichment';

-- ============================================
-- Materialized Views for Analytics
-- ============================================

-- Revenue by traffic source (hourly aggregation)
CREATE MATERIALIZED VIEW mv_revenue_by_source AS
SELECT 
    DATE_TRUNC('hour', checkout_timestamp) AS hour,
    traffic_source,
    COUNT(*) AS checkout_count,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_revenue,
    AVG(attribution_window_seconds) AS avg_attribution_window
FROM attributed_checkouts
GROUP BY DATE_TRUNC('hour', checkout_timestamp), traffic_source
ORDER BY hour DESC, total_revenue DESC;

CREATE UNIQUE INDEX ON mv_revenue_by_source (hour, traffic_source);

-- Product category performance
CREATE MATERIALIZED VIEW mv_category_performance AS
SELECT 
    attributed_category,
    COUNT(*) AS conversion_count,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_order_value,
    COUNT(DISTINCT user_id) AS unique_customers
FROM attributed_checkouts
GROUP BY attributed_category
ORDER BY total_revenue DESC;

CREATE UNIQUE INDEX ON mv_category_performance (attributed_category);

-- Device type analysis
CREATE MATERIALIZED VIEW mv_device_analysis AS
SELECT 
    device_type,
    COUNT(*) AS conversion_count,
    SUM(revenue) AS total_revenue,
    AVG(revenue) AS avg_order_value,
    AVG(attribution_window_seconds) / 60 AS avg_time_to_purchase_minutes
FROM attributed_checkouts
GROUP BY device_type
ORDER BY total_revenue DESC;

CREATE UNIQUE INDEX ON mv_device_analysis (device_type);

-- ============================================
-- Functions for materialized view refresh
-- ============================================

CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_by_source;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_device_analysis;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA ecommerce TO PUBLIC;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA ecommerce TO PUBLIC;

-- Success message
SELECT 'Schema created successfully!' AS status;
