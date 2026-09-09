# Sedan Exodus

A SQL-driven analysis of North American sedan sales (2004/2005–2025), testing whether the well-documented sedan-to-SUV shift is uniform across the market — or concentrated in the luxury tier.

## Problem Statement

Sedans have been losing market share to SUVs and crossovers for over a decade — that trend is well documented and not, by itself, an interesting question. What's less obvious is *where* that decline is concentrated.

The prompt for this project was a simple observation: Lexus's sedan lineup has shrunk to just the ES and IS, while Toyota — Lexus's parent brand — has expanded its own sedan offerings, adding the Crown alongside the long-running Camry, Corolla, and Elantra-class rivals. If the sedan-to-SUV shift were uniform across the market, you'd expect both brands to be pruning their sedan lineups at a similar rate. They aren't.

**Hypothesis:** Sedan sales decline is not uniform across the market — it concentrates more heavily in the luxury tier than in mainstream sedans. Cost-conscious mainstream buyers may retain sedans longer, since sedans remain the practical, lower-cost choice, while luxury buyers — already paying a premium — migrate to luxury SUVs and crossovers faster, since the status signaling behind the purchase transfers just as well to an SUV.

**Update, mid-analysis:** Since drafting the hypothesis above, two more data points have emerged that sharpen it. The Lexus LS is being discontinued, and the Audi A8 is being retired in favor of the new Q9 SUV — on top of the already-noted Audi A4 → A5 shift. Three separate luxury sedan nameplates disappearing in favor of SUV investment, across two different brands, is no longer an isolated anecdote. This reframes the question slightly: it's not just "are luxury sedans selling worse," it's "are luxury manufacturers actively exiting the sedan segment in favor of SUVs." That's a stronger and more falsifiable claim, and it's one the sales-decline data alone can support or complicate — a nameplate can decline in sales for years before a manufacturer decides to cut it, so the discontinuation timing itself is a data point worth tracking against the sales trend, not just a footnote.

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

A few things worth knowing before reading the numbers below:

- **This dataset reflects a fixed 22-year window (2004/2005–2025), not each model's full production history.** Several nameplates — the Passat, Camry, 3-Series among them — existed for decades before this window starts. A model's "first year" in this dataset means "first year we collected," not "first year it existed."

- **The Volkswagen Passat has no 2023–2024 rows because the nameplate was discontinued in North America after the 2022 model year** — there was no production or sales activity to report for those years, so their absence reflects reality rather than a data collection gap. A `2025: 0` entry is included to make the discontinuation explicit in the dataset rather than leaving it as a silent hole.

- **Decline percentages in Findings are calculated against each model's last year with real (non-zero) sales, not literally against 2025.** A model discontinued mid-window would otherwise show an artificial ~-100% decline driven by a placeholder zero year rather than reflecting its actual sales trajectory. Where a model's discontinuation status itself is the notable fact, that's called out separately rather than folded into the decline percentage.

## Data Quality Notes

A few known issues in the source data, worth keeping in mind when reading results:

- **BMW 3-Series:** 2013(Sep)–2015(May) US figures include 4-Series sales bundled in, per GCBC's own note. The apparent 2015→2016 drop (140,609 → 72,290) is largely an accounting change, not a pure demand collapse.
- **Mercedes E-Class:** GCBC's table is missing 2017–2023 entirely (jumps from 2016 to 2024), with no Canada data available for those years either. This is a source gap, not a collection error.
- **Mercedes C-Class (2025):** January 2025 data point missing from source; annual total is understated.
- **Genesis (G70/G80/G90):** Genesis split from Hyundai as a standalone brand in 2015–2016, so earlier years are N/A by definition — not missing data.
- **Audi A4:** Nameplate discontinued, replaced by the A5 for the 2025/2026 model year. Sales collapse to near-zero in 2025 as a result.
- **Audi A8:** Being discontinued, with lineup focus shifting to the new Q9 SUV.
- **Lexus LS:** Being discontinued as Lexus shifts investment toward SUVs/crossovers.
- **VW Passat:** Discontinued in North America after the 2022 model year. US/Canada data ends at 2022, with 2025 confirmed at 0 units.

Full detail lives in the `Data Notes` tab of `sedan_sales_data.xlsx`.

## Methodology

1. Sales data collected per-model from GoodCarBadCar.net and compiled into `sedan_sales_data.xlsx`, with year-over-year % change calculated for both US and Canada.
2. Data imported into a local SQLite database (`sedan_data.db`) via `import_to_sqlite.py`.
3. Exploratory SQL queries (`queries.sql`) used to sanity-check the import, confirm scope, and orient around the dataset before testing the hypothesis.
4. Tier-comparison analysis: peak-to-latest decline calculated per model, then compared across the luxury and mainstream tiers using SQL aggregation and window functions (CTEs, `RANK()`, `LAG()`/`LEAD()`, running totals).
5. Findings visualized in 3–4 targeted charts, each answering one specific question rather than a chart-per-model dump.

## Findings

*In progress — to be filled in once the tier-comparison queries are complete.*

## Interpretation

*In progress.*

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
- SQLite for analysis
- GoodCarBadCar.net as the sole data source
