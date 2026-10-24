WITH checks AS (
    SELECT 'mart_row_count' AS check_name, COUNT(*)::VARCHAR AS check_value
    FROM order_delivery_mart

    UNION ALL

    SELECT 'distinct_order_count', COUNT(DISTINCT order_id)::VARCHAR
    FROM order_delivery_mart

    UNION ALL

    SELECT 'duplicate_order_rows', (COUNT(*) - COUNT(DISTINCT order_id))::VARCHAR
    FROM order_delivery_mart

    UNION ALL

    SELECT 'missing_review_pct', ROUND(100 * AVG((review_score IS NULL)::INTEGER), 2)::VARCHAR
    FROM order_delivery_mart

    UNION ALL

    SELECT 'missing_distance_pct', ROUND(100 * AVG((distance_km IS NULL)::INTEGER), 2)::VARCHAR
    FROM order_delivery_mart

    UNION ALL

    SELECT 'negative_delivery_duration_rows', SUM((delivery_days < 0)::INTEGER)::VARCHAR
    FROM order_delivery_mart

    UNION ALL

    SELECT 'payment_vs_item_freight_abs_diff_brl',
           ROUND(ABS(SUM(payment_value) - SUM(item_value + freight_value)), 2)::VARCHAR
    FROM order_delivery_mart
)
SELECT * FROM checks;

