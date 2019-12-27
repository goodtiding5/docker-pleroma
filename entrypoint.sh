#!/bin/ash

set -e

WORKDIR=/opt/pleroma
DATADIR=/var/lib/pleroma

[ -d $DATADIR/static ]	|| mkdir -p $DATADIR/static
[ -d $DATADIR/uploads ]	|| mkdir -p $DATADIR/uploads

chown -R pleroma:pleroma $WORKDIR
chown -R pleroma:pleroma $DATADIR

if [[ -t 0 || -p /dev/stdin ]]; then
    # we have an interactive session
    export PS1='[\u@\h : \w]\$ '
    if [[ $@ ]]; then
	eval "exec $@"
    else
	exec /bin/sh
    fi
else
    if [[ $@ ]]; then
	eval "exec $@"
    else
	exec gosu pleroma /usr/local/bin/start_pleroma.sh
    fi
fi

# Will never reach here
exit 0



