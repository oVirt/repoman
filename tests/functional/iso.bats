#!/usr/bin/env bats

load helpers
load common_vars
load utils


SUITE_NAME=stores.iso
ISO_PATH="fixtures/dummy-project-1.2.3.iso"
EXPECTED_ISO_PATH="iso/dummy-project/1.2.3/dummy-project-1.2.3.iso"
ISO_BADPATH="fixtures/dummy-project-without-version.iso"
ISO_BADPATH_WITH_NUMBERS="fixtures/123/dummy-project-without-version.iso"
EXPECTED_ISO_MD5_PATH="${EXPECTED_ISO_PATH}.md5sum"
EXPECTED_ISO_SIG_PATH="${EXPECTED_ISO_MD5_PATH}.sig"
PGP_KEY=fixtures/my_key.asc
PGP_PASS=123456
PGP_ID=bedc9c4be614e4ba


@test "stores.iso: Add iso" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$ISO_PATH"
    helpers.is_file "$repo/$EXPECTED_ISO_PATH"
}


@test "stores.iso: Add iso to an existing repo" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$ISO_PATH"
    repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$ISO_PATH"
    helpers.is_file "$repo/$EXPECTED_ISO_PATH"
}


@test "stores.iso: Add iso with wrong name" {
    local repo \
        created_dirs
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run \
        repoman_coverage --verbose \
            "$repo" \
            add "$BATS_TEST_DIRNAME/$ISO_BADPATH"
    helpers.equals "$status" "1"
    helpers.contains "$output" "No artifacts found"
    shopt -s nullglob
    created_dirs=( "$repo"/* )
    [[ -z "$created_dirs" ]]
}


@test "stores.iso: Add iso with wrong name from a path with numbers" {
    local repo \
        created_dirs
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    mkdir -p "$BATS_TEST_DIRNAME/${ISO_BADPATH_WITH_NUMBERS%/*}"
    cp -a \
        "$BATS_TEST_DIRNAME/$ISO_BADPATH" \
        "$BATS_TEST_DIRNAME/$ISO_BADPATH_WITH_NUMBERS"
    helpers.run \
        repoman_coverage --verbose \
            "$repo" \
            add "$BATS_TEST_DIRNAME/$ISO_BADPATH_WITH_NUMBERS"
    helpers.equals "$status" "1"
    helpers.contains "$output" "No artifacts found"
    shopt -s nullglob
    created_dirs=( "$repo"/* )
    [[ -z "$created_dirs" ]]
}


@test "stores.iso: Add and sign iso" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$ISO_PATH"
    helpers.is_file "$repo/$EXPECTED_ISO_PATH"
    helpers.is_file "$repo/$EXPECTED_ISO_MD5_PATH"
    helpers.is_file "$repo/$EXPECTED_ISO_SIG_PATH"
}


@test "stores.iso: gather coverage data" {
    helpers.run utils.gather_coverage \
        "$SUITE_NAME" \
        "$BATS_TEST_DIRNAME" \
        "$OUT_DIR" \
        "stores/iso.py"
    echo "$output"
    helpers.equals "$status" 0
}
