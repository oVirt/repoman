#!/usr/bin/env bats

load common_vars


@test "closing: gathering global coverage data" {
    rm -rf "$OUT_DIR/"coverage.total*
    cd "$OUT_DIR"
    export COVERAGE_FILE=coverage.total.db
    coverage combine coverage.*.db
    coverage report \
        --include "*site-packages/repoman*" \
        -m \
    > "coverage.total.txt"
    coverage html \
        --include "*site-packages/repoman*" \
        -d "coverage.total.html"
}
