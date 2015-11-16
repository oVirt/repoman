#!/usr/bin/env bats

load helpers
load common_vars
load utils


SUITE_NAME=filters.only_missing
ONLY_MISSING_REPO_BASE=fixtures/only_missing_repo_base
ONLY_MISSING_REPO1=fixtures/only_missing_repo1
ONLY_MISSING_REPO2=fixtures/only_missing_repo2
ONLY_MISSING_RPM_EXPECTED_PATHS1=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.4/dummy-project-1.4.iso
)
ONLY_MISSING_RPM_UNEXPECTED_PATHS1=(
    rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
)
ONLY_MISSING_RPM_EXPECTED_PATHS2=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    iso/dummy-project/1.4/dummy-project-1.4.iso
)
ONLY_MISSING_RPM_UNEXPECTED_PATHS2=(
    rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
)
ONLY_MISSING_RPM_EXPECTED_PATHS3=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.4/dummy-project-1.4.iso
)
ONLY_MISSING_RPM_UNEXPECTED_PATHS3=(
    rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
)


@test "filters.only_missing: Simple only_missing filter, all artifacts already there" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO1"
    tree "$repo"
    helpers.run \
        repoman_coverage \
            -v \
            "$repo" \
            add "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO_BASE:only-missing"
    helpers.equals "$status" "1"
    helpers.contains "$output" "No artifacts found"
    tree "$repo"
    for expected in "${ONLY_MISSING_RPM_EXPECTED_PATHS1[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${ONLY_MISSING_RPM_UNEXPECTED_PATHS1[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "filters.only_missing: Simple only_missing filter, no artifacts there yet" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$repo"
    tree "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO_BASE"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
        add "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO_BASE:only-missing"
    tree "$repo"
    for expected in "${ONLY_MISSING_RPM_EXPECTED_PATHS2[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${ONLY_MISSING_RPM_UNEXPECTED_PATHS2[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "filters.only_missing: Simple only_missing filter, mix of existing and non-existing artifacts" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO2"
    tree "$repo"
    repoman_coverage \
        -v \
        "$repo" \
        add "$BATS_TEST_DIRNAME/$ONLY_MISSING_REPO_BASE:only-missing"
    tree "$repo"
    for expected in "${ONLY_MISSING_RPM_EXPECTED_PATHS3[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${ONLY_MISSING_RPM_UNEXPECTED_PATHS3[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "filters.only_missing: gather coverage data" {
    helpers.run utils.gather_coverage \
    "$SUITE_NAME" \
    "$BATS_TEST_DIRNAME" \
    "$OUT_DIR" \
    "filters/only_missing.py"
    echo "$output"
    helpers.equals "$status" 0
}
