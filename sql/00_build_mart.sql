-- Olist delivery portfolio: reusable analytical mart
-- Run from the directory containing the nine source CSV files.

CREATE OR REPLACE TABLE customers AS
SELECT * FROM read_csv_auto('olist_customers_dataset.csv', header = true);

CREATE OR REPLACE TABLE geolocation AS
SELECT * FROM read_csv_auto('olist_geolocation_dataset.csv', header = true);

CREATE OR REPLACE TABLE order_items AS
SELECT * FROM read_csv_auto('olist_order_items_dataset.csv', header = true);

CREATE OR REPLACE TABLE order_payments AS
SELECT * FROM read_csv_auto('olist_order_payments_dataset.csv', header = true);

CREATE OR REPLACE TABLE order_reviews AS
SELECT * FROM read_csv_auto('olist_order_reviews_dataset.csv', header = true);

CREATE OR REPLACE TABLE orders AS
SELECT * FROM read_csv_auto('olist_orders_dataset.csv', header = true);

CREATE OR REPLACE TABLE products AS
SELECT * FROM read_csv_auto('olist_products_dataset.csv', header = true);

CREATE OR REPLACE TABLE sellers AS
SELECT * FROM read_csv_auto('olist_sellers_dataset.csv', header = true);

CREATE OR REPLACE TABLE category_translation AS
SELECT *
FROM read_csv_auto(
    'product_category_name_translation.csv',
    header = true,
    all_varchar = true
);

CREATE OR REPLACE TABLE geo_zip AS
SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude
FROM geolocation
WHERE geolocation_lat BETWEEN -34 AND 6
  AND geolocation_lng BETWEEN -74 AND -34
GROUP BY 1;

CREATE OR REPLACE TABLE item_enriched AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    p.product_weight_g,
    p.product_length_cm * p.product_height_cm * p.product_width_cm AS product_volume_cm3,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name
FROM order_items AS oi
LEFT JOIN products AS p USING (product_id)
LEFT JOIN category_translation AS t USING (product_category_name);

CREATE OR REPLACE TABLE item_agg AS
SELECT
    order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT seller_id) AS seller_count,
    SUM(price) AS item_value,
    SUM(freight_value) AS freight_value,
    SUM(product_weight_g) AS total_weight_g,
    SUM(product_volume_cm3) AS total_volume_cm3
FROM item_enriched
GROUP BY 1;

CREATE OR REPLACE TABLE dominant_seller AS
WITH seller_value AS (
    SELECT
        order_id,
        seller_id,
        SUM(price + freight_value) AS seller_order_value
    FROM item_enriched
    GROUP BY 1, 2
)
SELECT order_id, seller_id
FROM seller_value
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id
    ORDER BY seller_order_value DESC, seller_id
) = 1;

CREATE OR REPLACE TABLE dominant_category AS
WITH category_value AS (
    SELECT
        order_id,
        category_name,
        SUM(price) AS category_item_value
    FROM item_enriched
    GROUP BY 1, 2
)
SELECT order_id, category_name
FROM category_value
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id
    ORDER BY category_item_value DESC, category_name
) = 1;

CREATE OR REPLACE TABLE latest_review AS
SELECT
    order_id,
    review_id,
    review_score,
    review_creation_date,
    review_answer_timestamp
FROM order_reviews
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id
    ORDER BY review_answer_timestamp DESC NULLS LAST,
             review_creation_date DESC NULLS LAST,
             review_id
) = 1;

CREATE OR REPLACE TABLE payment_agg AS
SELECT
    order_id,
    SUM(payment_value) AS payment_value,
    MAX(payment_installments) AS max_installments,
    COUNT(*) AS payment_record_count
FROM order_payments
GROUP BY 1;

CREATE OR REPLACE TABLE order_delivery_mart AS
WITH base AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ia.item_count,
        ia.seller_count,
        ia.item_value,
        ia.freight_value,
        ia.total_weight_g,
        ia.total_volume_cm3,
        pa.payment_value,
        lr.review_score,
        dc.category_name,
        s.seller_state,
        cg.latitude AS customer_latitude,
        cg.longitude AS customer_longitude,
        sg.latitude AS seller_latitude,
        sg.longitude AS seller_longitude
    FROM orders AS o
    INNER JOIN customers AS c USING (customer_id)
    INNER JOIN item_agg AS ia USING (order_id)
    LEFT JOIN dominant_seller AS ds USING (order_id)
    LEFT JOIN sellers AS s USING (seller_id)
    LEFT JOIN dominant_category AS dc USING (order_id)
    LEFT JOIN latest_review AS lr USING (order_id)
    LEFT JOIN payment_agg AS pa USING (order_id)
    LEFT JOIN geo_zip AS cg
        ON c.customer_zip_code_prefix = cg.zip_code_prefix
    LEFT JOIN geo_zip AS sg
        ON s.seller_zip_code_prefix = sg.zip_code_prefix
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_approved_at IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
), metrics AS (
    SELECT
        *,
        DATE_TRUNC('month', order_purchase_timestamp)::DATE AS purchase_month,
        DATE_DIFF('hour', order_purchase_timestamp, order_delivered_customer_date) / 24.0 AS delivery_days,
        DATE_DIFF('hour', order_purchase_timestamp, order_estimated_delivery_date) / 24.0 AS promised_days,
        DATE_DIFF('hour', order_approved_at, order_delivered_carrier_date) / 24.0 AS handling_days,
        DATE_DIFF('hour', order_delivered_carrier_date, order_delivered_customer_date) / 24.0 AS carrier_days,
        DATE_DIFF('hour', order_estimated_delivery_date, order_delivered_customer_date) / 24.0 AS delay_days,
        order_delivered_customer_date > order_estimated_delivery_date AS is_late,
        customer_state = seller_state AS same_state,
        CASE
            WHEN customer_latitude IS NULL OR seller_latitude IS NULL THEN NULL
            ELSE 6371 * 2 * ASIN(SQRT(LEAST(1.0,
                POWER(SIN(RADIANS(customer_latitude - seller_latitude) / 2), 2)
                + COS(RADIANS(seller_latitude)) * COS(RADIANS(customer_latitude))
                * POWER(SIN(RADIANS(customer_longitude - seller_longitude) / 2), 2)
            )))
        END AS distance_km
    FROM base
)
SELECT
    *,
    CASE
        WHEN delay_days <= -7 THEN '7+ days early'
        WHEN delay_days < 0 THEN '1-6 days early'
        WHEN delay_days < 1 THEN '<1 day late'
        WHEN delay_days < 4 THEN '1-3 days late'
        WHEN delay_days < 8 THEN '4-7 days late'
        ELSE '8+ days late'
    END AS delay_bucket,
    CASE
        WHEN distance_km IS NULL THEN 'Unknown'
        WHEN distance_km < 250 THEN '<250 km'
        WHEN distance_km < 750 THEN '250-749 km'
        WHEN distance_km < 1500 THEN '750-1,499 km'
        ELSE '1,500+ km'
    END AS distance_band,
    CASE
        WHEN total_weight_g IS NULL THEN 'Unknown'
        WHEN total_weight_g < 1000 THEN '<1 kg'
        WHEN total_weight_g < 5000 THEN '1-4.9 kg'
        WHEN total_weight_g < 10000 THEN '5-9.9 kg'
        ELSE '10+ kg'
    END AS weight_band
FROM metrics;

