# Global Reading Rules

- If Korean text or paths appear mojibake/garbled after reading a file, immediately re-read the file explicitly as UTF-8 before summarizing or acting on it.

## Test Safety Rules

- For bug fixes, first identify or add a focused regression test that reproduces the bug, then make it pass.
- For validation work, test both invalid inputs and successful paths.
- For refactors, verify behavior before and after the change when feasible.
- Keep changes surgical so unrelated tests are not affected.
- Do not refactor, reformat, or clean adjacent code unless required for the task.
- Remove imports, variables, functions, or files made unused by your own changes.
- Run the smallest relevant test first, then broaden only when risk or touched surface warrants it.
- Treat terminal mojibake as suspicious. If Korean text or paths look garbled, re-read the file explicitly as UTF-8 before editing.
- Before changing suspected broken Korean or emoji strings, verify the actual UTF-8 contents.
- Loop independently until success criteria are verified.

## Godot CLI Test Safety

- Use `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter <test_file>` for focused Godot CLI tests.
- Use `powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1` for the full Godot CLI suite.
- Do not bypass the runner for routine tests.
- Do not run multiple raw Godot headless commands in parallel on Windows.
- Avoid raw Godot invocations. If unavoidable, always include `--disable-crash-handler` and a unique `--log-file tmp\godot-logs\<test-name>.log`.
- Treat `Failed to read the root certificate store` as non-fatal; use the runner output and process exit code as source of truth.
