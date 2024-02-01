# SPDX-License-Identifier: Apache-2.0
# Expects address without a length, like address => "208.80.152.10", prefixlen => "32"
define interface::ip($interface, $address, $prefixlen='32', $options=undef, $ensure='present') {
    $prefix = "${address}/${prefixlen}"
    if $options {
        $options_real = "${options} "
    } else {
        $options_real = ''
    }
    $ipaddr_command = "ip addr add ${prefix} ${options_real}dev ${interface}"

    if $ensure == 'absent' {
      $ipaddr_del_command = "ip addr del ${prefix} dev ${interface}"

      file_line { "rm_${interface}_${prefix}":
        ensure            => absent,
        path              => '/etc/network/interfaces',
        match             => $ipaddr_command,
        match_for_absence => true,
      }

      exec { $ipaddr_del_command:
          path    => '/bin:/usr/bin',
          returns => [0, 2],
          onlyif  => "ip address show ${interface} | grep -q ${prefix}",
      }

    } else { # By default, add the IP
      # Use augeas to add an 'up' command to the interface
      augeas { "${interface}_${prefix}":
          incl    => '/etc/network/interfaces',
          lens    => 'Interfaces.lns',
          context => "/files/etc/network/interfaces/*[. = '${interface}' and ./family = 'inet']",
          changes => "set up[last()+1] '${ipaddr_command}'",
          onlyif  => "match up[. = '${ipaddr_command}'] size == 0";
      }

      # Add the IP address manually as well
      exec { $ipaddr_command:
          path    => '/bin:/usr/bin',
          returns => [0, 2],
          unless  => "ip address show ${interface} | grep -q ${prefix}",
      }

      # if the interface is managed by Puppet, ensure it's created first
      Exec <| tag == "interface-create-${interface}" |>
        -> Exec[$ipaddr_command]
    }
}
