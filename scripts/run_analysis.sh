#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${1:-$PROJECT_ROOT/data}"
DB_PATH="$PROJECT_ROOT/olist_analysis.duckdb"

required_files=(
  olist_customers_dataset.csv
  olist_geolocation_dataset.csv
  olist_order_items_dataset.csv
  olist_order_payments_dataset.csv
  olist_order_reviews_dataset.csv
  olist_orders_dataset.csv
  olist_products_dataset.csv
  olist_sellers_dataset.csv
  product_category_name_translation.csv
)

for file_name in "${required_files[@]}"; do
  if [[ ! -f "$DATA_DIR/$file_name" ]]; then
    echo "Missing source file: $DATA_DIR/$file_name" >&2
    exit 1
  fi
done

if ! command -v duckdb >/dev/null 2>&1; then
  echo "DuckDB CLI is required. See README.md for installation." >&2
  exit 1
fi

rm -f "$DB_PATH" "$DB_PATH.wal"
(
  cd "$DATA_DIR"
  duckdb "$DB_PATH" < "$PROJECT_ROOT/sql/00_build_mart.sql"
)

query_files=(
  01_kpis
  02_delay_review
  03_monthly_trend
  04_state_performance
  05_driver_segments
  06_category_performance
  07_process_stage
  08_quality_checks
  09_hypothesis_summary
)

for query_name in "${query_files[@]}"; do
  duckdb -csv -header "$DB_PATH" < "$PROJECT_ROOT/sql/$query_name.sql" \
    > "$PROJECT_ROOT/results/$query_name.csv"
done

python3 "$PROJECT_ROOT/scripts/generate_assets.py"
echo "Analysis complete: $PROJECT_ROOT/results"

