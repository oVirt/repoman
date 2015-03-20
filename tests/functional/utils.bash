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
