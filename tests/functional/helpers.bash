#!/usr/bin/env bash

helpers.exists() {
    local what="${1:?}"
    echo "exists $what"
    [[ -e "$what" ]]
}

helpers.is_file() {
    local what="${1:?}"
    echo "is file $what"
    [[ -f "$what" ]]
}

helpers.is_dir() {
    local what="${1:?}"
    echo "is dir $what"
    [[ -d "$what" ]]
}

helpers.is_link() {
    local what="${1:?}"
    echo "is link $what"
    [[ -L "$what" ]]
}

helpers.run() {
    run "$@"
    echo "$output"
}
