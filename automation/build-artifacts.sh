#!/bin/bash -e
# If the rpm requirement name should not get python- appended put in this
# array
SAME_RPM_NAME=(
    'pyOpenSSL'
    'rpm-python'
    'koji'
    'python-gnupg'
    'createrepo'
)
# If instead of automatically adding it you want to add a spec snippet yourself
# add it here
declare -A EXTRA_SPECS
EXTRA_SPECS[pexpect]='
%if 0%{?fedora} >= 1
Requires: python-pexpect
%else
Requires: pexpect
%endif
'
EXTRA_SPECS[rpm-sign]='
%if 0%{?fedora} || 0%{?rhel} >= 7
Requires: rpm-sign
%endif
'

is_in() {
    local what="${1?}"
    local where=("${@:2}")
    local word
    for word in "${where[@]}"; do
        if [[ "$word" == "$what" ]]; then
            return 0
        fi
    done
    return 1
}


add_extra_spec() {
    local specfile="${1?}"
    local extra_spec="${2?}"
    awk \
        -vextra="$extra_spec" \
        '/Url:/{print extra}1' \
        "$specfile" \
    > "$specfile".tmp
    mv "$specfile".tmp "$specfile"
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

# Requires
for requirement in $(grep -v -e '^\s*# ' requirements.txt); do
    requirement="${requirement%%[<>=]*}"
    requirement="${requirement##*#}"
    if is_in "$requirement" "${SAME_RPM_NAME[@]}"; then
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nRequires:$requirement/" \
            dist/repoman.spec
    elif is_in "$requirement" "${!EXTRA_SPECS[@]}"; then
        add_extra_spec "dist/repoman.spec" "${EXTRA_SPECS[$requirement]}"
    else
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nRequires:python-$requirement/" \
            dist/repoman.spec
    fi
done

# BuildRequires
for requirement in $(grep -v -e '^\s*#' build-requirements.txt); do
    requirement="${requirement%%[<>=]*}"
    if is_in "$requirement" "${SAME_RPM_NAME[@]}"; then
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nBuildRequires:$requirement/" \
            dist/repoman.spec
    elif is_in "$requirement" "${!EXTRA_SPECS[@]}"; then
        add_extra_spec "dist/repoman.spec" "${EXTRA_SPECS[$requirement]}"
    else
        sed \
            -i \
            -e "s/Url: \(.*\)/Url: \1\nBuildRequires:python-$requirement/" \
            dist/repoman.spec
    fi
done

# generate tarball
python setup.py sdist

# install build-requires
yum-builddep dist/repoman.spec

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
