# Scroll redesign tests

Lightweight PHP CLI assertions for the scroll redesign work.

Run all: `bash tests/scroll/run-all.sh` (must run from project root, container must be up).
Run one: `docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_xxx.php`

Tests are intentionally simple — input/output validation of primitives + manifest schema. Visual regression CI lives in Plan 3.

## Helpers

- `lib/assert.php` — assert_true / assert_equals / assert_in_array / assert_file_exists_msg / test_section
- `lib/brace_edit.py` — Python brace-balanced block extractor for refactor scripts (used by Plan 3 tasks)

## Snapshot output

Snapshots written by `test_php_render.php` and `test_snapshots.php` go to `tests/scroll/snapshots/` and `tests/scroll/snapshots-current/` (gitignored). Baselines for visual regression in `tests/scroll/snapshots-baseline/` (committed).
