# SPDX-License-Identifier: Apache-2.0
# @summary profile for sretest hosts
class profile::sretest {
    $cache_nodes = lookup('cache::nodes')  # lint:ignore:wmf_styleguide
    file { '/var/tmp/testing':
        ensure  => directory,
        recurse => true,
        purge   => true,
    }
    wmflib::resource::export('file', '/var/tmp/testing/wmflib_export_test.txt', 'sretest', {
        'ensure' => 'file',
        content  => 'foo',
        tag      => 'foo::bar',
    })
    wmflib::resource::import('file', undef, { tag => 'foo::bar' })
    wmflib::resource::export('file', '/var/tmp/testing/wmflib_export_merge_cotent_test.txt', 'sretest', {
        'ensure'  => 'file',
        'content' => "${facts['networking']['fqdn']}\n",
        'tag'     => 'foo::bar::merge',
    })
    wmflib::resource::import('file', undef, { tag => 'foo::bar::merge' }, true)

    file {'/tmp/httpasswd_test.txt':
        ensure  => file,
        content => htpasswd('foobar', 'salty123'),
    }
    # Test binary file content
    file { '/tmp/delete_me_jbond':
        content => secret('cassandra/restbase/truststore'),
        mode    => '0400',
    }
}
