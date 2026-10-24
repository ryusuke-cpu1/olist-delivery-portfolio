WITH metric AS (
    SELECT
        AVG(review_score) FILTER (WHERE is_late) AS late_review,
        AVG(review_score) FILTER (WHERE NOT is_late) AS on_time_review,
        AVG(is_late::INTEGER) FILTER (WHERE distance_band = '1,500+ km') AS long_distance_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE distance_band = '<250 km') AS short_distance_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE weight_band = '10+ kg') AS heavy_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE weight_band = '<1 kg') AS light_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE item_count >= 3) AS multi_item_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE item_count = 1) AS single_item_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE NOT same_state) AS interstate_late_rate,
        AVG(is_late::INTEGER) FILTER (WHERE same_state) AS same_state_late_rate,
        AVG(carrier_days) FILTER (WHERE is_late) AS late_carrier_days,
        AVG(carrier_days) FILTER (WHERE NOT is_late) AS on_time_carrier_days
    FROM order_delivery_mart
)
SELECT
    'H1' AS hypothesis_id,
    'Late orders have lower review scores' AS hypothesis,
    ROUND(late_review, 2) AS comparison_value,
    ROUND(on_time_review, 2) AS baseline_value,
    ROUND(late_review - on_time_review, 2) AS difference,
    'Supported: association only' AS result
FROM metric

UNION ALL

SELECT
    'H2',
    'Long-distance routes have a higher late rate',
    ROUND(100 * long_distance_late_rate, 2),
    ROUND(100 * short_distance_late_rate, 2),
    ROUND(100 * (long_distance_late_rate - short_distance_late_rate), 2),
    'Supported: unadjusted comparison'
FROM metric

UNION ALL

SELECT
    'H3',
    'Heavy orders have a higher late rate',
    ROUND(100 * heavy_late_rate, 2),
    ROUND(100 * light_late_rate, 2),
    ROUND(100 * (heavy_late_rate - light_late_rate), 2),
    'Supported: unadjusted comparison'
FROM metric

UNION ALL

SELECT
    'H4',
    'Orders with 3+ items have a higher late rate',
    ROUND(100 * multi_item_late_rate, 2),
    ROUND(100 * single_item_late_rate, 2),
    ROUND(100 * (multi_item_late_rate - single_item_late_rate), 2),
    'Not supported'
FROM metric

UNION ALL

SELECT
    'H5',
    'Interstate routes have a higher late rate',
    ROUND(100 * interstate_late_rate, 2),
    ROUND(100 * same_state_late_rate, 2),
    ROUND(100 * (interstate_late_rate - same_state_late_rate), 2),
    'Supported: unadjusted comparison'
FROM metric

UNION ALL

SELECT
    'H6',
    'Late orders spend longer in carrier transit',
    ROUND(late_carrier_days, 2),
    ROUND(on_time_carrier_days, 2),
    ROUND(late_carrier_days - on_time_carrier_days, 2),
    'Supported: association only'
FROM metric;

