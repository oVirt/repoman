#!/bin/bash

for i in $(rpm -ql rpm-python); do
    for dst in .tox/functional/lib/python*; do
        dst="$dst/site-packages${i##*site-packages}"
        mkdir -p "${dst%/*}"
        echo "Installing $i -> $dst"
        cp -a "$i" "$dst"
    done
done

