#!/usr/bin/env bats

load helpers
load common_vars
load utils


SUITE_NAME=stores.iso


@test "stores.iso: Add iso" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<"${#ISOS[@]}"; i++)); do
        iso_path="${ISOS[$i]}"
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        rm -rf "$BATS_TMPDIR/myrepo"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$iso_path"
        helpers.is_file "$repo/$expected_path"
    done
}


@test "stores.iso: Add iso to an existing repo" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage --verbose "$repo" \
        add "$BATS_TEST_DIRNAME/${ISOS[0]}"
    repoman_coverage --verbose "$repo" \
        add "$BATS_TEST_DIRNAME/${ISOS[1]}"
    helpers.is_file "$repo/${EXPECTED_ISO_PATHS[0]}"
    helpers.is_file "$repo/${EXPECTED_ISO_PATHS[1]}"
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
        add "$BATS_TEST_DIRNAME/${ISOS[0]}"
    helpers.is_file "$repo/${EXPECTED_ISO_PATHS[0]}"
    helpers.is_file "$repo/${EXPECTED_ISO_PATHS[0]}.md5sum"
    helpers.is_file "$repo/${EXPECTED_ISO_PATHS[0]}.md5sum.sig"
}


@test "stores.iso: Remove all but the latest from existing repo" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_isos="${#ISOS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$num_isos; i++)); do
        iso_path="${ISOS[$i]}"
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$iso_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        remove-old --keep 1
    # check that only the latest is there
    for ((i=0; i<$num_isos; i++)); do
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        if [[ "$i" == $(($num_isos - 1)) ]]; then
            helpers.is_file "$repo/$expected_path"
        else
            helpers.isnt_file "$repo/$expected_path"
        fi
    done
}


@test "stores.iso: Remove all but the latest 2 from existing repo" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_isos="${#ISOS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$num_isos; i++)); do
        iso_path="${ISOS[$i]}"
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$iso_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        remove-old --keep 2
    # check that only the latest 2 are there
    for ((i=0; i<$num_isos; i++)); do
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        if [[ "$i" -ge $(($num_isos - 2)) ]]; then
            helpers.is_file "$repo/$expected_path"
        else
            helpers.isnt_file "$repo/$expected_path"
        fi
    done
}


@test "stores.iso: When adding, leave only the latest" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_isos="${#ISOS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$(($num_isos - 1)); i++)); do
        iso_path="${ISOS[$i]}"
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$iso_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        add \
            --keep-latest 1 \
            "$BATS_TEST_DIRNAME/${ISOS[@]: -1}"
    # check that only the latest 2 are there
    for ((i=0; i<$num_isos; i++)); do
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        if [[ "$i" -eq $(($num_isos - 1)) ]]; then
            helpers.is_file "$repo/$expected_path"
        else
            helpers.isnt_file "$repo/$expected_path"
        fi
    done
}


@test "stores.iso: When adding, leave only the latest 2" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_isos="${#ISOS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$(($num_isos - 1)); i++)); do
        iso_path="${ISOS[$i]}"
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$iso_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        add \
            --keep-latest 2 \
            "$BATS_TEST_DIRNAME/${ISOS[@]: -1}"
    # check that only the latest 2 are there
    for ((i=0; i<$num_isos; i++)); do
        expected_path="${EXPECTED_ISO_PATHS[$i]}"
        if [[ "$i" -ge $(($num_isos - 2)) ]]; then
            helpers.is_file "$repo/$expected_path"
        else
            helpers.isnt_file "$repo/$expected_path"
        fi
    done
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
