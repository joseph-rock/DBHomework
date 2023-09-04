SELECT 'Hello World!';

-- SECTION B - Tier name function

CREATE OR REPLACE FUNCTION tier_name(total_spent numeric)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN CASE 
    WHEN total_spent >= 100 AND total_spent < 200
        THEN 'gold'
    WHEN total_spent >= 200
        THEN 'platinum'
    ELSE
	'standard'
    END;
END;
$$;

-- Function test

DROP TABLE IF EXISTS test;
CREATE TEMP TABLE test (
	expected varchar(20),
	actual varchar(10)
);

INSERT INTO test (expected, actual)
VALUES
	('standard', tier_name(0)),
	('standard', tier_name(50.10)),
	('standard', tier_name(99.99)),
	('gold', tier_name(100)),
	('gold', tier_name(125.48)),
	('gold', tier_name(199.99)),
	('platinum', tier_name(200)),
	('platinum', tier_name(999.99)),
	('standard', tier_name(-1)),
	('null > standard', tier_name(null));
	
SELECT * FROM test;


-- SECTION C - Detailed table

DROP TABLE IF EXISTS revenue_per_customer;

CREATE TABLE revenue_per_customer (
    customer_id int,
    first_name varchar(45),
    last_name varchar(45),
    email varchar(50),
    total_spent numeric,
    tier text
);

SELECT * FROM revenue_per_customer;


-- SECTION C - Summary Table

DROP TABLE IF EXISTS tier_totals;

CREATE TABLE tier_totals (
    tier text,
    number_of_customers numeric
);

SELECT * FROM tier_totals;


-- SECTION D - Select statement that will populate the detailed table																	
	
WITH customer_revenue AS (
    SELECT 	
        customer_id,
        SUM(amount) AS total_spent
    FROM payment
    GROUP BY customer_id
)
SELECT 	
    customer.customer_id,
    customer.first_name,
    customer.last_name,
    customer.email,
    COALESCE(customer_revenue.total_spent, 0) AS total_spent,
    tier_name(customer_revenue.total_spent)
FROM customer
LEFT JOIN customer_revenue 
    ON customer.customer_id = customer_revenue.customer_id
ORDER BY total_spent DESC;

SELECT COUNT(*) FROM customer;
SELECT COUNT(DISTINCT customer_id) FROM payment;


-- SECTION E - Trigger to update summary table

CREATE OR REPLACE FUNCTION insert_customer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM tier_totals;
    INSERT INTO tier_totals
    SELECT
        tier, 
        COUNT(customer_id)
    FROM revenue_per_customer
    GROUP BY tier;
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_tier_totals
AFTER INSERT OR DELETE
ON revenue_per_customer
FOR EACH STATEMENT
EXECUTE PROCEDURE insert_customer();

SELECT * FROM tier_totals;


-- SECTION F - Stored Procedure

CREATE OR REPLACE PROCEDURE refresh_customer_revenue()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM revenue_per_customer;
    DELETE FROM tier_totals;
    
    INSERT INTO revenue_per_customer	
    WITH customer_revenue AS (
        SELECT 
            customer_id,
            SUM(amount) AS total_spent
        FROM payment
        GROUP BY customer_id
    )
    SELECT 	
        customer.customer_id,
        customer.first_name,
        customer.last_name,
        customer.email,
        COALESCE(customer_revenue.total_spent, 0),
        tier_name(customer_revenue.total_spent)
    FROM customer
    LEFT JOIN customer_revenue 
        ON customer.customer_id = customer_revenue.customer_id
    ORDER BY total_spent DESC;
RETURN;
END;
$$;

-- Test refresh procedure
SELECT * FROM tier_totals ORDER BY number_of_customers DESC;
SELECT * FROM revenue_per_customer ORDER BY customer_id DESC;

CALL refresh_customer_revenue();

SELECT COUNT(*) FROM customer;
SELECT COUNT(*) FROM revenue_per_customer;

INSERT INTO revenue_per_customer
VALUES (999, 'test', 'account', 'test@account.com', 999.99, 'special');

DELETE FROM revenue_per_customer WHERE tier = 'standard';







