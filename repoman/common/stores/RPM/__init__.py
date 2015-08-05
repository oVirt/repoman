#!/usr/bin/env python
# encoding:utf-8
"""
This module holds the class and methods to manage an rpm store and it's
sources.

In our case an rpm store is not just a yum repository but a set of them and
src files, in the following structure:


repository_dir
├── rpm
│   ├── $dist1  <- this is a yum repository
│   │   ├── repodata
│   │   │   └── ...
│   │   ├── SRPMS
│   │   │   ├── $srcrpm1
│   │   │   ├── $srcrpm2
│   │   │   └── ...
│   │   ├── $arch1
│   │   │   ├── $rpm1
│   │   │   ├── $rpm2
│   │   │   └── ...
│   │   ├── $arch2
│   │   └── ...
│   ├── $dist2  <- another yum reposiory
│   │   └── ...
│   └── ...
└── src
    ├── $project1
    │   │   ├── $source1
    │   │   ├── $source1.sig
    │   │   ├── $source2
    │   │   └── ...
    │   └── ...
    └── ...
"""
import os
import logging
import subprocess
import gnupg
import multiprocessing as mp
from .. import ArtifactStore
from .RPM import (
    RPMList,
    RPMName,
    RPM,
)
from ...utils import (
    list_files,
    save_file,
    extract_sources,
    sign_detached,
)


logger = logging.getLogger(__name__)


class CreaterepoError(Exception): pass  # flake8: noqa


class CreatereposError(Exception): pass  # flake8: noqa


class RPMStore(ArtifactStore):
    """
    Represents the repository sctructure, it does not require that the repo has
    the structure specified in the module doc when loading it, but when adding
    new rpms or generating the sources it will create the new files in that
    directory structure.

    Configuration options:

      distro_reg
        Regular expression to extract the distribution from the release string

      extra_symlinks
        Comma separated list of orig:symlink pairs to create links, the paths

      path_prefix
        Prefixes of this store inside the globl artifact repository, separated
        by commas

      rpm_dir
        name of the directory that will contain the rpms (rpm by default), if
        empty, it will not create a subdirectory for the rpms and will be put
        on the root of the repo (root/$dist/$arch/*rpm)

      signing_key
        Path to the gpg keey to sign the rpms with, will not sign them if not
        set

      signing_passphrase
        Passphrase for the above key

      temp_dir
        Temporary dir to store any transient downloads (like rpms from
        urls). The caller should make sure it exists and clean it up if needed.

      with_sources
        If true, will extract the sources form the scrrpms

      with_srcrpms
        If false, will ignore the srcrpms
        will be relative to the store root path.
    """

    CONFIG_SECTION = 'RPMStore'
    DEFAULT_CONFIG = {
        'distro_reg': r'\.(fc|el)\d+(?=\w*)',
        'extra_symlinks': '',
        'path_prefix': 'rpm,src',
        'rpm_dir': 'rpm',
        'signing_key': '',
        'signing_passphrase': 'ask',
        'temp_dir': 'generate',
        'with_sources': 'false',
        'with_srcrpms': 'true',
    }

    def __init__(self, config, repo_path=None):
        """
        :param repo_path: Path to the repository directory, if passed it will
            automatically add all the rpms under it to the repo if any.
        :param config: configuration for the store
        """
        self.name = self.__class__.__name__
        self.rpms = RPMList()
        self._path_prefix = config.get('path_prefix').split(',')
        self.path = repo_path or ('Non persistent %s' % self.name)
        self.rpmdir = config.get('rpm_dir')
        self.to_copy = []
        self.distros = set()
        self.sign_key = config.get('signing_key')
        self.sign_passphrase = config.get('signing_passphrase')
        # init first, add existing repo after
        super(RPMStore, self).__init__(config=config)
        if repo_path:
            logger.info('Loading repo %s', repo_path)
            for pkg in list_files(repo_path, '.rpm'):
                self.add_artifact(
                    pkg,
                    to_copy=False,
                    hidelog=True,
                )
            logger.info('Repo %s loaded', repo_path)

    @property
    def path_prefix(self):
        return self._path_prefix

    def handles_artifact(self, artifact):
        if self.config.get('with_srcrpms').lower() == 'false':
            return (
                artifact.endswith('.rpm')
                and not artifact.endswith('.src.rpm')
            )
        else:
            return artifact.endswith('.rpm')

    def add_artifact(self, pkg, **args):
        self.add_rpm(pkg, **args)

    def add_rpm(self, pkg, onlyifnewer=False, to_copy=True, hidelog=False):
        """
        Generic functon to add an rpm package to the repo.

        :param pkg: path or url to the rpm file to add
        :param onlyifnewer: If set to True, will only add the package if it's
            not there already or the version is newer than the on already
            there.
        :param to_copy: If set to True, will add that package to the list of
            packages to copy into the repo when saving, usually used when
            adding new packages to the repo.
        :param hidelog: If set to True will not show the extra information
            (used when loading a repository to avoid verbose output)
        """
        pkg = RPM(
            pkg,
            temp_dir=self.config.get('temp_dir'),
            distro_reg=self.config.get('distro_reg')
        )
        if self.rpms.add_pkg(pkg, onlyifnewer):
            if to_copy:
                self.to_copy.append(pkg)
            if not hidelog:
                logger.info(
                    'Adding package %s to repo %s', pkg.path, self.path,
                )
        else:
            if not hidelog:
                logger.info(
                    "Not adding %s, there's already an equal or newer "
                    "version",
                    pkg,
                )
        if pkg.distro != 'all':
            self.distros.add(pkg.distro)

    def save(self, **args):
        self._save(**args)

    def _save(self, onlylatest=False):
        """
        Copy all the extra rpms added to the repository and save it's state.

        :param onlylatest: Only copy the latest version of the added rpms.
        """
        logger.info('Saving new added rpms into %s', self.path)
        for pkg in self.to_copy:
            if onlylatest and not self.is_latest_version(pkg):
                logger.info(
                    'Skipping %s a newer version is already in the repo.',
                    pkg,
                )
                continue
            if pkg.distro == 'all':
                if not self.distros:
                    raise Exception(
                        'No distros found in the repo and no packages with '
                        'any distros added.'
                    )
                dst_distros = self.distros
            else:
                dst_distros = [pkg.distro]
            for distro in dst_distros:
                if pkg.distro == 'all':
                    dst_path = (
                        self.path + '/'
                        + pkg.generate_path(self.rpmdir) % distro
                    )
                else:
                    dst_path = self.path + '/' + pkg.generate_path(self.rpmdir)
                save_file(pkg.path, dst_path)
                pkg.path = dst_path
        if self.sign_key:
            self.sign_rpms()
        if self.config.getboolean('with_sources'):
            self.generate_sources(
                with_patches=self.config.getboolean('with_sources'),
                key=self.config.get('signing_key'),
                passphrase=self.sign_passphrase,
            )
        self.createrepos()
        self.create_symlinks()
        logger.info('')
        logger.info('Saved %s\n', self.path)

    def is_latest_version(self, pkg):
        """
        Check if the given package is the latest version in the repo
        :pram pkg: RPM instance of the package to compare
        """
        verlist = self.rpms.get(pkg.full_name, {})
        if not verlist or pkg.full_version in verlist.get_latest():
            return True
        return False

    def generate_sources(self, with_patches=False, key=None, passphrase=None):
        """
        Generate the sources directory from all the srcrpms
        :param with_patches: If set, will also extract the .patch files from
            the srcrpm
        :param key: If set to the path of a gpg key, will use that key to
            create the detached signatures of the extracted sources
        :param passphrase: Passphrase to unlock the key
        """
        logger.info('')
        logger.info('Extracting sources')
        logger.info("Generating src directory from srpms")
        for versions in self.rpms.itervalues():
            for version in versions.itervalues():
                for inode in version.itervalues():
                    pkg = inode[0]
                    if pkg.is_source:
                        break
                else:
                    continue
                logger.info("Parsing srpm %s", pkg)
                dst_dir = '%s/src/%s' % (self.path, pkg.name)
                extract_sources(pkg.path, dst_dir, with_patches)
                if key:
                    sign_detached(dst_dir, key, passphrase)
        logger.info('src dir generated')

    @staticmethod
    def createrepo(dst_dir):
        with open(os.devnull, 'w') as devnull:
            res = subprocess.call(['createrepo', dst_dir], stdout=devnull)
        if res != 0:
            raise CreaterepoError(
                "Createrepo failed on %s with rc %d" % (dst_dir, res)
            )

    def createrepos(self):
        """
        Generate the yum repositories metadata
        """
        logger.info('')
        logger.info('Updating metadata')
        procs = []
        for distro in self.distros:
            logger.info('  Creating metadata for %s', distro)
            dst_dir = os.path.join(self.path, self.rpmdir, distro)
            new_proc = mp.Process(
                target=self.createrepo,
                args=(dst_dir,),
            )
            new_proc.start()
            procs.append(new_proc)
        for proc in procs:
            proc.join()
            if proc.exitcode != 0:
                raise CreatereposError("Failed to create some repos metadata")

    def delete_old(self, keep=1, noop=False):
        """
        Delete the oldest versions for each package from the repo
        :param keep: Maximium number of versions to keep of each package
        :param noop: If set, will only log what will be done, not actually
            doing anything.
        """
        new_rpms = RPMList(self.rpms)
        for name, versions in self.rpms.iteritems():
            if len(versions) <= keep:
                continue
            to_keep = RPMName()
            for _ in range(keep):
                latest = versions.get_latest()
                to_keep.update(latest)
                versions.pop(latest.keys()[0])
            new_rpms[name] = to_keep
            for version in versions.keys():
                logger.info('Deleting %s version %s', name, version)
                versions.del_version(version, noop)
        self.rpms = new_rpms

    def get_rpms(self, regmatch=None, fmatch=None, latest=0):
        """
        Get the list of rpms, filtered or not.
        :param regmatch: Regular expression that will be applied to the path of
            each package to filter it
        :param fmatch: Filter function that must return True for a package to
            be selected, will be passed the RPM object as only parameter
        :param latest: If set to N>0, it will return only the N latest versions
            for each package
        """
        logging.debug('RPMStore.get_rpms::regmatch=%s', regmatch)
        logging.debug('RPMStore.get_rpms::fmatch=%s', fmatch)
        logging.debug('RPMStore.get_rpms::latest=%s', latest)
        return self.rpms.get_artifacts(
            regmatch=regmatch,
            fmatch=fmatch,
            latest=latest,
        )

    def get_latest(self, num=1):
        """
        Return the num latest versions for each rpm in the repo
        :param num: number of latest versions to return
        """
        return [pkg.path for pkg in self.get_rpms(latest=num)]

    def get_artifacts(self, regmatch=None, fmatch=None, latest=0):
        """
        Returns the list of artifacts matching the params

        :param regmatch: Regular expression to filter the rpms path with
        :param fmatch: Filter function, must return True for packages to be
            included, or False to be excluded. The package object will be
            passed as parameter
        :param latest: number of latest versions to return (0 for all,)
        """
        return self.get_rpms(
            regmatch=regmatch,
            fmatch=fmatch,
            latest=latest,
        )

    def sign_rpms(self):
        """
        Sign all the unsigned rpms in the repo.
        """
        logger.info('')
        logger.info('Signing packages')
        try:
            # older gnupg versions
            gpg = gnupg.GPG(gnupghome=os.path.expanduser('~/.gnupg'))
        except TypeError:
            gpg = gnupg.GPG(homedir=os.path.expanduser('~/.gnupg'))

        key = self.sign_key
        passphrase = self.sign_passphrase
        try:
            with open(key) as key_fd:
                skey = gpg.import_keys(key_fd.read())
        except IOError:
            logger.error('Unable to find signing key')
            raise
        fprint = skey.results[0]['fingerprint']
        keyuid = None
        for key in gpg.list_keys(True):
            if key['fingerprint'] == fprint:
                keyuid = key['uids'][0]

        for pkg in self.get_rpms():
            logger.info('Got package %s', pkg)
        for pkg in self.get_rpms(
                fmatch=lambda pkg: not pkg.signature
        ):
            pkg.sign(keyuid, passphrase)
            logger.info('Got unsigned package %s', pkg)
        logger.info("Done signing")

    def create_symlinks(self):
        """Creates all the symlinks to the dirs passed on the config"""
        logger.info('')
        logger.info('Creating symlinks')
        symlinks = self.config.getarray('extra_symlinks')
        for symlink in symlinks:
            if ':' not in symlink:
                logger.warn('  Ignoring malformed symlink def %s', symlink)
                continue
            s_orig, s_link = symlink.split(':', 1)
            if not s_orig or not s_link:
                logger.warn('  Ignoring malformed symlink def %s', symlink)
                continue
            full_s_orig = os.path.join(self.path, s_orig)
            s_link = os.path.join(self.path, s_link)
            logger.info('  %s -> %s', s_link, s_orig)
            if os.path.lexists(s_link):
                logger.warn('    Path for the link already exists')
                continue
            if not os.path.exists(full_s_orig):
                logger.warn('   The link points to non-existing path')
            try:
                os.symlink(s_orig, s_link)
            except Exception as exc:
                logger.error(
                    '    Failed to create link %s -> %s',
                    s_link,
                    s_orig,
                )
                logger.error(exc)
                continue
            logger.info('  Done')
        logger.info('Symlinks created')
