#!/bin/bash -e

if rpm --eval "%dist" | grep -qFi 'el6'; then
    # On EL6 there's no python2.7
    sed -i "s:python2.7:python2.6:" tox.ini
fi

echo "######################################################################"
echo "#  Unit/static checks"
echo "#"
tox
echo "# Unit/static OK"
echo "######################################################################"
echo "######################################################################"
echo "#  Functional tests"
echo "#"
tox -e functional
echo "#"
echo "# Functional OK"
echo "######################################################################"


"${0%/*}"/build-artifacts.sh

echo "######################################################################"
echo "#  Installation tests"
echo "#"

shopt -s extglob
if which yum-deprecated &>/dev/null; then
    yum-deprecated install exported-artifacts/!(*src).rpm
else
    yum install exported-artifacts/!(*src).rpm
fi
repoman -h

echo "#"
echo "# Installation OK"
echo "######################################################################"

