ARG CEPH_IMG=quay.io/ceph/ceph
ARG CEPH_TAG=v19
FROM ${CEPH_IMG}:${CEPH_TAG}

COPY micro-osd.sh /
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
