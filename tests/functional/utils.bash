#!/usr/bin/env bash

utils.distro(){
    local distro \
        release
    if ! lsb_release &>/dev/null; then
        echo "Unknown"
        return 1
    else
        lsb_release -irs
    fi
    return 0
}


utils.gather_coverage(){
    local suite_name="${1?}"
    local test_dirname="${2?}"
    local out_dir="${3?}"
    local include="${4}"
    local file_tag="${suite_name//_/-5f}"
    file_tag="${file_tag//./-2e}"
    ls -l "$test_dirname"
    rm -rf "$out_dir/coverage.$suite_name"*
    [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
    mv "${test_dirname}"/coverage.* "$out_dir/"
    cd "$out_dir"
    export COVERAGE_FILE="$out_dir/coverage.$suite_name.db"
    coverage combine coverage.test_"${file_tag}"-*
    coverage report \
        --include "*site-packages/repoman*${include}" \
        -m \
    > "coverage.$suite_name.txt"
    coverage html \
        --include "*site-packages/repoman*${include}" \
        -d "coverage.${suite_name}.html"
}
