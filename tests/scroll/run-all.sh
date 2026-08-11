#!/usr/bin/env bash
# Run all scroll-redesign PHP CLI tests inside the Docker container.
# Usage: bash tests/scroll/run-all.sh
set -e
cd "$(dirname "$0")"
fail=0
for t in test_*.php; do
	[ -f "$t" ] || continue
	echo ">> $t"
	docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php "$t" || fail=1
done
exit $fail
