#!/bin/bash -e

SAME_RPM_NAME=(
    'pyOpenSSL'
    'rpm-python'
    'koji'
    'python-gnupg'
)
PEXPECT_SPEC='
%if 0%{?fedora} >= 1
Requires: python-pexpect
%else
Requires: pexpect
%endif
'

is_in() {
    what="${1?}"
    where=("${@:2}")
    for word in "${where[@]}"; do
        if [[ "$word" == "$what" ]]; then
            return 0
        fi
    done
    return 1
}


echo "######################################################################"
echo "#  Building artifacts"
echo "#"

shopt -s nullglob

# cleanup
rm -Rf \
    exported-artifacts \
    dist \
    build
mkdir exported-artifacts

# Custom hacks to get the correct spec file
# to add the dist, and the requirements
python setup.py bdist_rpm --spec-only

sed -i \
  -e 's/Release: \(.*\)/Release: \1%{?dist}/' \
  dist/repoman.spec

for requirement in $(grep -v -e '^\s*# ' requirements.txt); do
    requirement="${requirement%%<*}"
    requirement="${requirement%%>*}"
    requirement="${requirement%%=*}"
    requirement="${requirement##*#}"
    if is_in "$requirement" "${SAME_RPM_NAME[@]}"; then
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nRequires:$requirement/" \
            dist/repoman.spec
    elif [[ "$requirement" == "pexpect" ]]; then
        awk \
            -vextra="$PEXPECT_SPEC" \
            '/Url:/{print extra}1' \
            dist/repoman.spec \
        > dist/repoman.spec.tmp
        mv dist/repoman.spec.tmp dist/repoman.spec
    else
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nRequires:python-$requirement/" \
            dist/repoman.spec
    fi
done

for requirement in $(grep -v -e '^\s*#' build-requirements.txt); do
    requirement="${requirement%%<*}"
    requirement="${requirement%%>*}"
    requirement="${requirement%%=*}"
    sed -i \
        -e "s/Url: \(.*\)/Url: \1\nBuildRequires:python-$requirement/" \
        dist/repoman.spec
done

# generate tarball
python setup.py sdist

# create rpms
rpmbuild \
    -ba \
    --define "_srcrpmdir $PWD/dist" \
    --define "_rpmdir $PWD/dist" \
    --define "_sourcedir $PWD/dist" \
    dist/repoman.spec

for file in $(find dist -iregex ".*\.\(tar\.gz\|rpm\)$"); do
    echo "Archiving $file"
    mv "$file" exported-artifacts/
done

rm -rf rpmbuild

echo "#"
echo "#  Building artifacts OK"
echo "######################################################################"

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
