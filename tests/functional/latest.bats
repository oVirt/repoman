#!/usr/bin/env bats

load helpers

LATEST_REPO1=fixtures/latest_repo1
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


@test "latest: Simple latest filter" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman -v "$repo" add "$BATS_TEST_DIRNAME/$LATEST_REPO1:latest"
    tree "$repo"
    for expected in "${LATEST_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${LATEST_RPM_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}


@test "latest: latest=2 filter" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman -v "$repo" add "$BATS_TEST_DIRNAME/$LATEST_REPO1:latest=2"
    tree "$repo"
    for expected in "${LATEST_2_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected"
    done
    for unexpected in "${LATEST_2_RPM_UNEXPECTED_PATHS[@]}"; do
        helpers.not_exists "$repo/$unexpected"
    done
}
