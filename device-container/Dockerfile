# Virtual "edge device": Mender client (mender-auth/update/connect) + a single-node k3s,
# in one privileged container. Stands in for the Raspberry Pi from the main README.
# Build context is the repository root (see docker-compose.yml).
FROM mendersoftware/mender-client-docker-addons:latest

ARG K3S_VERSION=v1.35.9+k3s1
ARG TARGETARCH

# k3s is a multi-call binary: kubectl, ctr and crictl are symlinks to it
RUN asset=k3s; [ "$TARGETARCH" = arm64 ] && asset=k3s-arm64; \
    curl -fsSLo /usr/local/bin/k3s \
      "https://github.com/k3s-io/k3s/releases/download/$(echo "$K3S_VERSION" | sed 's/+/%2B/')/$asset" \
 && chmod 755 /usr/local/bin/k3s \
 && for c in kubectl ctr crictl; do ln -sf k3s "/usr/local/bin/$c"; done

# Same update module and inventory script the Raspberry Pi image gets
COPY --chmod=755 mender/k8s-update-module \
     /usr/share/mender/modules/v3/k8s-workload
COPY --chmod=755 mender/convert-overlay/rootfs_overlay/usr/share/mender/inventory/mender-inventory-k8s-app \
     /usr/share/mender/inventory/mender-inventory-k8s-app

COPY --chmod=755 device-container/k3s-entrypoint.sh /k3s-entrypoint.sh

# A checkout made by Git for Windows (core.autocrlf=true) has CRLF scripts: "#!/bin/sh\r"
RUN sed -i 's/\r$//' /k3s-entrypoint.sh \
      /usr/share/mender/modules/v3/k8s-workload \
      /usr/share/mender/inventory/mender-inventory-k8s-app

# containerd's overlayfs snapshotter cannot sit on Docker's overlayfs: these must be volumes
VOLUME ["/var/lib/rancher/k3s", "/var/lib/kubelet", "/var/lib/cni"]

CMD ["/k3s-entrypoint.sh"]
