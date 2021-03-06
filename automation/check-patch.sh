#!/bin/bash -e

source "automation/python.sh"

${PYTHON} -m pip install --upgrade pip
# currently need to add a specific version of tox
# the newer versions 4.14.1 and  3.14.2 fails on
# ERROR: Cannot uninstall 'virtualenv'. It is a distutils installed project
# and thus we cannot accurately determine which files belong to it which
# would lead to only a partial uninstall.
${PYTHON} -m pip install --upgrade tox==3.14.0

# on el8 pip installs to /usr/local/bin
export PATH="${PATH}:/usr/local/bin/"

mkdir -p exported-artifacts

save_logs() {
cp -pr .tox exported-artifacts/tox
}

trap save_logs EXIT

echo "######################################################################"
echo "#  Unit/static checks"
echo "#"
tox -e pep8,syspy,${PYTHON/thon}
echo "# Unit/static OK"
echo "######################################################################"
echo "######################################################################"
echo "#  Functional tests"
echo "#"
tox -e functional-${PYTHON/thon}
echo "#"
echo "# Functional OK"
echo "######################################################################"


"${0%/*}"/build-artifacts.sh

echo "######################################################################"
echo "#  Installation tests"
echo "#"

shopt -s extglob
if command -v dnf &>/dev/null; then
    dnf install -y exported-artifacts/!(*src).rpm
else
    yum install -y exported-artifacts/!(*src).rpm
fi
repoman -h

echo "#"
echo "# Installation OK"
echo "######################################################################"

echo "######################################################################"
echo "#  Generating report"
echo "#"

cat <<EOR > exported-artifacts/index.html
<html><body>
<a href="coverage/functional/coverage.total.html/index.html">
    Coverage report
</a>
EOR

echo "#"
echo "# Report generated"
echo "######################################################################"
