#!/usr/bin/env bash
# Local equivalent of .github/workflows/deploy.yml, targeting the container device.
# Builds output/app-nginx-<TAG>.mender; also uploads and deploys it when
# MENDER_TOKEN (personal access token) and MENDER_DEVICE_GROUP are set.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."

TAG="${TAG:-local-$(date +%Y%m%d-%H%M%S)}"
PLATFORM="${PLATFORM:-linux/amd64}"
MENDER_DEVICE_TYPE="${MENDER_DEVICE_TYPE:-generic-x86_64}"
MENDER_SERVER_URL="${MENDER_SERVER_URL:-https://hosted.mender.io}"
ARTIFACT_NAME="app-nginx-$TAG"

mkdir -p payload/overlay output

# build + save rather than `buildx --output type=docker,dest=...`, which the default
# "docker" buildx driver rejects
docker build --platform "$PLATFORM" --tag "nginx-edge:$TAG" app/
docker save -o payload/image.tar "nginx-edge:$TAG"

# Pin the tag in a throwaway overlay instead of running `kustomize edit` on the tracked one
cat > payload/overlay/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../k8s/overlays/edge
images:
  - name: nginx-edge
    newTag: $TAG
EOF

docker build -q -t mender-k3s-tools -f device-container/tools.Dockerfile device-container > /dev/null
docker run --rm -v "$PWD:/work" -w /work mender-k3s-tools sh -ec "
    kustomize build payload/overlay > payload/manifests.yaml
    mender-artifact write module-image \
        --type             k8s-workload \
        --compatible-types '$MENDER_DEVICE_TYPE' \
        --artifact-name    '$ARTIFACT_NAME' \
        --file             payload/image.tar \
        --file             payload/manifests.yaml \
        -o                 'output/$ARTIFACT_NAME.mender'"
echo "Artifact: output/$ARTIFACT_NAME.mender"

if [[ -n "${MENDER_TOKEN:-}" && -n "${MENDER_DEVICE_GROUP:-}" ]]; then
    curl -fsS -X POST -H "Authorization: Bearer $MENDER_TOKEN" \
        -F "artifact=@output/$ARTIFACT_NAME.mender" \
        "$MENDER_SERVER_URL/api/management/v1/deployments/artifacts"
    curl -fsS -X POST -H "Authorization: Bearer $MENDER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$ARTIFACT_NAME\", \"artifact_name\": \"$ARTIFACT_NAME\"}" \
        "$MENDER_SERVER_URL/api/management/v1/deployments/deployments/group/$MENDER_DEVICE_GROUP"
    echo "Deployed $ARTIFACT_NAME to group $MENDER_DEVICE_GROUP"
fi
