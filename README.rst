Development Environment Setup
==============================

To run the tests you need to have installed in your system a reasonable
new version of 'tox' and the required project dependencies that are
not available in PyPI.

See project's Dockerfile or requirements.txt to get idea which distribution
packages are needed. The list is created and maintained for Fedora or CentOS
with EPEL enabled.

Building and Running Tests
===========================

To build and run unit tests, run 'tox' from the top dir of the project::

    tox

There is also a functional test suite that can be run by specifying additional
'tox' environment parameter::

    tox -e functional

Building the Documentation
===========================

To build the docs, you can use 'docs' environment::

    tox -e docs

That will leave the docs under the path ``docs/_build/html/index.html``

Docker Development Image
=========================

This project requires a set of dependencies to be installed on a system. To help
with that for development there is a pre-built docker image available based
on the CentOS 7 official image. The development image includes everything
necessary to build repoman, run unit and functional tests and generate docs.

By default, the container will cd to /mnt directory where it expects the root of
repoman source code tree to be mounted, but will not run any command (there is
no entry point explicitly defined). Also it does not require root privileges and
is convenient to run under your UID, so you can use your working tree.

E.g. to run just 'tox' you can use::

    sudo docker run -v /path/to/repoman/source:/mnt -u $UID -t -i marchukov/repoman-tox-env-centos7 tox

You can pass 'tox' parameters to the container as usual, e.g. to run the
functional test suite::

    sudo docker run -v /path/to/repoman/source:/mnt -u $UID -t -i marchukov/repoman-tox-env-centos7 tox -e functional

Since each run will create a new container, when debugging requires multiple
runs, it is convenient to reuse a single container with an interactive shell::

    sudo docker run -v /path/to/repoman/source:/mnt -u $UID -t -i marchukov/repoman-tox-env-centos7 bash

This will give you a shell and you can then run 'tox' there or do whatever else
is necessary.
