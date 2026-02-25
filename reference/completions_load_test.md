# Replay stored completions at a fixed request rate

Send previously collected completion requests at a controlled interval.
This is useful for load testing: run against the Qwen3-8B endpoint, then
again against Zeta at the same rate, and compare GPU utilisation on
Baseten.

Requests are dispatched asynchronously using `curl`'s multi interface,
so new requests go out on schedule even when previous responses are
still in flight.

## Usage

``` r
completions_load_test(
  completions,
  model = c("qwen3-8b", "zeta"),
  interval = 0.2,
  n = NULL
)
```

## Arguments

- completions:

  A data frame returned by
  [`completions_read()`](https://posit-dev.github.io/nesevals/reference/completions_read.md)
  that contains a `request` list-column with the original request
  bodies.

- model:

  One of `"qwen3-8b"` or `"zeta"`. Determines which Baseten endpoint to
  target.

- interval:

  Target number of seconds between consecutive requests. For example,
  `0.2` sends 5 requests per second.

- n:

  Number of requests to send. Defaults to `nrow(completions)`. If `n`
  exceeds the number of stored requests, they are recycled.

## Value

Invisibly, a data frame with columns `request_index`, `scheduled_time`,
`actual_send_time`, `latency`, `tokens_input`, and `tokens_output`.
