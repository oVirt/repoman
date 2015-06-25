#!/usr/bin/env python

import pytest

from repoman.common.sources import jenkins


def get_url(suffix=''):
    return 'http://jenkins.ovirt.org/job/' + suffix


class RequestsMock(object):
    def __init__(self, build):
        self.build = build

    def get(self, what):
        return self.build


class ConfigMock(object):
    def get(self, name):
        return jenkins.JenkinsSource.DEFAULT_CONFIG.get(name, name)


class ResponseMock(object):
    def json(self):
        return self

    def ok(self):
        return True


class MulticonfigBuild(dict, ResponseMock):
    def __init__(self, build_number, runs):
        super(MulticonfigBuild, self).__init__()
        self['number'] = build_number
        self['runs'] = runs
        self['url'] = get_url()


class Build(dict, ResponseMock):
    def __init__(self, build_number, artifacts, url):
        super(Build, self).__init__()
        self['number'] = build_number
        self['artifacts'] = artifacts
        self['url'] = url


class Run(Build):
    def __init__(self, build_number, artifacts, url):
        super(Run, self).__init__(build_number, artifacts, url)


class Artifact(dict):
    def __init__(self, relative_path):
        super(Artifact, self).__init__()
        self['relativePath'] = relative_path


@pytest.fixture(params=[
    # simple case
    (
        get_url('111'),
        RequestsMock(
            Build(
                build_number='111',
                artifacts=[
                    Artifact('iaman.rpm'),
                    Artifact('iaman.iso'),
                ],
                url=get_url('111')
            ),
        ),
        [
            get_url('111/artifact/iaman.rpm'),
            get_url('111/artifact/iaman.iso'),
        ],
    ),
    # multiconfig with some spurious runs
    (
        get_url('111'),
        RequestsMock(
            MulticonfigBuild(
                build_number='111',
                runs=(
                    Build(
                        build_number='111',
                        artifacts=[
                            Artifact('iaman.rpm'),
                            Artifact('iaman.iso'),
                        ],
                        url=get_url('111/run1')
                    ),
                    Build(
                        build_number='111',
                        artifacts=[
                            Artifact('iaman2.rpm'),
                            Artifact('iaman2.iso'),
                        ],
                        url=get_url('111/run2')
                    ),
                    Build(
                        build_number='112',
                        artifacts=[
                            Artifact('iaman3.rpm'),
                            Artifact('iaman3.iso'),
                        ],
                        url=get_url('111/run3')
                    ),
                ),
            ),
        ),
        [
            get_url('111/run1/artifact/iaman.rpm'),
            get_url('111/run1/artifact/iaman.iso'),
            get_url('111/run2/artifact/iaman2.rpm'),
            get_url('111/run2/artifact/iaman2.iso'),
        ],
    ),
])
def jenkins_data(request):
    return request.param


def test_sources(monkeypatch, jenkins_data):
    source_str, jenkins_mock, expected = jenkins_data
    monkeypatch.setattr(jenkins, 'requests', jenkins_mock)
    monkeypatch.setattr(
        jenkins,
        'has_store',
        lambda x, y: x.endswith('.rpm') or x.endswith('.iso')
    )
    jenkins_source = jenkins.JenkinsSource(config=ConfigMock(), stores=None)
    _, artifacts = jenkins_source.expand(source_str)
    assert artifacts == expected


def test_filters_are_extracted(monkeypatch):
    source_str = get_url('111:whatever:filters')
    jenkins_mock = RequestsMock(
        Build(
            build_number='111',
            artifacts=[Artifact('myartie.rpm')],
            url=get_url('111')
        )
    )
    expected = [get_url('111/artifact/myartie.rpm')]
    monkeypatch.setattr(jenkins, 'requests', jenkins_mock)
    monkeypatch.setattr(
        jenkins,
        'has_store',
        lambda x, y: x.endswith('.rpm') or x.endswith('.iso')
    )
    jenkins_source = jenkins.JenkinsSource(config=ConfigMock(), stores=None)
    extracte_filters, artifacts = jenkins_source.expand(source_str)
    assert artifacts == expected
    assert extracte_filters == 'whatever:filters'
