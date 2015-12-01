#!/usr/bin/env bats

load helpers
load common_vars
load utils

SUITE_NAME=stores.rpm


@test "stores.rpm: Add simple unsigned rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<${#UNSIGNED_RPMS[@]}; i++)); do
        rpm_file="${UNSIGNED_RPMS[$i]}"
        rpm_expected_path="${UNSIGNED_RPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.is_file "$repo/$rpm_expected_path"
    done
}


@test "stores.rpm: Add simple signed rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<${#SIGNED_RPMS[@]}; i++)); do
        rpm_file="${SIGNED_RPMS[$i]}"
        rpm_expected_path="${SIGNED_RPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.is_file "$repo/$rpm_expected_path"
    done
}


@test "stores.rpm: Add simple signed rpm to existing repo" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    for ((i=0; i<${#SIGNED_RPMS[@]}; i++)); do
        rpm_file="${SIGNED_RPMS[$i]}"
        rpm_expected_path="${SIGNED_RPM_EXPECTED_PATHS[$i]}"
        repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.is_file "$repo/$rpm_expected_path"
    done
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
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[0]}" \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[2]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[2]}"
    helpers.run repoman_coverage \
        -v "$repo" \
        --option store.RPMStore.on_wrong_distro=copy_to_all \
        add "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "0"
    tree "$repo"
    ! helpers.contains "$output" 'Unknown distro'
    ! helpers.contains "$output" 'Malformed release string'
    for expected_path in "${ALL_DISTRO_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected_path"
    done
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
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[0]}" \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[2]}" \
            "$BATS_TEST_DIRNAME/$NO_DISTRO_RPM"
    helpers.equals "$status" "0"
    tree "$repo"
    ! helpers.contains "$output" 'Unknown distro'
    ! helpers.contains "$output" 'Malformed release string'
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[2]}"
    for expected_path in "${ALL_DISTRO_RPM_EXPECTED_PATHS[@]}"; do
        helpers.is_file "$repo/$expected_path"
    done
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
    for ((i=0; i<${#UNSIGNED_SRPMS[@]}; i++)); do
        rpm_file="${UNSIGNED_SRPMS[$i]}"
        rpm_expected_path="${UNSIGNED_SRPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.is_file "$repo/$rpm_expected_path"
    done
}


@test "stores.rpm: Add simple signed srpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<${#SIGNED_SRPMS[@]}; i++)); do
        rpm_file="${SIGNED_SRPMS[$i]}"
        rpm_expected_path="${SIGNED_SRPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage -v "$repo" add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.is_file "$repo/$rpm_expected_path"
    done
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
    helpers.run repoman_coverage -v "$repo" \
        add "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.equals "$status" "0"
    helpers.contains "$output" '^.*(Creating metadata.*)$'
    ! helpers.contains "$output" '^.*(Creating metadata.*){2}$'
}

@test "stores.rpm: Add and sign one rpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<${#UNSIGNED_RPMS[@]}; i++)); do
        rpm_file="${UNSIGNED_RPMS[$i]}"
        rpm_expected_path="${UNSIGNED_RPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage \
            -v \
            "$repo"  \
            --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
            --passphrase "$PGP_PASS" \
            add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.run rpm -qpi "$repo/$rpm_expected_path"
        helpers.equals "$status" "0"
        helpers.contains "$output" "^.*Key ID $PGP_ID.*\$"
    done
}


@test "stores.rpm: Add and sign one srpm" {
    local repo
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    for ((i=0; i<${#UNSIGNED_SRPMS[@]}; i++)); do
        rpm_file="${UNSIGNED_SRPMS[$i]}"
        rpm_expected_path="${UNSIGNED_SRPM_EXPECTED_PATHS[$i]}"
        rm -rf "$repo"
        rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
        repoman_coverage \
            -v \
            "$repo"  \
            --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
            --passphrase "$PGP_PASS" \
            add "$BATS_TEST_DIRNAME/$rpm_file"
        helpers.run rpm -qpi "$repo/$rpm_expected_path"
        helpers.equals "$status" "0"
        helpers.contains "$output" "^.*Key ID $PGP_ID.*\$"
    done
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
    for gen_file in "${FULL_SRPM_FILES[@]}"; do
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
    for gen_file in "${FULL_SRPM_FILES[@]}"; do
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
                "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
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
            "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
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
            "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.equals "$status" '0'
    expected_path="${SIGNED_RPM_EXPECTED_PATHS[0]/rpm/custom_name}"
    helpers.is_file "$repo/$expected_path"
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
            "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]#rpm/}"
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
            "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.run repoman_coverage \
        -v \
        "$repo" \
            add \
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[1]}"
    helpers.equals "$status" '0'
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
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
            "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[0]}"
    helpers.equals "$status" '0'
    echo -e\
        "$BATS_TEST_DIRNAME/${SIGNED_RPMS[0]}" \
        "\n" \
        "$BATS_TEST_DIRNAME/${UNSIGNED_RPMS[1]}" \
    | repoman_coverage \
        -v \
        "$repo" \
            add \
            --read-sources-from-stdin
    helpers.is_file "$repo/${SIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[0]}"
    helpers.is_file "$repo/${UNSIGNED_RPM_EXPECTED_PATHS[1]}"
}



@test "stores.rpm: Remove all but the latest from existing repo" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$num_rpms; i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        remove-old --keep 1
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST[$i]}"
        helpers.isnt_file "$repo/$unexpected_path"
    done
    # check that the original rpms are still there
    for rpm_path in "${ALL_RPMS[@]}"; do
        helpers.is_file "$BATS_TEST_DIRNAME/$rpm_path"
    done
}


@test "stores.rpm: Remove all but the latest 2 from existing repo" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$num_rpms; i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        remove-old --keep 2
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST_TWO[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST_TWO[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST_TWO[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST_TWO[$i]}"
        helpers.isnt_file "$repo/$unexpected_path"
    done
    # check that the original rpms are still there
    for rpm_path in "${ALL_RPMS[@]}"; do
        helpers.is_file "$BATS_TEST_DIRNAME/$rpm_path"
    done
}


@test "stores.rpm: When adding, leave only the latest" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$(($num_rpms - 1)); i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        add \
            --keep-latest 1 \
            "$BATS_TEST_DIRNAME/${ALL_RPMS[@]: -1}"
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST[$i]}"
        helpers.isnt_file "$repo/$unexpected_path"
    done
    # check that the original rpms are still there
    for rpm_path in "${ALL_RPMS[@]}"; do
        helpers.is_file "$BATS_TEST_DIRNAME/$rpm_path"
    done
}


@test "stores.rpm: When adding, leave only the latest 2" {
    local repo
    load utils
    export COVERAGE_FILE="$BATS_TEST_DIRNAME/coverage.$BATS_TEST_NAME"
    repo="$BATS_TMPDIR/myrepo"
    num_rpms="${#ALL_RPMS[@]}"
    rm -rf "$BATS_TMPDIR/myrepo"
    for ((i=0; i<$(($num_rpms - 1)); i++)); do
        rpm_path="${ALL_RPMS[$i]}"
        expected_path="${ALL_EXPECTED_RPM_PATHS[$i]}"
        repoman_coverage --verbose "$repo" add "$BATS_TEST_DIRNAME/$rpm_path"
        helpers.is_file "$repo/$expected_path"
    done
    repoman_coverage --verbose "$repo" \
        add \
            --keep-latest 2 \
            "$BATS_TEST_DIRNAME/${ALL_RPMS[@]: -1}"
    # check that only the latest is there
    num_expected="${#ALL_EXPECTED_RPM_LATEST_TWO[@]}"
    for ((i=0; i<$num_expected; i++)); do
        expected_path="${ALL_EXPECTED_RPM_LATEST_TWO[$i]}"
        helpers.is_file "$repo/$expected_path"
    done
    num_unexpected="${#ALL_UNEXPECTED_RPM_LATEST_TWO[@]}"
    for ((i=0; i<$num_unexpected; i++)); do
        unexpected_path="${ALL_UNEXPECTED_RPM_LATEST_TWO[$i]}"
        helpers.isnt_file "$repo/$unexpected_path"
    done
    # check that the original rpms are still there
    for rpm_path in "${ALL_RPMS[@]}"; do
        helpers.is_file "$BATS_TEST_DIRNAME/$rpm_path"
    done
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


@test "store.rpm: Add and sign multiple rpms (same rpm with multiple distros and other rpms)" {
    local repo
    local rpm
    load utils
    repo="$BATS_TMPDIR/myrepo"
    rm -rf "$repo"
    rm -rf "$BATS_TEST_DIRNAME/../../.gnupg"
    rpms=()
    for rpm in "${UNSIGNED_RPMS[@]}"; do
        rpms+=("$BATS_TEST_DIRNAME/$rpm")
    done
    repoman \
        -v \
        "$repo"  \
        --key "$BATS_TEST_DIRNAME/$PGP_KEY" \
        --passphrase "$PGP_PASS" \
        add "${rpms[@]}"
    for rpm in "${UNSIGNED_RPM_EXPECTED_PATHS[@]}"; do
        helpers.run rpm -qpi "$repo/$rpm"
        helpers.equals "$status" "0"
        helpers.contains "$output" "^.*Key ID $PGP_ID.*\$"
    done
}
