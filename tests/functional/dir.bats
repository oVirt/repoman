#!/usr/bin/env bats

load helpers

TEST_DIR1=fixtures/testdir1
TEST_DIR2=fixtures/testdir2
TEST_DIR1_EXPECTED_PATHS=(
    rpm/fc21/x86_64/unsigned_rpm-1.1-1.fc21.x86_64.rpm
    rpm/fc21/x86_64/signed_rpm-1.0-1.fc21.x86_64.rpm
    rpm/fc21/SRPMS/signed_rpm-1.0-1.fc21.src.rpm
    iso/dummy-project/1.2.3/dummy-project-1.2.3.iso
)


@test "source.dir: Add simple dir" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman --verbose "$repo" add "dir:$BATS_TEST_DIRNAME/$TEST_DIR1"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}


@test "source.dir: Add recursively a dir, full path" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman --verbose "$repo" add "dir:$BATS_TEST_DIRNAME/$TEST_DIR2"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}


@test "source.dir: Add recursively a dir, relative path" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    cd "$BATS_TEST_DIRNAME"
    repoman --verbose "$repo" add "dir:$TEST_DIR2"
    for artifact in "${TEST_DIR1_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$artifact"
    done
}
