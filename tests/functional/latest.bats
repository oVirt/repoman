#!/usr/bin/env bats

load helpers


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


@test "filter.latest: Simple latest filter" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO1"
    helpers.run repoman \
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


@test "filter.latest: latest=2 filter" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO1"
    helpers.run repoman \
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


@test "filter.latest: Make sure that it ignores src.rpms when calculating the latest, but pulls the src.rpm of the selected latest rpm" {
    local repo \
        conf
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    tree "$LATEST_REPO2"
    helpers.run repoman \
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
