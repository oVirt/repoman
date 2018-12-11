#!/usr/bin/env bats

load helpers
load common_vars
load utils


SUITE_NAME=filters.latest
LATEST_REPO1="$BATS_TEST_DIRNAME/fixtures/latest_repo1"
LATEST_REPO2="$BATS_TEST_DIRNAME/fixtures/latest_repo2"
LATEST_RPM_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    iso/dummy-project/1.4/dummy-project-1.4.iso
)
LATEST_RPM_UNEXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
)
LATEST_2_RPMS_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
    iso/dummy-project/1.4/dummy-project-1.4.iso
)
LATEST_2_RPMS_UNEXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
)
LATEST_3_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
    rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
)
LATEST_3_UNEXPECTED_PATHS=(
    rpm/fc21/SRPMS/unsigned_rpm-1.1-1.fc21.src.rpm
)
LATEST_4_RPMS_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    iso/dummy-project/1.4/dummy-project-1.4.iso
    iso/dummy-project/1.3.5-20181203/fc29/dummy-project-1.3.5-20181203.fc29.iso
    rpm/fc21/SRPMS/unsigned_rpm-1.1-1.fc21.src.rpm
)
LATEST_4_RPMS_UNEXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
    rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
    iso/dummy-project/1.2.4/dummy-project-1.2.4.iso
)


@test "filters.latest: Simple latest filter" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO1"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add "dir:$LATEST_REPO1:latest"
    helpers.equals "$status" '0'
    tree "$repo"
    for expected in "${LATEST_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${LATEST_RPM_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "filters.latest: latest=2 filter" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO1"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add "dir:$LATEST_REPO1:latest=2"
    helpers.equals "$status" '0'
    tree "$repo"
    for expected in "${LATEST_2_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${LATEST_2_RPM_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "filters.latest: Make sure that it ignores src.rpms when calculating the latest, but pulls the src.rpm of the selected latest rpm" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO2"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "dir:$LATEST_REPO2:latest"
    helpers.equals "$status" '0'
    tree "$repo"
    for expected in "${LATEST_3_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${LATEST_3_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "option.latest: Create extra latest repo if option passed" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO2"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "repo-extra-dir:first_level" \
            "repo-extra-dir:second_level1" \
            "dir:$LATEST_REPO2"
    helpers.run repoman_coverage \
        -v \
        --create-latest-repo \
        "$repo" \
            add \
            "repo-extra-dir:first_level" \
            "repo-extra-dir:second_level2" \
            "dir:$LATEST_REPO1"
    helpers.equals "$status" '0'
    tree "$repo"
    for expected in "${LATEST_4_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/first_level/latest/$expected"
    done
    for unexpected in "${LATEST_4_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/first_level/latest/$unexpected"
    done
}


@test "filters.latest: gather coverage data" {
    helpers.run utils.gather_coverage \
    "$SUITE_NAME" \
    "$BATS_TEST_DIRNAME" \
    "$OUT_DIR" \
    "filters/latest.py"
    echo "$output"
    helpers.equals "$status" 0
}
