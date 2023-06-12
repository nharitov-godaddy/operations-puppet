# This class holds all the apt pinning for key packages in the Toolforge cluster

class profile::toolforge::apt_pinning {
    case debian::codename() {
        'bullseye': {
            $libpam_pkg_version       = 'version 1.4.0-9'
            $libpam_ldapd_pkg_version = 'version 0.9.11-1'
            $ldap_utils_pkg_version   = 'version 2.4.57+dfsg-3'
            $libnss3_pkg_version      = 'version 2:3.61-1'
            $libnfsidmap2_pkg_version = 'version 0.25-6'
            $libnss_db_pkg_version    = 'version 2.2.3pre1-6'
            $nfs_common_pkg_version   = 'version 1:1.3.4-6'
            $sssd_pkg_version         = 'version 2.4.1-2'
        }

        'buster': {
            $libpam_pkg_version       = 'version 1.3.1-5'
            $libpam_ldapd_pkg_version = 'version 0.9.10-2'
            $ldap_utils_pkg_version   = 'version 2.4.47+dfsg-3+deb10u1'
            $libnss3_pkg_version      = 'version 2:3.42.1-1+deb10u1'
            $libnfsidmap2_pkg_version = 'version 0.25-5.1'
            $libnss_db_pkg_version    = 'version 2.2.3pre1-6+b6'
            $nfs_common_pkg_version   = 'version 1:1.3.4-2.5'
            $sssd_pkg_version         = 'version 1.16.3-3.2'
        }
        default: {
            fail("${debian::codename()}: not supported")
        }
    }

    apt::pin { [
        'toolforge-sudo-ldap-pinning',
        'toolforge-nscd-pinning',
        'toolforge-python-ldap-pinning',
        'toolforge-ldapvi-pinning',
    ]:
        ensure   => absent,
        pin      => 'not used',
        priority => -1,
    }

    apt::pin { 'toolforge-libpam-pinning':
        package  => 'libpam-runtime libpam-modules* libpam0g',
        pin      => $libpam_pkg_version,
        priority => 1001,
    }
    apt::pin { 'toolforge-libpam-ldapd-pinning':
        package  => 'libpam-ldapd nslcd* libnss-ldapd',
        pin      => $libpam_ldapd_pkg_version,
        priority => 1001,
    }
    apt::pin { 'toolforge-libnss-db-pinning':
        package  => 'libnss-db',
        pin      => $libnss_db_pkg_version,
        priority => 1001,
    }
    apt::pin { 'toolforge-ldap-utils-pinning':
        package  => 'ldap-utils libldap*',
        pin      => $ldap_utils_pkg_version,
        priority => 1001,
    }
    apt::pin { 'toolforge-libnss3-pinning':
        package  => 'libnss3**',
        pin      => $libnss3_pkg_version,
        priority => 1001,
    }
    # sssd
    apt::pin { 'toolforge-sssd-pinning':
        package  => 'sssd*',
        pin      => $sssd_pkg_version,
        priority => 1001,
    }

    apt::pin { 'toolforge-nfs-common-pinning':
        package  => 'nfs-common',
        pin      => $nfs_common_pkg_version,
        priority => 1001,
    }
    apt::pin { 'toolforge-libnfsidmap2-pinning':
        package  => 'libnfsidmap2',
        pin      => $libnfsidmap2_pkg_version,
        priority => 1001,
    }
}
