#!/usr/bin/env python3
"""Generate dependency-free SVG charts and a static portfolio page from SQL results."""

from __future__ import annotations

import csv
import html
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
ASSETS = ROOT / "assets"
DOCS = ROOT / "docs"
ASSETS.mkdir(exist_ok=True)
DOCS.mkdir(exist_ok=True)
(DOCS / "assets").mkdir(exist_ok=True)

NAVY = "#17324D"
BLUE = "#2F6B9A"
TEAL = "#2A9D8F"
ORANGE = "#E76F51"
GOLD = "#E9C46A"
GRID = "#DCE5EC"
TEXT = "#243746"
MUTED = "#667784"


def read_csv(name: str) -> list[dict[str, str]]:
    with (RESULTS / name).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def fmt_int(value: str | float) -> str:
    return f"{float(value):,.0f}"


def write_svg(output_name: str, content: str) -> None:
    """Keep README assets and the self-contained GitHub Pages copy in sync."""
    (ASSETS / output_name).write_text(content, encoding="utf-8")
    (DOCS / "assets" / output_name).write_text(content, encoding="utf-8")


def svg_bar_chart(
    rows: list[dict[str, str]],
    label_key: str,
    value_key: str,
    title: str,
    subtitle: str,
    output_name: str,
    value_suffix: str = "",
) -> None:
    width = 980
    left = 210
    right = 90
    top = 95
    row_height = 42
    height = top + row_height * len(rows) + 55
    values = [float(row[value_key]) for row in rows]
    max_value = max(values) if values else 1
    plot_width = width - left - right
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{esc(title)}">',
        '<rect width="100%" height="100%" fill="#FFFFFF"/>',
        f'<text x="24" y="34" font-family="Arial" font-size="22" font-weight="700" fill="{NAVY}">{esc(title)}</text>',
        f'<text x="24" y="60" font-family="Arial" font-size="13" fill="{MUTED}">{esc(subtitle)}</text>',
    ]
    for idx, row in enumerate(rows):
        y = top + idx * row_height
        value = float(row[value_key])
        bar_width = plot_width * value / max_value
        color = ORANGE if value_key == "late_rate_pct" else BLUE
        parts.extend(
            [
                f'<text x="{left - 12}" y="{y + 19}" text-anchor="end" font-family="Arial" font-size="13" fill="{TEXT}">{esc(row[label_key])}</text>',
                f'<rect x="{left}" y="{y + 4}" width="{plot_width}" height="24" rx="3" fill="#EFF3F6"/>',
                f'<rect x="{left}" y="{y + 4}" width="{bar_width:.1f}" height="24" rx="3" fill="{color}"/>',
                f'<text x="{left + bar_width + 8:.1f}" y="{y + 21}" font-family="Arial" font-size="12" font-weight="700" fill="{TEXT}">{value:.2f}{esc(value_suffix)}</text>',
            ]
        )
    parts.append('</svg>')
    write_svg(output_name, "\n".join(parts))


def svg_line_chart(rows: list[dict[str, str]]) -> None:
    width, height = 980, 430
    left, right, top, bottom = 72, 32, 86, 62
    plot_w, plot_h = width - left - right, height - top - bottom
    values = [float(row["late_rate_pct"]) for row in rows]
    min_y = max(0.0, min(values) - 2)
    max_y = max(values) + 2

    def x_at(index: int) -> float:
        return left + plot_w * index / max(1, len(rows) - 1)

    def y_at(value: float) -> float:
        return top + plot_h * (max_y - value) / max(0.001, max_y - min_y)

    points = " ".join(f"{x_at(i):.1f},{y_at(value):.1f}" for i, value in enumerate(values))
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="Monthly late-delivery rate">',
        '<rect width="100%" height="100%" fill="#FFFFFF"/>',
        f'<text x="24" y="34" font-family="Arial" font-size="22" font-weight="700" fill="{NAVY}">Monthly late-delivery rate</text>',
        f'<text x="24" y="60" font-family="Arial" font-size="13" fill="{MUTED}">Purchase cohorts with at least 100 delivered orders</text>',
    ]
    for tick in range(5):
        value = min_y + (max_y - min_y) * tick / 4
        y = y_at(value)
        parts.append(f'<line x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}" stroke="{GRID}"/>')
        parts.append(f'<text x="{left-10}" y="{y+4:.1f}" text-anchor="end" font-family="Arial" font-size="11" fill="{MUTED}">{value:.1f}%</text>')
    parts.append(f'<polyline fill="none" stroke="{TEAL}" stroke-width="4" points="{points}"/>')
    for idx, row in enumerate(rows):
        x = x_at(idx)
        y = y_at(float(row["late_rate_pct"]))
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="{TEAL}"/>')
        if idx % 2 == 0 or idx == len(rows) - 1:
            label = row["purchase_month"][:7]
            parts.append(f'<text x="{x:.1f}" y="{height-bottom+24}" text-anchor="middle" font-family="Arial" font-size="10" fill="{MUTED}">{esc(label)}</text>')
    parts.append('</svg>')
    write_svg("monthly_late_rate.svg", "\n".join(parts))


def generate_page() -> None:
    kpi = read_csv("01_kpis.csv")[0]
    delay_rows = read_csv("02_delay_review.csv")
    process_rows = {row["delivery_status"]: row for row in read_csv("07_process_stage.csv")}
    early = delay_rows[0]
    severe = next(row for row in delay_rows if row["delay_bucket"] == "8+ days late")
    late = process_rows["Late"]
    on_time = process_rows["On time / early"]
    page = f"""<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Olist配送パフォーマンス分析</title>
  <style>
    :root {{ --navy:{NAVY}; --blue:{BLUE}; --teal:{TEAL}; --orange:{ORANGE}; --bg:#F5F7F9; --text:{TEXT}; --muted:{MUTED}; }}
    * {{ box-sizing:border-box; }} body {{ margin:0; font-family:Arial,"Hiragino Kaku Gothic ProN",sans-serif; color:var(--text); background:var(--bg); line-height:1.65; }}
    header {{ background:linear-gradient(120deg,var(--navy),#245579); color:white; padding:72px 24px; }}
    .wrap {{ max-width:1080px; margin:auto; }} h1 {{ font-size:42px; line-height:1.2; margin:0 0 16px; }} h2 {{ color:var(--navy); margin-top:54px; }}
    .lead {{ max-width:760px; font-size:18px; color:#E7EEF3; }} .tag {{ display:inline-block; background:#ffffff1f; border:1px solid #ffffff55; border-radius:999px; padding:6px 12px; margin:4px; }}
    main {{ padding:34px 24px 72px; }} .kpis {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:14px; margin-top:-68px; }}
    .card {{ background:white; border-radius:12px; padding:22px; box-shadow:0 8px 24px #17324d14; }} .kpi-value {{ color:var(--navy); font-size:30px; font-weight:700; }} .kpi-label {{ color:var(--muted); font-size:13px; }}
    .finding {{ border-left:5px solid var(--orange); }} .finding strong {{ color:var(--navy); }}
    .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:18px; }} img {{ width:100%; background:white; border-radius:12px; box-shadow:0 8px 24px #17324d10; }}
    table {{ width:100%; border-collapse:collapse; background:white; }} th,td {{ padding:12px; border-bottom:1px solid #E4EBF0; text-align:left; }} th {{ background:var(--navy); color:white; }}
    code {{ background:#EAF0F4; padding:2px 5px; border-radius:4px; }} footer {{ color:var(--muted); font-size:13px; margin-top:54px; }}
  </style>
</head>
<body>
<header><div class="wrap">
  <p>SQL DATA ANALYTICS PORTFOLIO</p>
  <h1>Olist配送パフォーマンス分析</h1>
  <p class="lead">ブラジルのEC公開データを用い、配送遅延が顧客評価へ与える関係と、改善対象となる物流セグメントをDuckDB SQLで分析しました。</p>
  <div><span class="tag">DuckDB SQL</span><span class="tag">Data Modeling</span><span class="tag">Business Analysis</span></div>
</div></header>
<main><div class="wrap">
  <section class="kpis">
    <div class="card"><div class="kpi-value">{fmt_int(kpi['delivered_orders'])}</div><div class="kpi-label">分析対象の配送完了注文</div></div>
    <div class="card"><div class="kpi-value">{esc(kpi['late_rate_pct'])}%</div><div class="kpi-label">予定日超過率</div></div>
    <div class="card"><div class="kpi-value">{esc(kpi['median_delivery_days'])}日</div><div class="kpi-label">配送日数の中央値</div></div>
    <div class="card"><div class="kpi-value">{esc(kpi['avg_review_score'])}/5</div><div class="kpi-label">平均レビュー</div></div>
  </section>

  <h2>課題設定</h2>
  <div class="card"><p>配送完了だけを成果とせず、約束した到着予定日を守れているかを主要KPIとします。事業課題は、遅延による低評価を減らしながら、どの工程・地域・注文特性から優先して改善すべきかを明らかにすることです。</p></div>

  <h2>主要な発見</h2>
  <div class="grid">
    <div class="card finding"><strong>遅延と顧客評価には大きな差があります。</strong><p>7日以上早着した注文の平均評価は {esc(early['avg_review_score'])}、8日以上遅延した注文は {esc(severe['avg_review_score'])} でした。低評価率は {esc(early['low_review_rate_pct'])}% から {esc(severe['low_review_rate_pct'])}% へ上昇しています。</p></div>
    <div class="card finding"><strong>遅延注文では運送工程の長期化が目立ちます。</strong><p>配送業者への引き渡し後から顧客到着までの平均は、期限内注文が {esc(on_time['avg_carrier_days'])} 日、遅延注文が {esc(late['avg_carrier_days'])} 日です。因果は断定できませんが、監視対象として優先度が高い工程です。</p></div>
  </div>

  <h2>可視化</h2>
  <img src="assets/review_by_delay.svg" alt="遅延区分別の平均レビュー">
  <img src="assets/state_late_rate.svg" alt="州別の配送遅延率">
  <img src="assets/monthly_late_rate.svg" alt="月別の配送遅延率">

  <h2>改善提案</h2>
  <table>
    <thead><tr><th>優先度</th><th>施策</th><th>役割</th><th>検証KPI</th></tr></thead>
    <tbody>
      <tr><td>1</td><td>配送リスクの早期警告</td><td>距離・州間配送・重量・出荷遅れを使い、予定日超過リスクの高い注文を事前に抽出する。</td><td>予定日超過率、8日以上遅延率</td></tr>
      <tr><td>2</td><td>配送業者別SLA管理</td><td>引き渡し後の所要日数をルート別に監視し、長期化した組み合わせを改善対象にする。</td><td>carrier days、P90配送日数</td></tr>
      <tr><td>3</td><td>約束日の精度改善</td><td>州・距離帯・重量帯・月別の実績分布から、過度に楽観的な予定日を補正する。</td><td>予定日内到着率、早着日数と遅延日数の偏り</td></tr>
      <tr><td>4</td><td>遅延時の顧客対応</td><td>遅延見込み時点で通知し、更新予定日と選択肢を提示する。</td><td>遅延注文の低評価率、問い合わせ率</td></tr>
    </tbody>
  </table>

  <h2>分析上の注意</h2>
  <div class="card"><p>本分析は観察データの関連を示すもので、遅延が低評価を引き起こしたという因果効果を証明していません。レビューがない注文と位置情報が取得できない注文があり、距離は郵便番号ごとの緯度経度平均から計算した概算です。複数出品者の注文は取引金額が最大の出品者を代表として使用しました。</p></div>

  <footer>Source: Brazilian E-Commerce Public Dataset by Olist. Analysis generated from the repository's SQL pipeline.</footer>
</div></main>
</body></html>"""
    (DOCS / "index.html").write_text(page, encoding="utf-8")


def main() -> None:
    delay_rows = read_csv("02_delay_review.csv")
    svg_bar_chart(
        delay_rows,
        "delay_bucket",
        "avg_review_score",
        "Average review score by delivery timing",
        "One latest review per order; five-point scale",
        "review_by_delay.svg",
    )
    state_rows = sorted(read_csv("04_state_performance.csv"), key=lambda row: float(row["late_rate_pct"]), reverse=True)
    svg_bar_chart(
        state_rows,
        "customer_state",
        "late_rate_pct",
        "Late-delivery rate by customer state",
        "States with at least 500 delivered orders",
        "state_late_rate.svg",
        "%",
    )
    svg_line_chart(read_csv("03_monthly_trend.csv"))
    generate_page()


if __name__ == "__main__":
    main()

