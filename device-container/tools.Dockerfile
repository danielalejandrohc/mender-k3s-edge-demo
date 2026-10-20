# kustomize + mender-artifact, the same versions the GitHub Actions workflow installs
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSLo /tmp/mender-artifact.deb \
      "https://downloads.mender.io/repos/workstation-tools/pool/main/m/mender-artifact/mender-artifact_4.4.0-2+ubuntu+noble_amd64.deb" \
 && apt-get install -y /tmp/mender-artifact.deb \
 && curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.4.1/kustomize_v5.4.1_linux_amd64.tar.gz" \
      | tar -xz -C /usr/local/bin kustomize \
 && rm -rf /tmp/mender-artifact.deb /var/lib/apt/lists/*
