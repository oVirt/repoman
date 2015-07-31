#!/usr/bin/env bats

BASE_RPM=fixtures/unsigned_rpm-1.0-1.fc21.x86_64.rpm
BASE_RPM_EXPECTED_PATH=custom_name/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm

load helpers

@test "basic: Command help is shown without errors" {
    helpers.run repoman -h
    helpers.equals "$status" "0"
    helpers.contains "${output}" '^.*usage: repoman'
}

@test "basic: Wrong parameters returns error" {
    helpers.run repoman --dontexist
    helpers.equals "$status" "2"
}

@test "basic: Conf options can be passed by command line" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman \
        --option store.RPMStore.rpm_dir=custom_name \
        "$repo" \
        add "$BATS_TEST_DIRNAME/$BASE_RPM"
    helpers.is_file "$repo/$BASE_RPM_EXPECTED_PATH"
}

@test "basic: Fail if bad conf is passed" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run \
        repoman \
            --config idontexist \
            "$repo" \
        add "$BATS_TEST_DIRNAME/$BASE_RPM"
    helpers.equals "$status" "1"
    helpers.contains "$output" "Unable to load config idontexist"
}

@test "basic: Fail if no artifacts for source string" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run \
        repoman \
            "$repo" \
            add "$BATS_TEST_DIRNAME/$BASE_RPM.idontexist"
    helpers.equals "$status" "1"
    helpers.contains "$output" "No artifacts found"
}
