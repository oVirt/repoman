#!/usr/bin/env bats

UNSIGNED_RPM=fixtures/unsigned_rpm-1.0-1.fc21.x86_64.rpm
UNSIGNED_RPM_EXPECTED_PATH=rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
SIGNED_RPM=fixtures/signed_rpm-1.0-1.fc21.x86_64.rpm
SIGNED_RPM_EXPECTED_PATH=rpm/fc21/x86_64/signed_rpm-1.0-1.fc21.x86_64.rpm
NO_DISTRO_RPM=fixtures/unsigned_rpm-1.0-1.x86_64.rpm
UNSIGNED_SRPM=fixtures/unsigned_rpm-1.0-1.fc21.src.rpm
UNSIGNED_SRPM_EXPECTED_PATH=rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
SIGNED_SRPM=fixtures/signed_rpm-1.0-1.fc21.src.rpm
SIGNED_SRPM_EXPECTED_PATH=rpm/fc21/SRPMS/signed_rpm-1.0-1.fc21.src.rpm
FULL_SRPM=fixtures/kexec-tools-2.0.4-32.1.el7.src.rpm
FULL_SRPM_NAME=kexec-tools
FULL_SRPM_FILES=(
    eppic_030413.tar.gz
    kexec-tools-2.0.3-build-makedumpfile-eppic-shared-object.patch
    kexec-tools-2.0.3-disable-kexec-test.patch
    kexec-tools-2.0.4-kdump-x86-Process-multiple-Crash-kernel-in-proc-iome.patch
    kexec-tools-2.0.4-kexec-i386-Add-cmdline_add_memmap_internal-to-reduce.patch
    kexec-tools-2.0.4-makedumpfile-Add-help-and-man-message-for-help.patch
    kexec-tools-2.0.4-makedumpfile-Add-non-mmap-option-to-disable-mmap-manually.patch
    kexec-tools-2.0.4-makedumpfile-Add-vmap_area_list-definition-for-ppc-ppc64.patch
    kexec-tools-2.0.4-makedumpfile-Assign-non-printable-value-as-short-option.patch
    kexec-tools-2.0.4-makedumpfile-cache-Allocate-buffers-at-initialization-t.patch
    kexec-tools-2.0.4-makedumpfile-cache-Reuse-entry-in-pending-list.patch
    kexec-tools-2.0.4-makedumpfile-Fall-back-to-read-when-mmap-fails.patch
    kexec-tools-2.0.4-makedumpfile-Fix-max_mapnr-issue-on-system-has-over-44-b.patch
    kexec-tools-2.0.4-makedumpfile-Improve-progress-information-for-huge-memor.patch
    kexec-tools-2.0.4-makedumpfile-PATCH-Support-newer-kernels.patch
    kexec-tools-2.0.4-makedumpfile-Support-to-filter-dump-for-kernels-that-use.patch
    kexec-tools-2.0.4-makedumpfile-Understand-v3.11-rc4-dmesg.patch
    kexec-tools-2.0.4-makedumpfile-Update-pfn_cyclic-when-the-cyclic-buffer-size-.patch
    kexec-tools-2.0.4-makedumpfile-Use-divideup-to-calculate-maximum-required-bit.patch
    kexec-tools-2.0.4-Revert-kexec-include-reserved-e820-sections-in-crash.patch
    kexec-tools-2.0.4-Revert-kexec-lengthen-the-kernel-command-line-image.patch
    kexec-tools-2.0.4-vmcore-dmesg-stack-smashing-happend-in-extreme-case.patch
    kexec-tools-2.0.4-vmcore-dmesg-struct_val_u64-not-casting-u64-to-u32.patch
)
PGP_KEY=fixtures/my_key.asc
PGP_PASS=123456
PGP_ID=bedc9c4be614e4ba


@test "rpm: Add simple unsigned rpm" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" add "$BATS_TEST_DIRNAME/$UNSIGNED_RPM"
    [[ -f "$repo/$UNSIGNED_RPM_EXPECTED_PATH" ]]
}

@test "rpm: Add simple signed rpm" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    [[ -f "$repo/$SIGNED_RPM_EXPECTED_PATH" ]]
}

@test "rpm: Add rpm without distro" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    run repoman "$repo" add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    echo "$output"
    [[ "$output" =~ Unknown\ distro ]]
    [[ "$status" -eq 1 ]]
}

@test "rpm: Add simple unsigned srpm" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" add "$BATS_TEST_DIRNAME/$UNSIGNED_SRPM"
    [[ -f "$repo/$UNSIGNED_SRPM_EXPECTED_PATH" ]]
}

@test "rpm: Add simple signed srpm" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_SRPM"
    [[ -f "$repo/$SIGNED_SRPM_EXPECTED_PATH" ]]
}

@test "rpm: Don't add srcrpm if conf says not to" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    cat >> "$conf" <<EOC
[store.RPMStore]
with_srcrpms=False
EOC
    repoman \
        --config "$conf" \
        "$repo" \
            add \
                "$BATS_TEST_DIRNAME/$SIGNED_SRPM" \
                "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    ! [[ -f "$repo/$SIGNED_SRPM_EXPECTED_PATH" ]]
    [[ -f "$repo/$SIGNED_RPM_EXPECTED_PATH" ]]
}

@test "rpm: Generate metadata only once" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    run repoman "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    echo "$output"
    [[ "$output" =~ ^.*(Creating\ metadata.*)$ ]]
    ! [[ "$output" =~ ^.*(Creating\ metadata.*){2}$ ]]
}

@test "rpm: Add and sign one rpm" {
    local repo
    load utils
    if [[ "$(utils.distro)" == "Fedora 22" ]]; then
        skip
    fi
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$UNSIGNED_RPM"
    run rpm -qpi "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
    echo "$output"
    [[ "$output" =~ ^.*Key\ ID\ $PGP_ID.*$ ]]
}

@test "rpm: Add and sign one srpm" {
    local repo
    load utils
    if [[ "$(utils.distro)" == "Fedora 22" ]]; then
        skip
    fi
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$UNSIGNED_SRPM"
    run rpm -qpi "$repo/$UNSIGNED_SRPM_EXPECTED_PATH"
    echo "$output"
    [[ "$output" =~ ^.*Key\ ID\ $PGP_ID.*$ ]]
}

@test "rpm: Add and sign one srpm with src generation" {
    local repo
    load utils
    if [[ "$(utils.distro)" == "Fedora 22" ]]; then
        skip
    fi
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        --with-sources \
        add "$BATS_TEST_DIRNAME/$FULL_SRPM"
    for gen_file in "${FULL_SRPM_FILES}"; do
        echo "Checking $gen_file"
        [[ -f "$repo/src/$FULL_SRPM_NAME/$gen_file" ]]
        echo "Checking $gen_file.sig"
        [[ -f "$repo/src/$FULL_SRPM_NAME/$gen_file.sig" ]]
    done
}

@test "rpm: Add one srpm with src generation without signatures" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    repoman \
        "$repo"  \
        --with-sources \
        add "$BATS_TEST_DIRNAME/$FULL_SRPM"
    for gen_file in "${FULL_SRPM_FILES}"; do
        echo "Checking $gen_file"
        [[ -f "$repo/src/$FULL_SRPM_NAME/$gen_file" ]]
        echo "Checking that $gen_file.sig waas not generated"
        ! [[ -f "$repo/src/$FULL_SRPM_NAME/$gen_file.sig" ]]
    done
}


@test "rpm: Create symlinks" {
    local repo
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    cat >> "$conf" <<EOC
[store.RPMStore]
extra_symlinks=
    one:two,
    three:four
EOC
    repoman \
        --config "$conf" \
        "$repo" \
            add \
                "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    [[ -f "$repo/$SIGNED_RPM_EXPECTED_PATH" ]]
    [[ -L "$repo/two" ]]
    [[ -L "$repo/four" ]]
    two_dst="$(readlink "$repo/two")"
    [[ "$repo/one" == "$two_dst" ]]
    four_dst="$(readlink "$repo/four")"
    [[ "$repo/three" == "$four_dst" ]]
}

@test "rpm: Warn if symlink path exists or origin does not" {
    local repo \
        conf
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$BATS_TMPDIR/myrepo"
    cat >> "$conf" <<EOC
[store.RPMStore]
extra_symlinks=idontexist:imalink,rpm:imalink
EOC
    run repoman \
        --config "$conf" \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    echo "$output"
    [[ "$status" == '0' ]]
    [[ -f "$repo/$SIGNED_RPM_EXPECTED_PATH" ]]
    [[ -L "$repo/imalink" ]]
    link_dst="$(readlink "$repo/imalink")"
    [[ "$repo/idontexist" == "$link_dst" ]]
    [[ "$output" =~ ^.*WARNING:.*The\ link\ points\ to\ non-existing\ path.*$ ]]
    [[ "$output" =~ ^.*WARNING:.*Path\ for\ the\ link\ already\ exists.*$ ]]
}
