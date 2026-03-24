# 0.5.0

The concurrency update, adds additional options for concurrency handling as well as support for custom file extension that should be treated as commands.

* Added `Config#allowed_extensions` which defaults to `["", ".sh", ".rb", ".pl", ".py"]`.
  * `""` is a special case which allows extension-less commands
* Improved `environment` file format and handling
  * `#` is now supported for comments
  * Blank lines no longer crash (blank being empty, or only containing spaces or newlines)
  * Lines which only contain a key are now treated as an error, it MUST take the form KEY=VALUE
  * Values which contain = are now properly handled with a less-greedy split
* Added `-v` and `--version` flag
* Added `-g N` and `--group N` flag, when paired with `jobs`, allows running specific commands in serial rather than parallel, in reality it locks all jobs that match the pattern on the same thread where possible.
* Added `-j N` and `--jobs N` flag, controls the number of threads used for parallel execution
* Added `--max-buffer-size N` and `--buffer-size N` to control IO buffering, these don't normally need to be fiddled with but are provided since they were used for testing
* Added some tests for new features and ensure regressions are being accounted for
* Added `EXEC_PATH` environment variable which tracks the original working directory where tachi was executed in the `tachi` shim.

# 0.4.0

* Added support for `{segment,segment2,segmentN}` in command paths
  * Example: `env.prod.component.{api,worker}.upgrade` will expand the command to run upgrade for both api and worker
