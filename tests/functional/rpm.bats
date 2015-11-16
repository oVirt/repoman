#!/usr/bin/env bats

load helpers
load common_vars
load utils


SUITE_NAME=stores.rpm
UNSIGNED_RPM=fixtures/unsigned_rpm-1.0-1.fc21.x86_64.rpm
UNSIGNED_RPM_EXPECTED_PATH=rpm/fc21/x86_64/unsigned_rpm-1.0-1.fc21.x86_64.rpm
UNSIGNED_RPM2=fixtures/unsigned_rpm-1.0-2.fc21.x86_64.rpm
UNSIGNED_RPM2_EXPECTED_PATH=rpm/fc21/x86_64/unsigned_rpm-1.0-2.fc21.x86_64.rpm
UNSIGNED_RPM3=fixtures/unsigned_rpm-1.0-1.fc22.x86_64.rpm
UNSIGNED_RPM3_EXPECTED_PATH=rpm/fc22/x86_64/unsigned_rpm-1.0-1.fc22.x86_64.rpm
SIGNED_RPM=fixtures/signed_rpm-1.0-1.fc21.x86_64.rpm
SIGNED_RPM_EXPECTED_PATH=rpm/fc21/x86_64/signed_rpm-1.0-1.fc21.x86_64.rpm
NO_DISTRO_RPM=fixtures/unsigned_rpm-1.0-1.x86_64.rpm
ALL_DISTRO_RPM_EXPECTED_PATH=rpm/fc21/x86_64/unsigned_rpm-1.0-1.x86_64.rpm
ALL_DISTRO_RPM2_EXPECTED_PATH=rpm/fc22/x86_64/unsigned_rpm-1.0-1.x86_64.rpm
UNSIGNED_SRPM=fixtures/unsigned_rpm-1.0-1.fc21.src.rpm
UNSIGNED_SRPM_EXPECTED_PATH=rpm/fc21/SRPMS/unsigned_rpm-1.0-1.fc21.src.rpm
UNSIGNED_SRPM2=fixtures/unsigned_rpm-1.1-1.fc21.src.rpm
UNSIGNED_SRPM2_EXPECTED_PATH=rpm/fc21/SRPMS/unsigned_rpm-1.1-1.fc21.src.rpm
SIGNED_SRPM=fixtures/signed_rpm-1.0-1.fc21.src.rpm
SIGNED_SRPM_EXPECTED_PATH=rpm/fc21/SRPMS/signed_rpm-1.0-1.fc21.src.rpm
SOURCE_REPO1=fixtures/testdir1
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


@test "stores.rpm: Add simple unsigned rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$UNSIGNED_RPM"
    helpers.is_file "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
}

@test "stores.rpm: Add simple signed rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
}

@test "stores.rpm: Add simple signed rpm to existing repo" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
}

@test "stores.rpm: Fail when adding rpm without distro" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    helpers.run repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "1"
    helpers.contains "$output" 'Unknown distro'
}

@test "stores.rpm: Warn when adding rpm without distro if option passed" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    helpers.run repoman_coverage \
        -v "$repo" \
        --option store.RPMStore.on_wrong_distro=warn \
        add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "0"
    ! helpers.contains "$output" 'Unknown distro'
    helpers.contains "$output" 'Malformed release string'
}

@test "stores.rpm: Add rpm to all the distros if option passed when dst repo has distros" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    repoman_coverage -v "$repo" \
        add \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM" \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM3"
    helpers.is_file "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$UNSIGNED_RPM3_EXPECTED_PATH"
    helpers.run repoman_coverage \
        -v "$repo" \
        --option store.RPMStore.on_wrong_distro=copy_to_all \
        add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "0"
    tree "$repo"
    ! helpers.contains "$output" 'Unknown distro'
    ! helpers.contains "$output" 'Malformed release string'
    helpers.is_file "$repo/$ALL_DISTRO_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$ALL_DISTRO_RPM2_EXPECTED_PATH"
}

@test "stores.rpm: Add rpm to all the distros if option passed when dst repo has no distros but added with another rpm with distros" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    repoman_coverage -v "$repo" add
    helpers.run repoman_coverage \
        -v "$repo" \
        --option store.RPMStore.on_wrong_distro=copy_to_all \
        add \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM" \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM3" \
            "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "0"
    tree "$repo"
    ! helpers.contains "$output" 'Unknown distro'
    ! helpers.contains "$output" 'Malformed release string'
    helpers.is_file "$repo/$ALL_DISTRO_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$ALL_DISTRO_RPM2_EXPECTED_PATH"
    helpers.is_file "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$UNSIGNED_RPM3_EXPECTED_PATH"
}

@test "stores.rpm: Fail if rpm should go to all distros, but no distros in the repo or no other rpms" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    helpers.run repoman_coverage \
        -v "$repo" \
        --option store.RPMStore.on_wrong_distro=copy_to_all \
            add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "1"
    ! helpers.contains "$output" 'Unknown distro'
    ! helpers.contains "$output" 'Malformed release string'
    helpers.contains \
        "$output" \
        'No distros found in the repo and no packages with any distros added.'
}

@test "stores.rpm: Add simple unsigned srpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$UNSIGNED_SRPM"
    helpers.is_file "$repo/$UNSIGNED_SRPM_EXPECTED_PATH"
}

@test "stores.rpm: Add simple signed srpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_SRPM"
    helpers.is_file "$repo/$SIGNED_SRPM_EXPECTED_PATH"
}

@test "stores.rpm: Don't add srcrpm if conf says not to" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    cat > "$conf" <<EOC
[store.RPMStore]
with_srcrpms=False
EOC
    helpers.run repoman_coverage \
        -v \
        --config "$conf" \
        "$repo" \
            add "dir:$BATS_TEST_DIRNAME/$SOURCE_REPO1" \
    helpers.equals "$status" "0"
    ! find "$repo/$SIGNED_SRPM_EXPECTED_PATH" -iname '*.src.rpm'
}

@test "stores.rpm: Generate metadata only once" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$BATS_TMPDIR/myrepo"
    helpers.run repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.equals "$status" "0"
    helpers.contains "$output" '^.*(Creating metadata.*)$'
    ! helpers.contains "$output" '^.*(Creating metadata.*){2}$'
}

@test "stores.rpm: Add and sign one rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage \
        -v \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$UNSIGNED_RPM"
    helpers.run rpm -qpi "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
    helpers.equals "$status" "0"
    helpers.contains "$output" "^.*Key ID $PGP_ID.*\$"
}

@test "stores.rpm: Add and sign one srpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    helpers.run repoman_coverage \
        -v \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "$BATS_TEST_DIRNAME/$UNSIGNED_SRPM"
    helpers.equals "$status" "0"
    helpers.run rpm -qpi "$repo/$UNSIGNED_SRPM_EXPECTED_PATH"
    helpers.equals "$status" "0"
    helpers.contains "$output" "^.*Key ID $PGP_ID.*\$"
}

@test "stores.rpm: Add and sign one srpm with src generation" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage \
        -v \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        --with-sources \
        add "$BATS_TEST_DIRNAME/$FULL_SRPM"
    for gen_file in "${FULL_SRPM_FILES}"; do
        echo "Checking $gen_file"
        helpers.is_file "$repo/src/$FULL_SRPM_NAME/$gen_file"
        echo "Checking $gen_file.sig"
        helpers.is_file "$repo/src/$FULL_SRPM_NAME/$gen_file.sig"
    done
}

@test "stores.rpm: Add one srpm with src generation without signatures" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    repoman_coverage \
        -v \
        "$repo"  \
        --with-sources \
        add "$BATS_TEST_DIRNAME/$FULL_SRPM"
    for gen_file in "${FULL_SRPM_FILES}"; do
        echo "Checking $gen_file"
        helpers.is_file "$repo/src/$FULL_SRPM_NAME/$gen_file"
        echo "Checking that $gen_file.sig waas not generated"
        ! helpers.is_file "$repo/src/$FULL_SRPM_NAME/$gen_file.sig"
    done
}


@test "stores.rpm: Create relative symlinks" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    cat > "$conf" <<EOC
[store.RPMStore]
extra_symlinks=
    one:two,
    three:four
EOC
    repoman_coverage \
        -v \
        --config "$conf" \
        "$repo" \
            add \
                "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
    helpers.is_link "$repo/two"
    helpers.is_link "$repo/four"
    two_dst="$(readlink "$repo/two")"
    helpers.equals "one" "$two_dst"
    four_dst="$(readlink "$repo/four")"
    helpers.equals "three" "$four_dst"
}


@test "stores.rpm: Warn if symlink path exists or origin does not" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    cat > "$conf" <<EOC
[store.RPMStore]
extra_symlinks=idontexist:imalink,rpm:imalink
EOC
    helpers.run repoman_coverage \
        -v \
        --config "$conf" \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
    helpers.is_link "$repo/imalink"
    link_dst="$(readlink "$repo/imalink")"
    helpers.equals "$repo/idontexist" "$repo/$link_dst"
    helpers.contains \
        "$output" \
        '^.*WARNING:.*The link points to non-existing path.*$'
    helpers.contains \
        "$output" \
        '^.*WARNING:.*Path for the link already exists.*$'
}


@test "stores.rpm: use custom rpm dir name" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    cat > "$conf" <<EOC
[store.RPMStore]
rpm_dir=custom_name
EOC
    helpers.run repoman_coverage \
        -v \
        --config "$conf" \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATH/rpm/custom_name}"
}


@test "stores.rpm: use no rpm subdirectoy" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    cat > "$conf" <<EOC
[store.RPMStore]
rpm_dir=
EOC
    helpers.run repoman_coverage \
        -v \
        --config "$conf" \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATH#rpm/}"
}


@test "stores.rpm: add package to existing repo" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$SIGNED_RPM"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM2"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/$UNSIGNED_RPM2_EXPECTED_PATH"
}


@test "stores.rpm: add package to existing repo, passed through stdin" {
    local repo \
        conf
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    conf="$BATS_TMPDIR/conf"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/$UNSIGNED_RPM"
    helpers.equals "$status" '0'
    echo -e\
        "$BATS_TEST_DIRNAME/$SIGNED_RPM" \
        "\n" \
        "$BATS_TEST_DIRNAME/$UNSIGNED_RPM2" \
    | repoman_coverage \
        -v \
        "$repo" \
            add \
            --read-sources-from-stdin
    helpers.is_file "$repo/$SIGNED_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$UNSIGNED_RPM_EXPECTED_PATH"
    helpers.is_file "$repo/$UNSIGNED_RPM2_EXPECTED_PATH"
}


@test "stores.rpm: gather coverage data" {
    helpers.run utils.gather_coverage \
    "$SUITE_NAME" \
    "$BATS_TEST_DIRNAME" \
    "$OUT_DIR" \
    "stores/RPM/*"
    echo "$output"
    helpers.equals "$status" 0
}
