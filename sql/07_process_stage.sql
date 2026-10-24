SELECT
    CASE WHEN is_late THEN 'Late' ELSE 'On time / early' END AS delivery_status,
    COUNT(*) AS orders,
    ROUND(AVG(promised_days), 2) AS avg_promised_days,
    ROUND(AVG(handling_days), 2) AS avg_handling_days,
    ROUND(AVG(carrier_days), 2) AS avg_carrier_days,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_delivery_mart
GROUP BY 1
ORDER BY delivery_status;

