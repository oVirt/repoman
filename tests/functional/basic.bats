#!/usr/bin/env bats

BASE_RPM=fixtures/unsigned_rpm-1.0-1.fc21.x86_64.rpm
BASE_RPM_EXPECTED_PATH=custom_name/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm

load helpers

@test "basic: Command help is shown without errors" {
    run repoman -h
    echo "$output"
    [[ $status -eq 0 ]]
    [[ ${output} =~ ^.*usage:\ repoman ]]
}

@test "basic: Wrong parameters returns error" {
    run repoman --dontexist
    echo "$output"
    [[ $status -eq 2 ]]
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
