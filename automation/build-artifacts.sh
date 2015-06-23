#!/bin/bash -e


PEXPECT_SPEC='
%if 0%{?fedora} >= 1
Requires: python-pexpect
%else
Requires: pexpect
%endif
'


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

for requirement in $(grep -v -e '^\s*#' requirements.txt); do
    requirement="${requirement%%<*}"
    requirement="${requirement%%>*}"
    requirement="${requirement%%=*}"
    if [[ "$requirement" == "pyOpenSSL" ]]; then
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

if which yum-deprecated &>/dev/null; then
    yum-deprecated install exported-artifacts/*rpm
else
    yum install exported-artifacts/*rpm
fi

echo "#"
echo "# Installation OK"
echo "######################################################################"
