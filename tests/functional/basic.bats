#!/usr/bin/env bats

load common_vars
load helpers
load utils

SUITE_NAME=basic
BASE_RPM=fixtures/unsigned_rpm-1.0-1.fc21.x86_64.rpm
BASE_RPM_EXPECTED_PATH=custom_name/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm


@test "basic: Command help is shown without errors" {
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    helpers.run repoman_coverage -h
    helpers.equals "$status" "0"
    helpers.contains "${output}" '^.*usage: repoman'
}

@test "basic: Wrong parameters returns error" {
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    helpers.run repoman_coverage --dontexist
    helpers.equals "$status" "2"
}

@test "basic: Conf options can be passed by command line" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose \
        --option store.RPMStore.rpm_dir=custom_name \
        "$repo" \
        add "$BATS_TEST_DIRNAME/$BASE_RPM"
    helpers.is_file "$repo/$BASE_RPM_EXPECTED_PATH"
}

@test "basic: Fail if bad conf is passed" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run \
        repoman_coverage --verbose \
            --config idontexist \
            "$repo" \
        add "$BATS_TEST_DIRNAME/$BASE_RPM"
    helpers.equals "$status" "1"
    helpers.contains "$output" "Unable to load config idontexist"
}

@test "basic: Fail if no artifacts for source string" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run \
        repoman_coverage --verbose \
            "$repo" \
            add "$BATS_TEST_DIRNAME/$BASE_RPM.idontexist"
    helpers.equals "$status" "1"
    helpers.contains "$output" "No artifacts found"
}


@test "basic: add package to new repo passed through stdin, with comments and empty lines" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    echo -e \
        "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}\n" \
        "# dummy comment\n" \
        "\n" \
        "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[1]}" \
    | repoman_coverage \
        -v \
        "$repo" \
            add \
            --read-sources-from-stdin
    echo "$output"
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
}


@test "basic: gather coverage data" {
    helpers.run utils.gather_coverage \
    "$SUITE_NAME" \
    "$BATS_TEST_DIRNAME" \
    "$OUT_DIR"
    echo "$output"
    helpers.equals "$status" 0
}
