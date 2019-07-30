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

Repo hosting container Image
============================

Along with repoman itself, this repo also provides a container image that uses
repoman to build a package repository and then shares it over HTTP. This image
is meant to be used as a builder image along with with OpenShift's
source-to-image (s2i) tool to build repository container images.

Building the repoman builder Image
----------------------------------

To build the builder image using Docker, the following command can be used:

    docker build . -f Dockerfile.s2i-repo -t repoman-repo-centos7

Building a repo container
-------------------------

To build a repo container using the builder image one need to first create a
directory containing a file called ``repoman_sources.lst``. That files should
contain a list of ``repoman`` sources to be included in the repo.

Once the file is ready the following command can be used to build the repo
container image (Assuning the directory was created at
``~/src/repoman_sources``)::

    s2i build ~/src/repoman_sources/ repoman-repo-centos7 my_repo

Given the command above the container will be created as ``my_repo``.

Incremental and layered builds
------------------------------

The repo container builder image provides two ways to add or update packges in
an existing repo container image:

Layered builds
  When using layered builds, we tak an existing repo container image and add a
  layer on top of it with the new packages included. The main benefit of this
  approach is in conserving disk space and bandwidth for machines that work with
  multiple versions of the same repo at the same time, or when pushing updates
  to a repo. The main shortcoming of this approach is that the images can only
  grow, since we keep adding layers, and removing packages does not free any
  space.

Incremental builds
  Incremental builds leverage the s2i incremental build feature to create a new
  container image while avoiding the need to re-download repo artifacts by
  copying then from and older image at build time. The benefit of this approach
  is that we can get smaller container images when compared to layered images
  because we don't keep older layers around, but the overall disk space usage
  can end up being greater if we have multiple versions of the same repo in the
  same machine.

Example: To perform a layered build to add packages to an older repo container
image called ``my_repo`` so that we get a new image called ``my_repo:new`` we
run the following command (We assume the sources file was changed to include new
packages))::

    s2i build ~/src/repoman_sources/ my_repo my_repo:new

(In the example above, note that the older image is a used as the builder image
and not the ``repoman-repo-centos7`` image)

To perform an incremental build to add packages to the ``my_repo`` container
image so that we get a new image of the same name with the new packages added,
we run the following command::

    s2i build --incremental ~/src/repoman_sources/ repoman-repo-centos7 my_repo
