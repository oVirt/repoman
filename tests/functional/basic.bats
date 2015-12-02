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
            conf:stdin
    echo "$output"
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
}


@test "basic: add mixed stdin and cli sources" {
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
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[2]}" \
            conf:stdin
    echo "$output"
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[2]}"
}



@test "basic: When adding with keep-latest and noop, don't remove anything" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$(($num_rpms - 1)); i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        --noop \
        add \
            --keep-latest 1 \
            "$BATS_TEST_DIRNAME/${ALL_RPMS[@]: -1}"
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$unexpected_path"
    done
}


@test "basic: When running remove-old with noop, don't actually remove" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$num_rpms; i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        --noop \
        remove-old --keep 1
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$unexpected_path"
    done
}


@test "basic: Work with 'conf:' sources" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    conf_source_file="$BATS_TMPDIR/conf_source_file.conf"
    rm -rf "$conf_source_file"
    for rpm in "${ALL_RPMS[@]}"; do
        echo "$BATS_TEST_DIRNAME/$rpm" >> "$conf_source_file"
    done
    helpers.run repoman_coverage "$repo" add "conf:$conf_source_file"
    echo "$output"
    helpers.equals "$status" "0"
    for expected_path in "${ALL_EXPECTED_RPM_PATHS[@]}"; do
        helpers.is_file "$repo/$expected_path"
    done
}


@test "basic: add package to new repo with suffix (included name sanity)" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    repo_suffixed="$repo.my_extra__dummy___suffix"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[1]}" \
            'repo-suffix:.my_extra_/dummy/&^suffix'
    echo "$output"
    helpers.is_file "$repo_suffixed/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
}


@test "basic: add package to existing repo with suffix (included name sanity)" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    repo_suffixed="$repo.my_extra__dummy___suffix"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo" "$repo_suffixed"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[0]}"
    repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[1]}" \
            'repo-suffix:.my_extra_/dummy/&^suffix'
    echo "$output"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.isnt_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
    helpers.is_file "$repo_suffixed/${UNSIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo_suffixed/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
}



@test "basic: gather coverage data" {
    helpers.run utils.gather_coverage \
    "$SUITE_NAME" \
    "$BATS_TEST_DIRNAME" \
    "$OUT_DIR"
    echo "$output"
    helpers.equals "$status" 0
}
