#!/usr/bin/env python%
# encoding: utf-8
"""
This module holds the helper classes to represent a repository, that in our
case (oVirt) is a set of repositories, in the form::

    Base_dir
    ├── rpm
    │   └── $dist
    │       ├── repodata
    │       ├── SRPMS
    │       └── $arch
    └── src
        └── $name
            ├── $name-$version-src.tar.gz
            └── $name-$version-src.tar.gz.sig


This module has the classess that manage a set of rpms, ina hierarchical
fashion, in the order::

    name 1-* version 1-* inode 1-* rpm-instance

So that translated to classes, with the first being the placeholder for the
whole data structure, is::

    RPMList 1-* RPMName 1-* RPMVersion 1-* RPMInode 1-* RPM

All except the RPM class are implemented as subclasses of the python dict, so
as key-value stores.

For clarification, here's a dictionary like diagram::

    RPMList{
        name1: RPMName{
            version1: RPMVersion{
                inode1: RPMInode[RPM, RPM, ...]
                inode2: RPMInode[...]
            },
            version2: RPMVersion{...}
        },
        name2: RPMName{...}
    }

"""
import os
import logging
import re

import rpm
import pexpect
import subprocess

from ...utils import (
    download,
    cmpfullver,
    gpg_unlock,
    gpg_get_keyuid,
)
from ...artifact import (
    Artifact,
    ArtifactVersion,
    ArtifactList,
    ArtifactName,
)


class WrongDistroException(Exception):
    pass


class RPM(Artifact):
    def __init__(
        self,
        path,
        temp_dir='/tmp',
        distro_reg=r'\.(fc|el)\d+',
        to_all_distros=(),
        verify_ssl=True,
    ):
        """
        :param path: Path or url to the rpm
        :param temp_dir: If url specified, will use that temporary dir to store
            it, the caller should take care of creating and deleting that
            temporary dir if needed
        :param distro_regs: Regular expression to match the distributions from
           the release string of the rpm.
        :param to_all_distros: Special rpm names that must go to all the
            distributions ignoring their release strings
        """
        trans = rpm.TransactionSet()
        # Do not fail for unsigned rpms
        trans.setVSFlags(rpm._RPMVSF_NOSIGNATURES)
        if path.startswith('http:') or path.startswith('https:'):
            name = path.rsplit('/', 1)[-1]
            if not name:
                raise Exception('Passed trailing slash in path %s, '
                                'unable to guess package name'
                                % path)
            fpath = temp_dir + '/' + name
            download(path, fpath, verify=verify_ssl)
            path = fpath
        self.path = path
        with open(path) as fdno:
            try:
                hdr = trans.hdrFromFdno(fdno)
            except Exception:
                logging.error("Failed to parse header for %s", path)
                raise
            self.inode = os.fstat(fdno.fileno()).st_ino
        self.is_source = hdr[rpm.RPMTAG_SOURCEPACKAGE] and True or False
        self.sourcerpm = hdr[rpm.RPMTAG_SOURCERPM]
        self._name = hdr[rpm.RPMTAG_NAME]
        self._version = hdr[rpm.RPMTAG_VERSION]
        self.major_version = self._version.split('.', 1)[0]
        self.release = hdr[rpm.RPMTAG_RELEASE]
        self.signature = hdr[rpm.RPMTAG_SIGPGP]
        self._raw_hdr = hdr
        # will be calculated if needed
        self._md5 = None
        # Check if this package has to go to all distros
        if any((
            self._name
            for nreg in to_all_distros
            if re.match(nreg, self._name)
        )):
            self.distro = 'all'
        else:
            try:
                self.distro = self.get_distro(self.release, distro_reg)
            except WrongDistroException as e:
                logging.error(
                    'Wrong distribution for package: %s-%s',
                    self._name,
                    self._version
                )
                raise e
        self.arch = hdr[rpm.RPMTAG_ARCH] or 'none'
        # remove the distro from the release for the version string
        if self.distro:
            release = re.sub(
                r'\.%s[^.]*' % self.distro,
                '',
                self.release,
                1
            )
        else:
            release = self.release
        self.ver_rel = '%s-%s' % (self._version, release)
        with open(os.devnull, 'w') as devnull:
            output = subprocess.Popen(
                ["rpm", "-qip", path],
                stdout=subprocess.PIPE,
                stderr=devnull,
            ).communicate()[0]
        match = re.search("Key ID (?P<key_id>\w+)\\n", output)
        self.key_hex = None
        if match:
            self.key_hex = match.groupdict()['key_id'].upper()

    @property
    def name(self):
        return '%s.%s.%s' % (self._name, self.distro, self.arch)

    @property
    def full_name(self):
        """
        Unique RPM Name.

        This property should uniquely identify a rpm entity, in the sense
        that if you have two rpms with the same full_name they must package
        the same content or one of them is wrongly generated (the version was
        not bumped or something).
        """
        return 'rpm(%s %s %s %s)' % (self._name,
                                     self.distro,
                                     self.arch,
                                     self.is_source and 'src' or 'bin')

    @property
    def version(self):
        return self.ver_rel

    @property
    def extension(self):
        if self.is_source:
            return '.src.rpm'
        return '.rpm'

    @property
    def type(self):
        if self.is_source:
            return 'source_rpm'
        return 'rpm'

    @staticmethod
    def get_distro(release, distro_reg):
        match = re.search(distro_reg, release)
        if match:
            return match.group()[1:]
        raise WrongDistroException('Unknown distro for %s' % release)

    def generate_path(self, base_dir='rpm'):
        """
        Returns the theoretical path that the rpm should be, instead of the
        current path it is. As explained at the module docs.

        If the package has to go to all distros, a placeholder for it will be
        set in the string
        """
        if self.is_source:
            arch_path = 'SRPMS'
            arch_name = 'src'
        else:
            arch_path = self.arch
            arch_name = self.arch
        return '%s%s/%s/%s-%s-%s.%s.rpm' % (
            base_dir + '/' if base_dir else '',
            '%s' if self.distro == 'all' else self.distro,
            arch_path,
            self._name,
            self._version,
            self.release,
            arch_name,
        )

    def sign(self, key_path, passwd):
        logging.info("SIGNING: %s", self.path)
        gpg = gpg_unlock(key_path, passphrase=passwd)
        keyuid = gpg_get_keyuid(key_path, gpg=gpg)
        # Remove any existing signature from the rpm before signing it.
        # This is needed because is a signature already exist, even whith our
        # signature, when installing it yum raise an error like:
        # The GPG keys listed for the "oVirt 4.2 Pre-Release" repository are
        # already installed but they are not correct for this package.
        logging.debug('\nrpm --delsign %s\n' % (self.path,))
        with open(os.devnull, 'w') as devnull:
            res = subprocess.call(
                ['rpm', '--delsign', self.path],
                stdout=devnull,
            )
            if res != 0:
                raise Exception(
                    "rpm --delsign failed on %s with rc %d" % (self.path, res)
                )
        # Signing the rpm with out key
        rpmsign_args = [
            '--resign',
            '-D', '_signature gpg',
            '-D', '_gpg_name %s' % keyuid,
            # TODO: make this work with gpg2 too, fc>21 throws invalid ioctl
            '-D', '__gpg /usr/bin/gpg',
            self.path,
        ]
        logging.debug('\nrpmsign /\n' + ' /\n\t'.join(rpmsign_args))
        child = pexpect.spawn(
            'rpmsign',
            rpmsign_args,
            timeout=600,  # rpmsign may take a lot of time...
        )
        try:
            child.expect(
                ['pass phrase: ', 'passphrase: ', 'Passphrase: '],
                timeout=5,
            )
        except Exception as exc:
            logging.error('Failed to sign')
            logging.debug(child)
            # overriding as the default exception includes too much
            # info, as passwords passed
            exc.value = exc.value.replace(passwd, '*****')
            raise exc
        # For some reason, on fedora>21 rpmsign needs some tries until it
        # properly signs
        done = False
        tries = 1
        while not done:
            child.sendline(passwd)
            logging.debug('Sent pass to rpmsign, try number %d', tries)
            try:
                child.expect(pexpect.EOF, timeout=10)
                done = True
            except pexpect.TIMEOUT as exc:
                tries += 1
                # signing big rpms might take it's time
                if tries >= 900:
                    logging.error('Failed to sign')
                    logging.debug(child)
                    exc.value = exc.value.replace(passwd, '*****')
                    raise exc
        child.close()
        if child.exitstatus != 0:
            logging.debug(child)
            raise Exception("Failed to sign package.")
        self.__init__(self.path)
        if not self.signature:
            logging.error('Failed to sign')
            raise Exception(
                "Failed to sign rpm %s with key '%s'"
                % (self.path, keyuid)
            )
        del(gpg)

    def __str__(self):
        """
        This string uniquely identifies a rpm file, if two rpms have the same
        string representation, the must point to the same file or a copy of
        it, if not, you wrongly generated two rpms with the same
        version/release and different content, or you signed them with
        different keys
        """
        return 'rpm(%s %s %s %s %s %s)' % (
            self.name, self._version,
            self.release, self.arch,
            self.is_source and 'src' or 'bin',
            self.signature and 'signed' or 'unsigned',
        )

    def __repr__(self):
        return self.__str__()


class RPMName(ArtifactName):
    """List of available versions for a package name"""
    def add_pkg(self, pkg, onlyifnewer):
        is_there_newer = next(
            (
                ver for ver in self.keys()
                if cmpfullver(ver, pkg.ver_rel) >= 0
            ),
            False,
        )
        if onlyifnewer and (is_there_newer or pkg.ver_rel in self):
            return False
        elif pkg.ver_rel not in self:
            self[pkg.ver_rel] = ArtifactVersion(pkg.ver_rel)
        return self[pkg.ver_rel].add_pkg(pkg)

    def get_latest(self, num=1):
        """
        Returns the list of available inodes for the latest version
        if any
        """
        if not self:
            return None
        if not num:
            num = len(self)
        sorted_list = [
            ver_name for ver_name, version in self.items()
            if version.get_artifacts(
                fmatch=lambda art: not art.is_source
            )
        ]
        sorted_list.sort(cmp=cmpfullver)
        latest = {}
        if num > len(sorted_list):
            num = len(sorted_list)
        for pos in xrange(num):
            latest[sorted_list[pos]] = self.get(sorted_list[pos])
        return latest


class RPMList(ArtifactList):
    """
    List of rpms, separated by name
    """
    def __init__(self, name_class=RPMName):
        super(RPMList, self).__init__(self)
        self.name_class = name_class
