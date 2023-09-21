#!/bin/sh

active_host="$(cat /etc/icinga/active_host)"
test -n "${active_host}" || exit 1

# Bail out if Icinga configuration is not valid, it would not restart
if ! /usr/sbin/icinga -v /etc/icinga/icinga.cfg > /dev/null 2>&1; then
    echo "Icinga configuration contains errors, skipping sync"
    exit 1
fi

# Stop the service first to avoid inconsistencies
/usr/sbin/service icinga stop
/usr/bin/rsync -a rsync://${active_host}/icinga-tmpfs/status.dat /var/icinga-tmpfs/status.dat
/usr/bin/rsync -a rsync://${active_host}/icinga-cache/objects.cache /var/cache/icinga/objects.cache
/usr/bin/rsync -a rsync://${active_host}/icinga-lib/retention.dat /var/lib/icinga/retention.dat
/usr/sbin/service icinga start

# icinga's init script 'stop' deletes the external commands named pipe after
# icinga has stopped listening to it.  This means any nsca subprocesses that
# were launched after that will be blocked forever trying to open() a pipe that
# has no listener.  SIGSTOP will cause that open() to error with EINTR and they
# will retry.
/usr/bin/killall -STOP nsca
/usr/bin/killall -CONT nsca
