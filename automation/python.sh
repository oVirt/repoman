#!/bin/bash -e

if rpm --eval "%dist" | grep -qFi 'el7'; then
    PYTHON=python2
else
    PYTHON=python3
fi
