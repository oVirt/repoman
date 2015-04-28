#!/usr/bin/env bats

ISO_PATH="fixtures/dummy-project-1.2.3.iso"
EXPECTED_ISO_PATH="iso/dummy-project/1.2.3/dummy-project-1.2.3.iso"
EXPECTED_ISO_MD5_PATH="${EXPECTED_ISO_PATH}.md5sum"
EXPECTED_ISO_SIG_PATH="${EXPECTED_ISO_MD5_PATH}.sig"
PGP_KEY=fixtures/my_key.asc
PGP_PASS=123456
PGP_ID=bedc9c4be614e4ba


@test "iso: Add iso" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" add "$BATS_TEST_DIRNAME/$ISO_PATH"
    [[ -f "$repo/$EXPECTED_ISO_PATH" ]]
}

@test "iso: Add and sign iso" {
    local repo
    load utils
    if [[ "$(utils.distro)" == "Fedora 22" ]]; then
        skip
    fi
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$ISO_PATH"
    [[ -f "$repo/$EXPECTED_ISO_PATH" ]]
    [[ -f "$repo/$EXPECTED_ISO_MD5_PATH" ]]
    [[ -f "$repo/$EXPECTED_ISO_SIG_PATH" ]]
}
