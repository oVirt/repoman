#!/usr/bin/env bats

load helpers
load utils
load common_vars

SUITE_NAME=sources.dir
TEST_DIR1=fixtures/testdir1
TEST_DIR2=fixtures/testdir2
TEST_DIR1_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    rpm/fc21/x86_64/signed_rpm-1.0-1.fc21.x86_64.rpm
    rpm/fc21/SRPMS/signed_rpm-1.0-1.fc21.src.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
)


@test "sources.dir: Add simple dir" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" add "dir:$BATS_TEST_DIRNAME/$TEST_DIR1"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}


@test "sources.dir: Add recursively a dir, full path" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" add "dir:$BATS_TEST_DIRNAME/$TEST_DIR2"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}


@test "sources.dir: Add recursively a dir, relative path" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    cd "$BATS_TEST_DIRNAME"
    repoman_coverage --verbose "$repo" add "dir:$TEST_DIR2"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}

@test "sources.dir: gather coverage data" {
    helpers.run utils.gather_coverage \
        "$SUITE_NAME" \
        "$BATS_TEST_DIRNAME" \
        "$OUT_DIR" \
        "sources/dir.py"
    echo "$output"
    helpers.equals "$status" 0
}
