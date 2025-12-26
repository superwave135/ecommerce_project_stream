-- Seed Data for E-commerce Streaming Analytics
-- Populates dimension tables with sample data

SET search_path TO ecommerce, public;

-- ============================================
-- Seed Users Table
-- ============================================

-- Generate sample users
INSERT INTO users (user_id, email, first_name, last_name, registration_date, customer_segment, lifetime_value)
VALUES
    -- Premium customers
    ('USER-00001', 'alice.smith@email.com', 'Alice', 'Smith', '2023-01-15', 'premium', 2500.00),
    ('USER-00002', 'bob.jones@email.com', 'Bob', 'Jones', '2023-02-20', 'premium', 3200.00),
    ('USER-00003', 'carol.white@email.com', 'Carol', 'White', '2023-03-10', 'premium', 2800.00),
    
    -- Regular customers
    ('USER-00004', 'david.brown@email.com', 'David', 'Brown', '2023-04-05', 'regular', 800.00),
    ('USER-00005', 'emma.wilson@email.com', 'Emma', 'Wilson', '2023-05-12', 'regular', 650.00),
    ('USER-00006', 'frank.miller@email.com', 'Frank', 'Miller', '2023-06-18', 'regular', 920.00),
    ('USER-00007', 'grace.davis@email.com', 'Grace', 'Davis', '2023-07-22', 'regular', 550.00),
    ('USER-00008', 'henry.garcia@email.com', 'Henry', 'Garcia', '2023-08-14', 'regular', 720.00),
    
    -- New customers
    ('USER-00009', 'iris.martinez@email.com', 'Iris', 'Martinez', '2024-01-08', 'new', 125.00),
    ('USER-00010', 'jack.lopez@email.com', 'Jack', 'Lopez', '2024-02-03', 'new', 89.00),
    ('USER-00011', 'kelly.taylor@email.com', 'Kelly', 'Taylor', '2024-03-15', 'new', 156.00),
    ('USER-00012', 'liam.anderson@email.com', 'Liam', 'Anderson', '2024-04-20', 'new', 95.00),
    ('USER-00013', 'mia.thomas@email.com', 'Mia', 'Thomas', '2024-05-10', 'new', 210.00),
    ('USER-00014', 'noah.jackson@email.com', 'Noah', 'Jackson', '2024-06-05', 'new', 45.00),
    ('USER-00015', 'olivia.harris@email.com', 'Olivia', 'Harris', '2024-07-18', 'new', 180.00);

-- Add more users dynamically (simulate 100 users)
DO $$
DECLARE
    i INTEGER;
    user_id_val VARCHAR(50);
    segment_val VARCHAR(20);
    ltv_val DECIMAL(10, 2);
BEGIN
    FOR i IN 16..100 LOOP
        user_id_val := 'USER-' || LPAD(i::TEXT, 5, '0');
        
        -- Randomly assign customer segment
        CASE (i % 3)
            WHEN 0 THEN 
                segment_val := 'premium';
                ltv_val := 2000.00 + (random() * 1500.00);
            WHEN 1 THEN 
                segment_val := 'regular';
                ltv_val := 500.00 + (random() * 1000.00);
            ELSE 
                segment_val := 'new';
                ltv_val := 50.00 + (random() * 250.00);
        END CASE;
        
        INSERT INTO users (
            user_id, 
            email, 
            first_name, 
            last_name, 
            registration_date, 
            customer_segment, 
            lifetime_value
        )
        VALUES (
            user_id_val,
            'user' || i || '@email.com',
            'FirstName' || i,
            'LastName' || i,
            CURRENT_DATE - (random() * 730)::INTEGER,  -- Random date within last 2 years
            segment_val,
            ROUND(ltv_val::NUMERIC, 2)
        );
    END LOOP;
END $$;

-- Verify data insertion
SELECT 
    customer_segment,
    COUNT(*) AS user_count,
    AVG(lifetime_value) AS avg_lifetime_value,
    SUM(lifetime_value) AS total_lifetime_value
FROM users
GROUP BY customer_segment
ORDER BY total_lifetime_value DESC;

-- Success message
SELECT 'Seed data inserted successfully!' AS status,
       (SELECT COUNT(*) FROM users) AS total_users;
