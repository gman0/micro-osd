#!/bin/bash

set -e

PAUSE="${PAUSE:-no}"
MICRO_OSD_PATH="${MICRO_OSD_PATH:-/micro-osd.sh}"
CEPH_CONF_ROOT="${CEPH_CONF:-/etc/ceph}"
MIRROR_STATE="${MIRROR_STATE:-/dev/null}"
CEPH_VERSION="${CEPH_VERSION:-pacific}"

show() {
    local ret
    echo "*** running:" "$@"
    "$@"
    ret=$?
    if [ ${ret} -ne 0 ] ; then
        echo "*** ERROR: returned ${ret}"
    fi
    return ${ret}
}

setup_mirroring() {
    mstate="$(cat "${MIRROR_STATE}" 2>/dev/null || true)"
    if [[ "$mstate" = functional ]]; then
        echo "Mirroring already functional"
        return 0
    fi
    echo "Setting up mirroring..."
    local CONF_A=${CEPH_CONF}
    local CONF_B=${MIRROR_CONF}
    ceph -c $CONF_A osd pool create rbd 8
    ceph -c $CONF_B osd pool create rbd 8
    rbd -c $CONF_A pool init
    rbd -c $CONF_B pool init
    rbd -c $CONF_A mirror pool enable rbd image
    rbd -c $CONF_B mirror pool enable rbd image
    rbd -c $CONF_A mirror pool peer bootstrap create --site-name ceph_a rbd > token
    rbd -c $CONF_B mirror pool peer bootstrap import --site-name ceph_b rbd token

    echo "enabled" > "${MIRROR_STATE}"
    rbd -c $CONF_A rm mirror_test 2>/dev/null || true
    rbd -c $CONF_B rm mirror_test 2>/dev/null || true
    (echo "Mirror Test"; dd if=/dev/zero bs=1 count=500K) | rbd -c $CONF_A import - mirror_test
    rbd -c $CONF_A mirror image enable mirror_test snapshot
    echo -n "Waiting for mirroring activation..."
    while ! rbd -c $CONF_A mirror image status mirror_test \
      | grep -q "state: \+up+replaying" ; do
        sleep 1
    done
    echo "done"
    rbd -c $CONF_A mirror image snapshot mirror_test
    echo -n "Waiting for mirror sync..."
    while ! rbd -c $CONF_B export mirror_test - 2>/dev/null | grep -q "Mirror Test" ; do
        sleep 1
    done
    echo "functional" > "${MIRROR_STATE}"
    echo " mirroring functional!"
}

if [[ ${MIRROR_CONF} && ${CEPH_VERSION} != nautilus ]]; then
    setup_mirroring
    export MIRROR_CONF
fi

show "${MICRO_OSD_PATH}" "$CEPH_CONF_ROOT"

ceph -s || true

echo "*** sleeping"
trap : TERM INT; (while true; do sleep 1000; done) & wait
