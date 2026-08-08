# Suppress booksetup's own progress messages (chapter/chunk one-liners) when
# running a generated data-generation script inside tests, so test output
# stays clean. Real errors/conditions still propagate normally, so
# expect_error()/expect_warning() continue to work as expected.
quiet_source <- function(path, ...) {
  suppressMessages(source(path, local = new.env(), echo = FALSE, ...))
}
