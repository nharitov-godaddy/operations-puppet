moduledir 'vendor_modules'

mod 'augeas_core',
    :git => 'https://github.com/puppetlabs/puppetlabs-augeas_core.git',
    :ref => 'v1.2.0'

mod 'augeasproviders_core',
    :git => 'https://github.com/voxpupuli/puppet-augeasproviders_core.git',
    :ref => 'v3.2.1'

mod 'concat',
    # NOTE: Deviates from upstream v7.3.0
    # TODO: migrate local fixes to gitlab.w.o and create a tag
    # also see https://github.com/b4ldr/puppetlabs-concat/tree/puppet5.5
    #
    # 1. f507466942dbdb0684a1d04ea3d96d62d0ec70fa.:
    #    This commit is reverted as the Regexp.match? operator is not availabe
    #    on ruby 2.3, this commit may be reverted, once all our stretch
    #    hosts are gone.
    :local => true
    # :git => 'https://github.com/puppetlabs/puppetlabs-concat',
    # :ref => 'v7.3.0'

mod 'dnsquery',
    :git => 'https://github.com/voxpupuli/puppet-dnsquery.git',
    :ref => 'v5.0.1'

mod 'lvm',
    # NOTE: Deviates from upstream v1.4.0
    # TODO: migrate local fixes to gitlab.w.o and create a tag
    #
    # 1. 6d5f32c127099005dcab88dda381b4184e1ff1cd:
    #    Force volume group removal
    #
    # 2. 97a762cb7b4a78eaa173176bc0f77852dc5f38b0:
    #    Increase timeout for facts, adds --noheadings
    #
    :local => true
    # :git => 'https://github.com/puppetlabs/puppetlabs-lvm',
    # :ref => 'v1.4.0'

mod 'postfix',
    # NOTE: Forked from upstream, https://github.com/bodgit/puppet-postfix
    # TODO: migrate local fixes to gitlab.w.o and create a tag
    #
    # Contains three pull requests
    #
    #  1. Add Debian Bullseye(11) support
    #  2. Fix support for /etc/aliases
    #  3. Debian: don't install Augeas lens for unix-dgram
    :git => 'https://github.com/lollipopman/puppet-postfix',
    :ref => '6fa18a6'

mod 'puppetdbquery',
    :git => 'https://github.com/dalen/puppet-puppetdbquery.git',
    :ref => '3.0.1'

mod 'rspamd',
    :git => 'https://gitlab.wikimedia.org/repos/sre/puppet-rspamd.git',
    :ref => 'v1.3.1'

mod 'stdlib',
    :git => 'https://github.com/puppetlabs/puppetlabs-stdlib',
    :ref => 'v8.1.0'
