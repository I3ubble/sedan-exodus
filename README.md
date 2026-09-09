# Sedan Exodus

A SQL-driven analysis of North American sedan sales (2004/2005–2025), testing whether the well-documented sedan-to-SUV shift is uniform across the market — or concentrated in the luxury tier.

**Live dashboard:** https://public.tableau.com/app/profile/rongcan.chen/viz/SedanExodusLuxuryvs_MainstreamSedanDecline/1_1?publish=yes

## What this project demonstrates

This project was built to move past basic `SELECT`/`GROUP BY` fluency into the SQL patterns that actually show up in analyst interviews and real reporting work: **CTEs, window functions (`RANK`, `LAG`), correlated subqueries, and multi-table joins**, applied to a real question rather than a toy dataset. Concretely, it demonstrates:

- **Data collection and cleaning** — sourced and compiled 20+ years of sales data across 21 nameplates and 8 brands from a public source, handling inconsistent date ranges, missing years, and source-side data gaps without fabricating or silently dropping anything
- **Data-integrity debugging** — caught and fixed a real bug where a correlated subquery was picking up placeholder zero-sales rows for discontinued models, which would have silently distorted every downstream decline calculation; documented the fix directly in the SQL so the reasoning is auditable, not just the result
- **Window functions for comparative analysis** — used `RANK() OVER (PARTITION BY tier ...)` to rank each model's decline severity *within its own tier* rather than against the whole dataset, and `LAG() OVER (PARTITION BY model ORDER BY year ...)` to compute year-over-year trajectories directly in SQL rather than relying on pre-calculated spreadsheet columns
- **Hypothesis testing with a stress test** — didn't just compute one tier-average number and stop; re-ran the comparison excluding the two most extreme discontinuation cases to confirm the luxury-vs-mainstream gap wasn't an artifact of two outliers, and reported both versions
- **Data visualization for a non-technical audience** — translated the SQL findings into a published, interactive Tableau Public dashboard with four purpose-built charts, each answering one specific question rather than dumping every possible cut of the data

## Problem Statement

Sedans have been losing market share to SUVs and crossovers for over a decade — that trend is well documented and not, by itself, an interesting question. What's less obvious is *where* that decline is concentrated.

The prompt for this project was a simple observation: Lexus's sedan lineup has shrunk to just the ES and IS, while Toyota — Lexus's parent brand — has expanded its own sedan offerings, adding the Crown alongside the long-running Camry, Corolla, and Elantra-class rivals. If the sedan-to-SUV shift were uniform across the market, you'd expect both brands to be pruning their sedan lineups at a similar rate. They aren't.

**Hypothesis:** Sedan sales decline is not uniform across the market — it concentrates more heavily in the luxury tier than in mainstream sedans. Cost-conscious mainstream buyers may retain sedans longer, since sedans remain the practical, lower-cost choice, while luxury buyers — already paying a premium — migrate to luxury SUVs and crossovers faster, since the status signaling behind the purchase transfers just as well to an SUV.

**Update, mid-analysis:** Since drafting the hypothesis above, several more data points emerged that sharpen it: the Lexus LS is being discontinued, the Audi A8 is being retired in favor of the new Q9 SUV, and the Audi A4 is being replaced by the A5. Three separate luxury sedan nameplates disappearing in favor of SUV investment, across two different brands, is no longer an isolated anecdote. This reframes the question slightly: it's not just "are luxury sedans selling worse," it's "are luxury manufacturers actively exiting the sedan segment in favor of SUVs."

## Key Findings

- **Luxury sedans decline more than mainstream sedans on average, and the gap holds up under scrutiny.** Across all 21 models, luxury averaged a **-67.1%** peak-to-latest decline versus mainstream's **-58.6%**. Excluding the two most extreme discontinuation cases (VW Passat, Audi A4) from each tier, the gap *widened* to -64.8% vs -50.7% — ruling out the concern that one bad outlier per tier was driving the result.
- **Luxury brands are discontinuing sedan nameplates at 3x the rate of mainstream brands.** 3 of 15 luxury models in scope (Lexus LS, Audi A4, Audi A8) are being discontinued or replaced by SUVs, versus 1 of 6 mainstream models (VW Passat).
- **Near-discontinued models show a recognizable trajectory shape before the fact.** Comparing year-over-year sales for the two confirmed-dying models (Passat, A4) against two still-active but declining luxury models (LS, A8) shows LS's recent trajectory converging toward the same late-stage cliff pattern A4 already went through — while A8's trajectory stays noisy and range-bound, suggesting its discontinuation is more of a strategic lineup decision than something the sales data was already signaling.

## Interpretation

*In progress.*

## Approach

Rather than looking at luxury sedans in isolation, this analysis compares luxury nameplates against their mainstream sibling from the same parent company, using 2004/2005–2025 US and Canada annual sales data:

| Luxury | Mainstream sibling |
|---|---|
| Lexus (IS, ES, LS) | Toyota (Camry, Corolla) |
| Genesis (G70, G80, G90) | Hyundai (Sonata, Elantra) |
| Audi (A4, A6, A8) | Volkswagen (Jetta, Passat) |
| BMW (3/5/7 Series) | *(no in-scope mainstream sibling)* |
| Mercedes-Benz (C/E/S-Class) | *(no in-scope mainstream sibling)* |

Pairing by parent company controls for at least some of the confounding factors that would otherwise muddy a straight luxury-vs-mainstream comparison — same underlying platforms in several cases, same general market positioning strategy, same macro exposure. BMW and Mercedes are included as supporting luxury-tier data points but have no mainstream sibling in scope, so they sit outside the core paired comparison.

## Data Sources

- **[GoodCarBadCar.net](https://www.goodcarbadcar.net/)** — US and Canada annual sales figures, 2004/2005–2025, collected per-model from each nameplate's dedicated sales-figures page.

20 models across 8 brands, 414 rows total:

- **Luxury:** Lexus IS/ES/LS, BMW 3/5/7 Series, Mercedes-Benz C/E/S-Class, Genesis G70/G80/G90, Audi A4/A6/A8
- **Mainstream:** Toyota Camry/Corolla, Hyundai Sonata/Elantra, Volkswagen Jetta/Passat

## Data Coverage & Interpretation Notes

A few things worth knowing before reading the numbers above:

- **This dataset reflects a fixed 22-year window (2004/2005–2025), not each model's full production history.** Several nameplates — the Passat, Camry, 3-Series among them — existed for decades before this window starts. A model's "first year" in this dataset means "first year we collected," not "first year it existed."
- **The Volkswagen Passat has no 2023–2024 rows because the nameplate was discontinued in North America after the 2022 model year** — there was no production or sales activity to report for those years, so their absence reflects reality rather than a data collection gap. A `2025: 0` entry is included to make the discontinuation explicit in the dataset rather than leaving it as a silent hole.
- **Decline percentages are calculated against each model's last year with real (non-zero) sales, not literally against 2025.** A model discontinued mid-window would otherwise show an artificial ~-100% decline driven by a placeholder zero year rather than reflecting its actual sales trajectory. Discontinuation status itself is tracked as a separate flag rather than folded into the decline percentage.

## Data Quality Notes

A few known issues in the source data, worth keeping in mind when reading results:

- **BMW 3-Series:** 2013(Sep)–2015(May) US figures include 4-Series sales bundled in, per GCBC's own note. The apparent 2015→2016 drop (140,609 → 72,290) is largely an accounting change, not a pure demand collapse.
- **Mercedes E-Class:** GCBC's table is missing 2017–2023 entirely (jumps from 2016 to 2024), with no Canada data available for those years either. This is a source gap, not a collection error.
- **Mercedes C-Class (2025):** January 2025 data point missing from source; annual total is understated.
- **Genesis (G70/G80/G90):** Genesis split from Hyundai as a standalone brand in 2015–2016, so earlier years are N/A by definition — not missing data.
- **Audi A4:** Nameplate discontinued, replaced by the A5 for the 2025/2026 model year.
- **Audi A8:** Being discontinued, with lineup focus shifting to the new Q9 SUV.
- **Lexus LS:** Being discontinued as Lexus shifts investment toward SUVs/crossovers.
- **VW Passat:** Discontinued in North America after the 2022 model year.

Full detail lives in the `Data Notes` tab of `sedan_sales_data.xlsx`.

## Methodology

1. Sales data collected per-model from GoodCarBadCar.net and compiled into `sedan_sales_data.xlsx`, with year-over-year % change calculated for both US and Canada.
2. Data imported into a local SQLite database (`sedan_data.db`) via `import_to_sqlite.py`.
3. Exploratory SQL queries (`queries.sql`) used to sanity-check the import, confirm scope, and orient around the dataset before testing the hypothesis.
4. Tier-comparison analysis: peak-to-latest decline calculated per model via CTEs, cross-checked with a stress test excluding discontinued outliers, then compared across tiers using `AVG`/`GROUP BY`.
5. Deeper analysis using window functions: `RANK()` to compare each model's decline severity within its own tier; `LAG()` to compute year-over-year trajectories and compare the shape of decline across near-discontinued models.
6. Findings exported and visualized in a 4-chart Tableau Public dashboard, each chart answering one specific question rather than a chart-per-model dump.

## Project Structure

```
sedan-exodus/
├── README.md
├── sedan_sales_data.xlsx   # raw compiled data + Data Notes + Progress tabs
├── sedan_data.db           # SQLite database (generated, not committed)
├── import_to_sqlite.py     # loads xlsx into sedan_data.db
├── queries.sql             # exploratory + analytical SQL, in order written
```

## Tools

- Python (openpyxl) for data compilation
- SQL (SQLite) — CTEs, window functions, correlated subqueries, joins
- Tableau Public for interactive data visualization
- GoodCarBadCar.net as the sole data source
