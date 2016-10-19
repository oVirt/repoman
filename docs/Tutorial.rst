Basic Tutorial
================

In order to get you started using repoman, here's a quick tutorial showing some
of the most commonly used features, remember that for extra help on all the
configuration options supported and all the sources and filters you can search
the api docs or run the `docs` subcommand to get info about it::

    repoman dummyrepo docs -h

Adding the packages of a local dir to an existing repo
--------------------------------------------------------

This is the most simple use case, imagine that you have a directory with some
artifacts, and you want to add it to an already existing repository, you can
just run::

    repoman /path/to/existing/repository add /path/to/dir/with/extra/artifacts


That will make sure that the artifacts in the directory
`/path/to/dir/with/extra/artifacts` are added to `/path/to/existing/repository`
and will make sure that they are added in an ordered manner, and update any
metadata needed by the repos (like yum repository metadata).


Adding other sources of packages to an existing repo
-----------------------------------------------------

Now let's try to use other types of sources for the artifacts, here is an
example::

    repoman /path/to/existing/repo add \
        koji:@some-tag \
        recursive:http://my.home.page/somepath \
        http://jenkins.ovirt.org/job/repoman_master_build-artifacts-el6-x86_64/ \
        http://koji.fedoraproject.org/koji/buildinfo?buildID=767073 \
        https://copr.fedorainfracloud.org/coprs/msivak/ovirt-optimizer-for-ovirt-4.0/build/466823/

As you can see you can specify more than one source at a time, let's take a
small look to the ones here:

* `koji:@some-tag`: this will go to koji, and retrieve any package tha matches
  the given tag

* `recursive:http://my.home.page/somepath`: this will recursively search in
  that web page, for link to artifacts, and retrieve all of them

* `http://jenkins.ovirt.org/job/repoman_master_build-artifacts-el6-x86_64/`:
  this will retrive all the artifacts from the latest successful build for that
  jenkins job.

* `http://koji.fedoraproject.org/koji/buildinfo?buildID=767073`: this will
  retrieve all the artifacts for the given koji build

* `https://copr.fedorainfracloud.org/coprs/msivak/ovirt-optimizer-for-ovirt-4.0/build/466823/`:
  this will retrieve all the artifacts for the given copr build


Filtering some of the sources
-------------------------------

Another useful tool that repoman gives you, is the ability to filter out the
artifacts that a source will expand to, that is done by appending one or more
':' separated filter strings to the source, for example::

    repoman /path/to/existing/repo add \
        /path/to/dir/with/extra/artifacts:latest=2

There it will only select the artifacts with the two highest versions from the
`/path/to/dir/with/extra/artifacts` source, ignoring any other lower version
ones, and only add those high version artifacts to the `/path/to/existing/repo`
repository. You can add more than one filter to the source, and they will be
applied from rightmost (outer) to leftmost (inner)::

    repoman /path/to/existing/repo add \
        /path/to/dir/with/extra/artifacts:latest:name~repoman.*

The above one would first filter by name (regexp) and then by version, getting
only the latest one (the default for the latest filter).


Getting the sources from a conf file
-------------------------------------

So, imagine that you have a bunch of different sources you want to add to a
repo, having to write them down as arguments in the command line is too
troublesome and has it's limitations, to overcome that issue, repoman allows
you to write the sources down inside a file, and them just refernce it with the
`conf:` metasource, for example, if you have a file named `mysources`::

    ## These are some useful souces for a release
    # get all the packages for a koji tag
    koji:@some-tag

    # we will need also all the packages under this page (recursively)
    recursive:http://my.home.page/somepath

    # And repoman latest successful build on el6
    http://jenkins.ovirt.org/job/repoman_master_build-artifacts-el6-x86_64/

So, if you have that file in your current directory, you can just run::

    repoman /path/to/existing/repo add conf:mysources

And repoman will read that file, discard any comments or empty lines, and use
any sources defined there as if they were specifyed by command line.


Specifying some custom repoman config options
----------------------------------------------

So, imagine that you want to tweak some default options, for example, you want
to force that when addin an rpm, if the distro can't be guessed from the
release, for it to be added to all the known distributions of the repo. So to
do that, you can use repoman --option::

    repoman --option=store.RPMStore.on_wrong_distro=copy_to_all \
        /path/to/existing/repo add conf:mysources

Remember that to see all the confi options you can check with the docs
subcommand like this::

    repoman dummyrepo docs config

And for details on what each value means, you can go to the specific section
docs, for example, for the option we added::

    repoman dummyrepo docs stores RPMStore


Specifying a custom repoman config file
----------------------------------------

The same way as when specifying the sources, having to specify the options in
the command line might be a burden, luckily we can also write the config
options down in a file, and just use that file, for example, if we have a file
called `custom.config`::

    # Some config overrides
    [store.RPMStore]
    on_wrong_distro = copy_to_all

Then we can call repoman with the -c|--config option like this::

    repoman --config=custom.config \
        /path/to/existing/repo add conf:mysources
