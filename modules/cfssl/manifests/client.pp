# @summary configure cfssl client
# @param ensure whether to ensure the resource
# @param conf_dir location of the configuration directory
# @param auth_key The sha256 hmac key
class cfssl::client (
    Stdlib::HTTPUrl      $signer,
    Stdlib::HTTPUrl      $bundles_source,
    Sensitive[String[1]] $auth_key,
    Wmflib::Ensure       $ensure    = 'present',
    Cfssl::Loglevel      $log_level = 'info',
) {
    include cfssl
    $conf_file = "${cfssl::conf_dir}/client-cfssl.conf"
    $default_auth_remote = {'remote' => 'default_remote', 'auth_key' => 'default_auth'}
    # for now we need to unwrap the sensitive value otherwise it is not interpreted
    # Related bug: PUP-8969
    $auth_keys = {'default_auth'     => { 'type' => 'standard', 'key' => $auth_key.unwrap}}
    $remotes = {'default_remote' => $signer}
    cfssl::config {'client-cfssl':
        default_auth_remote => $default_auth_remote,
        auth_keys           => $auth_keys,
        remotes             => $remotes,
        path                => $conf_file,
    }
    file {'/usr/local/sbin/cfssl-client':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0550',
        content => "#!/bin/sh\n/usr/bin/cfssl \"$@\" -config ${conf_file}";
    }
}
