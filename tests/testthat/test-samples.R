test_that("parse_excerpt splits on region markers", {
  excerpt <- paste0(
    "prefix\n",
    "<|editable_region_start|>\n",
    "editable line\n",
    "<|editable_region_end|>\n",
    "suffix"
  )
  res <- parse_excerpt(excerpt)
  expect_equal(res$prefix, "prefix\n")
  expect_equal(res$editable, "editable line")
  expect_equal(res$suffix, "\nsuffix")
})

test_that("parse_excerpt handles missing markers", {
  res <- parse_excerpt("no markers here")
  expect_equal(res$prefix, "no markers here")
  expect_equal(res$editable, "")
  expect_equal(res$suffix, "")
})

test_that("parse_excerpt handles marker on same line as content", {
  excerpt <- paste0(
    "before\n",
    "<|editable_region_start|>code here",
    "<|editable_region_end|>\n",
    "after"
  )

  res <- parse_excerpt(excerpt)
  expect_equal(res$prefix, "before\n")
  expect_equal(res$editable, "code here")
  expect_equal(res$suffix, "\nafter")
})

test_that("extract_region_text extracts between markers", {
  text <- "<|editable_region_start|>\nline 1\nline 2\n<|editable_region_end|>"
  expect_equal(extract_region_text(text), "line 1\nline 2")
})

test_that("extract_region_text returns input when no markers", {
  expect_equal(extract_region_text("plain text"), "plain text")
})

test_that("compute_line_status identifies equal lines", {
  res <- compute_line_status(c("a", "b", "c"), c("a", "b", "c"))
  expect_equal(res$a_status, c("equal", "equal", "equal"))
  expect_equal(res$b_status, c("equal", "equal", "equal"))
})

test_that("compute_line_status identifies all removed", {
  res <- compute_line_status(c("a", "b"), character())
  expect_equal(res$a_status, c("removed", "removed"))
  expect_equal(res$b_status, character())
})

test_that("compute_line_status identifies all added", {
  res <- compute_line_status(character(), c("x", "y"))
  expect_equal(res$a_status, character())
  expect_equal(res$b_status, c("added", "added"))
})

test_that("compute_line_status handles empty inputs", {
  res <- compute_line_status(character(), character())
  expect_equal(res$a_status, character())
  expect_equal(res$b_status, character())
})

test_that("compute_line_status identifies contiguous change", {
  res <- compute_line_status(
    c("a", "b", "c", "d"),
    c("a", "X", "Y", "d")
  )
  expect_equal(res$a_status, c("equal", "removed", "removed", "equal"))
  expect_equal(res$b_status, c("equal", "added", "added", "equal"))
})

test_that("compute_line_status identifies insertion", {
  res <- compute_line_status(
    c("a", "b"),
    c("a", "X", "b")
  )
  expect_equal(res$a_status, c("equal", "equal"))
  expect_equal(res$b_status, c("equal", "added", "equal"))
})

test_that("compute_line_status identifies deletion", {
  res <- compute_line_status(
    c("a", "X", "b"),
    c("a", "b")
  )
  expect_equal(res$a_status, c("equal", "removed", "equal"))
  expect_equal(res$b_status, c("equal", "equal"))
})

test_that("render_diff_lines marks removed and added lines", {
  html <- render_diff_lines(c("a", "b"), c("equal", "removed"))
  expect_match(html, "^a\n<span class=\"diff-removed\">b</span>$")
})

test_that("render_diff_lines returns empty string for no lines", {
  expect_equal(render_diff_lines(character(), character()), "")
})

test_that("render_diff_lines styles cursor marker when requested", {
  html <- render_diff_lines(
    "code<|user_cursor_is_here|>",
    "equal",
    style_cursor = TRUE
  )
  expect_match(html, "marker")
  expect_no_match(html, "<[|]user_cursor_is_here[|]>")
})

test_that("render_diff_lines leaves cursor marker unstyled by default", {
  html <- render_diff_lines("code<|user_cursor_is_here|>", "equal")
  expect_no_match(html, "marker")
})

test_that("render_diff_lines escapes HTML", {
  html <- render_diff_lines("<script>alert(1)</script>", "equal")
  expect_no_match(html, "<script>")
  expect_match(html, "&lt;script&gt;")
})

test_that("render_variables_html returns None for empty input", {
  expect_match(render_variables_html(NULL), "None")
  expect_match(render_variables_html(list()), "None")
})

test_that("render_variables_html renders a table", {
  vars <- list(
    list(name = "x", type = "numeric"),
    list(name = "df", type = "data.frame", value = "10 x 3")
  )
  html <- render_variables_html(vars)
  expect_match(html, "<table>")
  expect_match(html, "x")
  expect_match(html, "numeric")
  expect_match(html, "df")
  expect_match(html, "10 x 3")
})

test_that("render_variables_html escapes HTML in values", {
  vars <- list(list(name = "<b>", type = "a&b"))
  html <- render_variables_html(vars)
  expect_match(html, "&lt;b&gt;")
  expect_match(html, "a&amp;b")
})
