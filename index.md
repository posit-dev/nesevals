# nesevals

nesevals provides tooling for evaluating next edit suggestion (NES)
scaffolds across different edit history formats, output formats, and
models.

![A scatter plot titled 'NES Scaffold Performance vs. Latency'. The
x-axis shows median latency in milliseconds starting at 0, and the
y-axis shows mean model-graded quality score. The chart shows that
Qwen3-8B (Baseten) achieves competitive scores at very low latency
(under 200ms), while Claude Haiku 4.5 (Anthropic) achieves the highest
score (around 4.5) at a much higher latency (~1500ms). GPT-OSS 20B
(Groq) reaches a score near 4.3 at moderate latency (~550ms). GPT-4.1
Nano and GPT-5 Nano (both OpenAI) cluster around a score of 3.5 at high
latency. Zeta (Baseten) has the lowest score near 1.4. A group of
additional Qwen3-8B scaffolds (Baseten) clusters at low latency with
scores between roughly 3.1 and
3.4.](reference/figures/README-plot-1.png)

## Installation

Install the package with:

``` r
# if needed:
# install.packages("pak")

pak::pak("posit-dev/nesevals")
```

## Example

The package ships with a data frame `nes_results` that summarizes
experimental results:

``` r
library(dplyr)
library(nesevals)

glimpse(nes_results)
#> Rows: 18
#> Columns: 11
#> $ model              <chr> "claude-haiku-4-5-20251001", "openai/gpt-oss-20b", …
#> $ prompt             <chr> "rewrite-region", "rewrite-region", "rewrite-region…
#> $ edit_history       <chr> "narrative", "narrative", "narrative", "narrative",…
#> $ output_format      <chr> "rewrite_region", "rewrite_region", "rewrite_region…
#> $ n_completions      <int> 80, 80, 240, 240, 80, 80, 240, 240, 240, 240, 240, …
#> $ n_processable      <int> 80, 80, 240, 240, 80, 80, 240, 240, 240, 240, 240, …
#> $ n_exact            <int> 54, 46, 123, 123, 32, 30, 120, 114, 111, 93, 102, 9…
#> $ mean_score         <dbl> 4.49, 4.28, 4.03, 3.96, 3.52, 3.50, 3.41, 3.39, 3.3…
#> $ median_latency_ms  <dbl> 1476, 550, 144, 144, 1370, 1576, 158, 156, 168, 141…
#> $ mean_input_tokens  <dbl> 1358, 1050, 1181, 1155, 1128, 1127, 921, 905, 1097,…
#> $ mean_output_tokens <dbl> 140, 169, 108, 107, 95, 119, 219, 219, 225, 130, 12…
```
