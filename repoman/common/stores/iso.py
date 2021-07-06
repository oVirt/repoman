# encoding:utf-8
"""
This module holds the class and methods to manage an iso store::

    repository_dir
    └── iso
        ├── $project1
        │   │   ├── $version
        │   │   |   ├── $iso1
        │   |   │   ├── $iso1.md5sum
        │   │   |   └── $iso1.md5sum.sig
        │   │   └── ...
        │   └── ...
        └── ...
"""
import os
import re
import logging
from six import iteritems
from getpass import getpass
from . import ArtifactStore
from ..utils import (
    save_file,
    list_files,
    sign_detached,
)
from ..artifact import (
    Artifact,
    ArtifactName,
    ArtifactList,
)


logger = logging.getLogger(__name__)


ISO_REGEX = \
    r'(.*/)?(?P<name>[^\d/]+).(?P<version>\d[^fc|el]*)'\
    r'(?P<distro>\.(fc|el)\d+)?\.iso'


class WrongIsoError(Exception):
    """
    Any iso failure
    """
    pass


class Iso(Artifact):
    def __init__(self, path, temp_dir, verify_ssl=True):
        nv_match = re.match(ISO_REGEX, path)
        if not nv_match:
            raise WrongIsoError(
                "Can't extract name and version from %s"
                % path,
            )
        self._name = nv_match.groupdict().get('name')
        self._version = nv_match.groupdict().get('version')
        self._distro = nv_match.groupdict().get('distro')
        if self._distro:
            self._distro = self._distro.rsplit('.')[1]
        super(Iso, self).__init__(
            path=path,
            temp_dir=temp_dir,
            verify_ssl=verify_ssl,
        )
        with open(self.path) as fdno:
            self.inode = os.fstat(fdno.fileno()).st_ino

    @property
    def name(self):
        return self._name

    @property
    def full_name(self):
        """
        Unique ISO Name.

        This property should uniquely identify an ISO entity, in the
        sense that if you have two isos with the same full_name they must
        package the same content or one of them is wrongly generated (the
        version was not bumped or something).
        """
        if self.distro:
            return '%s(%s %s %s)' %\
                (self.type, self.name, self.version, self.distro)
        else:
            return '%s(%s %s)' % (self.type, self.name, self.version)

    @property
    def version(self):
        return self._version

    @property
    def distro(self):
        return self._distro

    @property
    def extension(self):
        return '.iso'

    @property
    def type(self):
        return 'iso'

    def generate_path(self):
        """
        Returns the theoretical path that the iso should be, instead of the
        current path it is. As explained at the module docs.
        """
        if self.distro:
            return '{name}/{version}/{distro}/{name}-{version}.{distro}.iso'\
                .format(
                    name=self.name,
                    version=self.version,
                    distro=self.distro,
                )
        else:
            return '{name}/{version}/{name}-{version}.iso'.format(
                name=self.name,
                version=self.version,
            )

    def sign(self, key, passwd):
        with open(self.path + '.md5sum', 'w') as md5_fd:
            md5_fd.write(self.md5)
        sign_detached(self.path + '.md5sum', key=key, passphrase=passwd)


class IsoStore(ArtifactStore):
    """
    Represents the repository sctructure, it does not require that the repo has
    the structure specified in the module doc when loading it, but when adding
    new isos it will create the new files in that directory structure.

    Configuration options:

    * temp_dir
        Temporary dir to store any transient downloads (like isos from
        urls). The caller should make sure it exists and clean it up if needed.

    * path_prefix
        Prefixes of this store inside the globl artifact repository, separated
        by commas

    * signing_key
        Path to the gpg keey to sign the isos with, will not sign them if not
        set

    * signing_passphrase
        Passphrase for the above key
    """

    CONFIG_SECTION = 'IsoStore'
    DEFAULT_CONFIG = {
        'temp_dir': 'generate',
        'path_prefix': 'iso',
        'signing_key': '',
        'signing_passphrase': 'ask',
    }

    def __init__(self, config, repo_path=None):
        """
        :param path: Path to the repository directory, if passed it will
            automatically add all the isos under it to the repo if any.
        """
        ArtifactStore.__init__(
            self,
            config=config,
            artifacts=ArtifactList('isos'),
        )
        self.name = self.__class__.__name__
        self._path_prefix = config.get('path_prefix').split(',')
        self.path = repo_path or ('Non persisten %s' % self.name)
        self.to_copy = []
        self.sign_key = config.get('signing_key')
        self.sign_passphrase = config.get('signing_passphrase')
        if self.sign_key and self.sign_passphrase == 'ask':
            self.sign_passphrase = getpass('Key passphrase: ')
        if repo_path:
            logger.info('Loading repo %s', repo_path)
            for iso in list_files(repo_path, '.iso', ignore_links=True):
                self.add_artifact(
                    iso,
                    to_copy=False,
                    hidelog=True,
                )
            logger.info('Repo %s loaded', repo_path)

    @property
    def path_prefix(self):
        return self._path_prefix

    def handles_artifact(self, artifact_str):
        logger.debug('Checking if %s is an iso', artifact_str)
        res = re.match(ISO_REGEX, artifact_str)
        if res:
            logger.debug('  It is')
            return True
        else:
            logger.debug('  It is not')
            return False

    def add_artifact(self, iso, **args):
        self.add_iso(iso, **args)

    def add_iso(self, iso, onlyifnewer=False, to_copy=True, hidelog=False):
        """
        Generic functon to add an iso package to the repo.

        :param iso: path or url to the iso file to add
        :param onlyifnewer: If set to True, will only add the package if it's
            not there already or the version is newer than the on already
            there.
        :param to_copy: If set to True, will add that package to the list of
            packages to copy into the repo when saving, usually used when
            adding new packages to the repo.
        :param hidelog: If set to True will not show the extra information
            (used when loading a repository to avoid verbose output)
        """
        iso = Iso(
            iso,
            temp_dir=self.config.get('temp_dir'),
            verify_ssl=self.config.getboolean('verify_ssl')
        )
        if self.artifacts.add_pkg(iso, onlyifnewer):
            if to_copy:
                self.to_copy.append(iso)
            if not hidelog:
                logger.info('Adding iso %s to repo %s', iso.path, self.path)
        else:
            if not hidelog:
                logger.info("Not adding %s, there's already an equal or "
                            "newer version", iso)

    def save(self, **args):
        self._save(**args)

    def _save(self, onlylatest=False):
        """
        Copy all the extra isos added to the repository and save it's state.

        :param onlylatest: Only copy the latest version of the added isos.
        """
        logger.info('Saving new added isos into %s', self.path)
        for iso in self.to_copy:
            if onlylatest and not self.is_latest_version(iso):
                logger.info('Skipping %s a newer version is already '
                            'in the repo.', iso)
                continue
            dst_path = os.path.join(self.path,
                                    self.path_prefix[0],
                                    iso.generate_path())
            save_file(iso.path, dst_path)
            iso.path = dst_path
        if self.sign_key:
            logger.info('')
            logger.info('Signing isos')
            self.sign_isos()
        logger.info('')
        logger.info('Saved %s\n', self.path)

    def is_latest_version(self, iso):
        """
        Check if the given iso is the latest version in the repo

        :param iso: ISO instance of the package to compare
        """
        verlist = self.artifacts.get(iso.full_name, {})
        if not verlist or iso.version in verlist.get_latest():
            return True
        return False

    def delete_old(self, keep=1, noop=False):
        """
        Delete the oldest versions for each package from the repo

        :param keep: Maximium number of versions to keep of each package
        :param noop: If set, will only log what will be done, not actually
            doing anything.
        """
        new_isos = ArtifactList(self.artifacts)
        for name, versions in iteritems(self.artifacts):
            if len(versions) <= keep:
                continue
            to_keep = ArtifactName()
            for _ in range(keep):
                latest = versions.get_latest()
                to_keep.update(latest)
                versions.next(iter(latest))
            new_isos[name] = to_keep
            for version in versions:
                logger.info('Deleting %s version %s', name, version)
                versions.del_version(version, noop)
        self.artifacts = new_isos

    def get_artifacts(self, regmatch=None, fmatch=None):
        """
        Get the list of isos, filtered or not.

        :param regmatch: Regular expression that will be applied to the path of
            each package to filter it
        :param fmatch: Filter function that must return True for a package to
            be selected, will be passed the iso object as only parameter
        """
        return self.artifacts.get_artifacts(
            regmatch=regmatch,
            fmatch=fmatch)

    def get_latest(self, regmatch=None, fmatch=None, num=1):
        """
        Return the num latest versions for each iso in the repo

        :param num: number of latest versions to return
        """
        return self.artifacts.get_artifacts(
            regmatch=regmatch,
            fmatch=fmatch,
            latest=num,
        )

    def sign_isos(self):
        """
        Sign all the isos in the repo.
        """
        passphrase = self.sign_passphrase
        for iso in self.get_artifacts():
            logger.info('Signing %s', iso)
            iso.sign(self.sign_key, passphrase)
        logger.info("Done signing")

    def change_path(self, new_path):
        """
        Changes the store path to the given one, copying any artifacts if
        needed

        Args:
            new_path (str): New path to set

        Returns:
            None
        """
        self.path = new_path
        self.to_copy.extend(self.get_artifacts())
