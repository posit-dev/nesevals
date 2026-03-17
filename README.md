
<!-- README.md is generated from README.Rmd. Please edit that file -->

# nesevals

<!-- badges: start -->

<!-- badges: end -->

nesevals provides tooling for evaluating next edit suggestion (NES)
scaffolds across different edit history formats, output formats, and
models.

<img src="man/figures/README-plot-1.png" alt="A scatter plot titled 'NES Scaffold Performance vs. Latency'. The x-axis shows median latency in milliseconds starting at 0, and the y-axis shows mean model-graded quality score. The chart shows that Qwen3-8B (Baseten) achieves competitive scores at very low latency (under 200ms), while Claude Haiku 4.5 (Anthropic) achieves the highest score (around 4.5) at a much higher latency (~1500ms). GPT-OSS 20B (Groq) reaches a score near 4.3 at moderate latency (~550ms). GPT-5.4 Mini (OpenAI) scores around 4.1 at ~1200ms latency. GPT-4.1 Nano, GPT-5 Nano, and GPT-5.4 Nano (all OpenAI) cluster around scores of 3.5–3.75 at high latency. Zeta (Baseten) has the lowest score near 1.4. A group of additional Qwen3-8B scaffolds (Baseten) clusters at low latency with scores between roughly 3.1 and 3.4." width="100%" />

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
#> Rows: 20
#> Columns: 11
#> $ model              <chr> "claude-haiku-4-5-20251001", "openai/gpt-oss-20b", …
#> $ prompt             <chr> "rewrite-region", "rewrite-region", "rewrite-region…
#> $ edit_history       <chr> "narrative", "narrative", "narrative", "narrative",…
#> $ output_format      <chr> "rewrite_region", "rewrite_region", "rewrite_region…
#> $ n_completions      <int> 80, 80, 85, 85, 240, 240, 85, 80, 80, 240, 240, 240…
#> $ n_processable      <int> 80, 80, 85, 85, 240, 240, 84, 80, 80, 240, 240, 240…
#> $ n_exact            <int> 54, 46, 55, 54, 123, 123, 44, 32, 30, 120, 114, 111…
#> $ mean_score         <dbl> 4.49, 4.28, 4.11, 4.07, 4.03, 3.96, 3.75, 3.52, 3.5…
#> $ median_latency_ms  <dbl> 1476, 550, 1138, 1034, 144, 144, 1228, 1370, 1576, …
#> $ mean_input_tokens  <dbl> 1358, 1050, 1335, 1133, 1181, 1155, 1139, 1128, 112…
#> $ mean_output_tokens <dbl> 140, 169, 128, 109, 108, 107, 111, 95, 119, 219, 21…
```
