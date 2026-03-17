library(nesevals)
library(ggplot2)
library(ggrepel)
library(ggforce)

qwen_cluster <- nes_results |>
  dplyr::filter(model == "qwen3-8b", median_latency_ms < 200, mean_score < 3.5)

qwen_cluster_2 <- nes_results |>
  dplyr::filter(model == "qwen3-8b", median_latency_ms > 200)

label_data <- nes_results |>
  dplyr::filter(model %in% c("claude-haiku-4-5-20251001", "openai/gpt-oss-20b", "qwen3-8b", "zeta",
                              "gpt-4.1-nano-2025-04-14", "gpt-5-nano", "llama3.1-8b", "gemini-3.1-flash-lite-preview",
                              "gpt-5.4-mini", "gpt-5.4-nano")) |>
  dplyr::slice_max(mean_score, by = model, n = 1) |>
  dplyr::mutate(label = dplyr::case_when(
    model == "claude-haiku-4-5-20251001" ~ "Claude Haiku 4.5 (Anthropic)",
    model == "openai/gpt-oss-20b"        ~ "GPT-OSS 20B (Groq)",
    model == "qwen3-8b"                  ~ "Qwen3-8B (Baseten)",
    model == "zeta"                      ~ "Zeta (Baseten)",
    model == "gpt-4.1-nano-2025-04-14"  ~ "GPT-4.1 Nano (OpenAI)",
    model == "gpt-5-nano"               ~ "GPT-5 Nano (OpenAI)",
    model == "llama3.1-8b"              ~ "Llama 3.1-8B (Cerebras)",
    model == "gemini-3.1-flash-lite-preview"    ~ "Gemini 3.1 Flash-Lite (Google)",
    model == "gpt-5.4-mini"             ~ "GPT-5.4 Mini (OpenAI)",
    model == "gpt-5.4-nano"             ~ "GPT-5.4 Nano (OpenAI)"
  ))

hull_label <- data.frame(
  median_latency_ms = max(qwen_cluster$median_latency_ms),
  mean_score        = mean(qwen_cluster$mean_score),
  label             = "Other Qwen3-8B\nscaffolds (Baseten)"
)

hull_label_2 <- data.frame(
  median_latency_ms = mean(qwen_cluster_2$median_latency_ms),
  mean_score        = mean(qwen_cluster_2$mean_score)
)

frontier_colors <- c(
  "claude-haiku-4-5-20251001"      = "#C95B25",
  "gpt-4.1-nano-2025-04-14"        = "#5BB8D4",
  "gpt-5-nano"                     = "#5BB8D4",
  "gpt-5.4-mini"                   = "#5BB8D4",
  "gpt-5.4-nano"                   = "#5BB8D4",
  "gemini-3.1-flash-lite-preview"  = "#3B8C5A"
)

nes_plot <- function(focus = "all") {
  fade <- "grey80"
  black <- "black"

  focused_models <- switch(focus,
    "frontier"    = c("claude-haiku-4-5-20251001", "gpt-4.1-nano-2025-04-14", "gpt-5-nano", "gemini-3.1-flash-lite-preview", "gpt-5.4-mini", "gpt-5.4-nano"),
    "boutique"    = c("openai/gpt-oss-20b", "llama3.1-8b"),
    "baseten"     = c("qwen3-8b", "zeta"),
    "zeta"        = c("zeta"),
    "qwen-other"  = c("qwen3-8b"),
    "qwen-winner" = c("qwen3-8b"),
    NULL
  )


  qwen_winner_rows <- nes_results |>
    dplyr::filter(model == "qwen3-8b") |>
    dplyr::slice_max(mean_score, n = 1)

  pt_data <- nes_results |>
    dplyr::mutate(
      is_winner = model == "qwen3-8b" &
        median_latency_ms == qwen_winner_rows$median_latency_ms[1] &
        mean_score == qwen_winner_rows$mean_score[1],
      focused = dplyr::case_when(
        focus == "all" ~ TRUE,
        focus == "qwen-winner" ~ is_winner,
        focus == "qwen-other" ~ model == "qwen3-8b" & !is_winner,
        TRUE ~ model %in% focused_models
      ),
      pt_color = dplyr::case_when(
        focus == "frontier" & model %in% names(frontier_colors) ~ frontier_colors[model],
        focused ~ black,
        TRUE ~ fade
      )
    )

  lbl_data <- label_data |>
    dplyr::mutate(
      focused = dplyr::case_when(
        focus == "all" ~ TRUE,
        focus == "qwen-winner" ~ model == "qwen3-8b",
        focus == "qwen-other" ~ FALSE,
        TRUE ~ model %in% focused_models
      ),
      lbl_color = dplyr::case_when(
        focus == "frontier" & model %in% names(frontier_colors) ~ frontier_colors[model],
        focused ~ black,
        TRUE ~ fade
      ),
      lbl_face = ifelse(model %in% c("gpt-5.4-mini", "gpt-5.4-nano"), "bold", "plain")
    )

  hull1_color <- if (focus %in% c("all", "baseten", "qwen-other")) black else fade
  hull2_color <- if (focus %in% c("all", "baseten", "qwen-other")) black else fade
  if (focus == "qwen-winner") {
    hull1_color <- fade
    hull2_color <- fade
  }
  hull_lbl_color <- if (focus %in% c("all", "baseten", "qwen-other")) black else fade
  hull_lbl <- hull_label |>
    dplyr::mutate(lbl_color = hull_lbl_color)

  set.seed(9598)

  p <- ggplot(pt_data) +
    aes(x = median_latency_ms, y = mean_score) +
    geom_mark_hull(
      data = qwen_cluster,
      expand = unit(3, "mm"),
      color = hull1_color,
      fill = NA
    ) +
    geom_mark_hull(
      data = qwen_cluster_2,
      expand = unit(3, "mm"),
      color = hull2_color,
      fill = NA
    ) +
    geom_point(aes(color = pt_color)) +
    scale_color_identity() +
    geom_text_repel(
      data = lbl_data,
      aes(label = label, color = lbl_color, fontface = lbl_face),
      max.overlaps = 20
    ) +
    geom_text_repel(
      data = hull_lbl,
      aes(label = label, color = lbl_color),
      nudge_x = 400,
      segment.curvature = -0.1,
      segment.color = hull_lbl_color
    ) +
    geom_curve(
      data = hull_label_2,
      aes(
        xend = median_latency_ms * 0.85 + (max(qwen_cluster$median_latency_ms) + 400) * 0.15,
        yend = mean_score * 0.85 + mean(qwen_cluster$mean_score) * 0.15
      ),
      x = mean(qwen_cluster_2$median_latency_ms) * 0.4 + (max(qwen_cluster$median_latency_ms) + 400) * 0.5,
      y = mean(qwen_cluster_2$mean_score) * 0.5 + mean(qwen_cluster$mean_score) * 0.5,
      curvature = 0,
      linewidth = 0.5,
      color = hull_lbl_color
    ) +
    labs(
      title = "NES Scaffold Performance vs. Latency",
      x = "Median Latency (ms)",
      y = "Mean Model-Graded Quality Score"
    ) +
    expand_limits(x = 0) +
    theme(plot.title = element_text(face = "bold"))

  p
}


p <- nes_plot("frontier") +
  labs(subtitle = "Model graded performance on an autocomplete task. Latency measures roundtrip of ~2,500\ninput tokens and ~250 output tokens. The new GPT 5.4 releases deliver better completions\nfaster than their predecessors, in the latency and quality ballpark of other frontier labs.") +
  theme_minimal()

ggsave(p, width = 7.5, height = 5.5,  file = "data-raw/viz.png")
