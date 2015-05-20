#!/usr/bin/env python

import pytest

from repoman.common.sources import kojibuild


class KojiMock(object):
    def __init__(self, builds, tag=None, package=None):
        self._topdir = None
        self._builds = builds
        self._tag = tag
        self._package = package

    def ClientSession(self, *args):
        return self

    def getLatestBuilds(self, tag, package=None):
        if self._tag is not None:
            assert self._tag == tag
        if self._package is not None:
            assert self._package == package
        return [{'build_id': build} for build in self._builds]

    def getBuild(self, nvr):
        return {'build_id': self._builds[0]}

    def listRPMs(self, buildID):
        return buildID

    def PathInfo(self, topdir):
        self._topdir = topdir
        return self

    def build(self, pkg):
        return pkg['build_id'][0].name

    def rpm(self, rpm):
        return rpm.rpm

    def get_mock_expected(self):
        return [
            build[0].name + '/' + rpm.rpm
            for build in self._builds
            for rpm in build
        ]


class Build(object):
    def __init__(self, packages):
        self.packages = packages

    def __getitem__(self, item):
        return self.packages[item]

    def __repr__(self):
        return 'Build(%s)' % str(self.packages)

    def __len__(self):
        return len(self.packages)

    def __int__(self):
        return 42


class Package(object):
    def __init__(self, name, rpm):
        self.name = name
        self.rpm = rpm

    def __repr__(self):
        return 'Package(name="%s", rpm="%s")' % (self.name, self.rpm)


class ConfigMock(object):
    def get(self, name):
        return name


@pytest.fixture(params=[
    (
        'koji:@tagonly',
        KojiMock(
            builds=(
                Build([Package('pkg1', 'rpm1')]),
                Build([Package('pkg2', 'rpm2'), Package('pkg3', 'rpm3')]),
            ),
            tag='tagonly',
        ),
    ),
    (
        'koji:name@tag',
        KojiMock(
            builds=(Build([Package('pkg4', 'rpm4')]),),
            tag='tag',
            package='name',
        )
    ),
    (
        'koji:name-ver-rel',
        KojiMock(builds=(Build([Package('pkg5', 'rpm5')]),)),
    ),
])
def koji_data(request):
    return request.param


def test_sources(monkeypatch, koji_data):
    source_str, koji_mock = koji_data
    monkeypatch.setattr(kojibuild, 'koji', koji_mock)
    monkeypatch.setattr(kojibuild, 'has_store', lambda x, y: True)
    koji_source = kojibuild.KojiBuildSource(config=ConfigMock(), stores=None)
    _, artifacts = koji_source.expand(source_str)
    assert artifacts == koji_mock.get_mock_expected()


def test_filters_are_etracted(monkeypatch):
    source_str = 'koji:name-version-release:whatever:filters'
    koji_mock = KojiMock(builds=(Build([Package('pkg6', 'rpm6')]),))
    monkeypatch.setattr(kojibuild, 'koji', koji_mock)
    monkeypatch.setattr(kojibuild, 'has_store', lambda x, y: True)
    koji_source = kojibuild.KojiBuildSource(config=ConfigMock(), stores=None)
    extracte_filters, artifacts = koji_source.expand(source_str)
    assert artifacts == koji_mock.get_mock_expected()
    assert extracte_filters == 'whatever:filters'
