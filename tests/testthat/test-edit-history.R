simple_edit_history <- paste0(
  "Edit 1 (2025-01-01T00:00:00.000Z):\n",
  "file.py\n",
  "@@ -1,3 +1,3 @@\n",
  " a\n",
  "-b\n",
  "+B\n",
  " c"
)

two_edit_history <- paste0(
  "Edit 1 (2025-01-01T00:00:00.000Z):\n",
  "file.py\n",
  "@@ -1,3 +1,3 @@\n",
  " a\n",
  "-b\n",
  "+B\n",
  " c\n",
  "\n",
  "Edit 2 (2025-01-01T00:00:01.000Z):\n",
  "file.py\n",
  "@@ -1,3 +1,3 @@\n",
  " a\n",
  "-B\n",
  "+Bx\n",
  " c"
)

insertion_history <- paste0(
  "Edit 1 (2025-01-01T00:00:00.000Z):\n",
  "file.py\n",
  "@@ -1,2 +1,3 @@\n",
  " a\n",
  "+new line\n",
  " b"
)

deletion_history <- paste0(
  "Edit 1 (2025-01-01T00:00:00.000Z):\n",
  "file.py\n",
  "@@ -1,3 +1,2 @@\n",
  " a\n",
  "-old line\n",
  " b"
)

# parse_edit_history ---------------------------------------------------------

test_that("parse_edit_history parses a single edit", {
  edits <- parse_edit_history(simple_edit_history)
  expect_length(edits, 1)
  expect_equal(edits[[1]]$edit_num, "1")
  expect_equal(edits[[1]]$filename, "file.py")
  expect_length(edits[[1]]$parsed_lines, 4)
})

test_that("parse_edit_history parses multiple edits", {
  edits <- parse_edit_history(two_edit_history)
  expect_length(edits, 2)
  expect_equal(edits[[1]]$edit_num, "1")
  expect_equal(edits[[2]]$edit_num, "2")
})

test_that("parse_edit_history strips header prefix", {
  with_header <- paste0(
    "## Edit History\n\n",
    "The following are the latest edits made by the user, from earlier to later.\n\n",
    simple_edit_history
  )
  edits <- parse_edit_history(with_header)
  expect_length(edits, 1)
  expect_equal(edits[[1]]$edit_num, "1")
})

test_that("parse_edit_history handles fenced format", {
  fenced <- paste0(
    "Edit 1 (2025-01-01T00:00:00.000Z):\n",
    "```file.py\n",
    "@@ -1,3 +1,3 @@\n",
    " a\n",
    "-b\n",
    "+B\n",
    " c\n",
    "```"
  )
  edits <- parse_edit_history(fenced)
  expect_length(edits, 1)
  expect_equal(edits[[1]]$filename, "file.py")
  expect_length(edits[[1]]$parsed_lines, 4)
})

test_that("parse_edit_history extracts timestamps", {
  edits <- parse_edit_history(simple_edit_history)
  expect_equal(edits[[1]]$timestamp, "2025-01-01T00:00:00.000Z")
})

test_that("parse_edit_history classifies line types", {
  edits <- parse_edit_history(simple_edit_history)
  types <- vapply(edits[[1]]$parsed_lines, \(x) x$type, character(1))
  expect_equal(types, c("context", "removed", "added", "context"))
})

# trim_to_context ------------------------------------------------------------

test_that("trim_to_context keeps lines around changes", {
  edits <- parse_edit_history(simple_edit_history)
  trimmed <- trim_to_context(edits[[1]]$parsed_lines, context_lines = 1L)
  expect_length(trimmed, 4)
})

test_that("trim_to_context with zero context keeps only changes", {
  edits <- parse_edit_history(simple_edit_history)
  trimmed <- trim_to_context(edits[[1]]$parsed_lines, context_lines = 0L)
  types <- vapply(trimmed, \(x) x$type, character(1))
  expect_true(all(types %in% c("removed", "added")))
})

test_that("trim_to_context handles empty input", {
  expect_length(trim_to_context(list(), 1L), 0)
})

# before_lines / after_lines ------------------------------------------------

test_that("before_lines excludes added lines", {
  edits <- parse_edit_history(simple_edit_history)
  result <- before_lines(edits[[1]]$parsed_lines)
  expect_equal(result, c("a", "b", "c"))
})

test_that("after_lines excludes removed lines", {
  edits <- parse_edit_history(simple_edit_history)
  result <- after_lines(edits[[1]]$parsed_lines)
  expect_equal(result, c("a", "B", "c"))
})

# describe_edit --------------------------------------------------------------

test_that("describe_edit detects typing extension", {
  expect_equal(describe_edit("ho", "hol"), 'typed `l`')
  expect_equal(describe_edit("x", "xyz"), 'typed `yz`')
})

test_that("describe_edit detects removal from end", {
  expect_equal(describe_edit("hello", "hel"), 'removed `lo` from the end')
})

test_that("describe_edit detects replacement", {
  expect_equal(describe_edit("foo", "bar"), 'changed `foo` to `bar`')
})

test_that("describe_edit detects pure addition", {
  expect_equal(describe_edit(character(), "new line"), 'added `new line`')
})

test_that("describe_edit detects pure removal", {
  expect_equal(describe_edit("old line", character()), 'removed `old line`')
})

test_that("describe_edit handles multi-line changes", {
  result <- describe_edit(c("a", "b"), c("x", "y", "z"))
  expect_equal(result, "added 3 lines and removed 2 lines")
})

test_that("describe_edit handles multi-line addition only", {
  result <- describe_edit(character(), c("x", "y"))
  expect_equal(result, "added 2 lines")
})

test_that("describe_edit handles multi-line removal only", {
  result <- describe_edit(c("x", "y"), character())
  expect_equal(result, "removed 2 lines")
})

test_that("describe_edit handles no changes", {
  expect_equal(describe_edit(character(), character()), "made no changes")
})

test_that("describe_edit singular line counts", {
  result <- describe_edit(c("a", "b"), c("x"))
  expect_equal(result, "added 1 line and removed 2 lines")
})

# format_edit_history_diffs --------------------------------------------------

test_that("format_edit_history_diffs wraps with header", {
  result <- format_edit_history_diffs(simple_edit_history)
  expect_match(result, "^## Edit History")
  expect_match(result, "from earlier to later")
  expect_match(result, "```file.py", fixed = TRUE)
})

test_that("format_edit_history_diffs returns empty for NULL", {
  expect_equal(format_edit_history_diffs(NULL), "")
  expect_equal(format_edit_history_diffs(""), "")
})

# format_edit_history_before_after -------------------------------------------

test_that("format_edit_history_before_after produces before/after blocks", {
  result <- format_edit_history_before_after(simple_edit_history)
  expect_match(result, "Before:")
  expect_match(result, "After:")
  expect_match(result, "### Edit 1:")
})

test_that("format_edit_history_before_after omits redundant before", {
  result <- format_edit_history_before_after(two_edit_history)
  before_count <- length(gregexpr("Before:", result)[[1]])
  after_count <- length(gregexpr("After:", result)[[1]])
  expect_equal(before_count, 1)
  expect_equal(after_count, 2)
})

test_that("format_edit_history_before_after returns empty for NULL", {
  expect_equal(format_edit_history_before_after(NULL), "")
  expect_equal(format_edit_history_before_after(""), "")
})

# format_edit_history_narrative ----------------------------------------------

test_that("format_edit_history_narrative describes single edit", {
  result <- format_edit_history_narrative(simple_edit_history)
  expect_match(result, "code started like this")
  expect_match(result, "Most recently")
})

test_that("format_edit_history_narrative handles multiple edits", {
  result <- format_edit_history_narrative(two_edit_history)
  expect_match(result, "code started like this")
  expect_match(result, "Then, the user changed")
  expect_match(result, "Most recently, the user typed")
})

test_that("format_edit_history_narrative returns empty for NULL", {
  expect_equal(format_edit_history_narrative(NULL), "")
  expect_equal(format_edit_history_narrative(""), "")
})

test_that("format_edit_history_narrative describes insertion", {
  result <- format_edit_history_narrative(insertion_history)
  expect_match(result, "added `new line`")
})

test_that("format_edit_history_narrative describes deletion", {
  result <- format_edit_history_narrative(deletion_history)
  expect_match(result, "removed `old line`")
})

test_that("format_edit_history_narrative uses 5-backtick fence", {
  result <- format_edit_history_narrative(simple_edit_history, fence = "`````")
  expect_match(result, "`````", fixed = TRUE)
  lines <- strsplit(result, "\n")[[1]]
  fence_lines <- grep("^`+$", lines, value = TRUE)
  expect_true(all(fence_lines == "`````"))
})

# format_edit_history dispatcher ---------------------------------------------

test_that("format_edit_history dispatches to diffs", {
  result <- format_edit_history(simple_edit_history, "diffs")
  expect_match(result, "^## Edit History")
})

test_that("format_edit_history dispatches to before_after", {
  result <- format_edit_history(simple_edit_history, "before_after")
  expect_match(result, "Before:")
})

test_that("format_edit_history dispatches to narrative", {
  result <- format_edit_history(simple_edit_history, "narrative")
  expect_match(result, "code started like this")
})

test_that("format_edit_history errors on invalid format", {
  expect_error(format_edit_history(simple_edit_history, "invalid"))
})

# snapshots ------------------------------------------------------------------

test_that("format_edit_history_diffs snapshot with real sample", {
  input <- samples$input[[1]]
  expect_snapshot(cat(format_edit_history_diffs(input$edit_history)))
})

test_that("format_edit_history_before_after snapshot with real sample", {
  input <- samples$input[[1]]
  expect_snapshot(cat(format_edit_history_before_after(input$edit_history)))
})

test_that("format_edit_history_narrative snapshot with real sample", {
  input <- samples$input[[1]]
  expect_snapshot(cat(format_edit_history_narrative(input$edit_history)))
})

test_that("format_edit_history_diffs snapshot with real sample 2", {
  input <- samples$input[[2]]
  expect_snapshot(cat(format_edit_history_diffs(input$edit_history)))
})

test_that("format_edit_history_before_after snapshot with real sample 2", {
  input <- samples$input[[2]]
  expect_snapshot(cat(format_edit_history_before_after(input$edit_history)))
})

test_that("format_edit_history_narrative snapshot with real sample 2", {
  input <- samples$input[[2]]
  expect_snapshot(cat(format_edit_history_narrative(input$edit_history)))
})

