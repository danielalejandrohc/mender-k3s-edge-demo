#!/bin/sh
# Starts k3s in the background, then hands over to the Mender client image's own
# /entrypoint.sh (mender-auth, mender-update, mender-connect).
set -e

# cgroup v2: k3s only evacuates the root cgroup itself when it is PID 1, which it is not
# here. Same fix k3d applies (from moby's dind script).
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    mkdir -p /sys/fs/cgroup/init
    xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || :
    sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
        > /sys/fs/cgroup/cgroup.subtree_control
fi

(
    while true; do
        k3s server --write-kubeconfig-mode=644 $K3S_ARGS >> /var/log/k3s.log 2>&1 \
            || echo "[k3s-entrypoint] k3s exited $?, restarting in 5s" >&2
        sleep 5
    done
) &

# STANDALONE=true: no server connection; install artifacts by hand with
#   mender-update install /path/to/artifact.mender
if [ "$STANDALONE" = "true" ]; then
    echo "[k3s-entrypoint] standalone mode: Mender daemons not started"
    wait
fi

exec /entrypoint.sh
