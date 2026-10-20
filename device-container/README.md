# Container edge device

Replaces the Raspberry Pi with a Docker container so the **app update stream** can be
tried on a laptop: `mendersoftware/mender-client-docker-addons` (mender-auth, mender-update,
mender-connect) + a single-node k3s + this repo's `k8s-workload` update module and
inventory script. The container runs `--privileged` (k3s needs it).

| Raspberry Pi (main README)                         | Container                                     |
|----------------------------------------------------|-----------------------------------------------|
| `customize-image.sh` / `firstrun.sh` install k3s   | `Dockerfile` downloads the k3s binary         |
| `/data/k3s` partition                              | `k3s-data` volume                             |
| device type `raspberrypi4_64`, arm64 images        | device type `generic-x86_64`, amd64 images    |
| A/B rootfs OS updates                              | **not reproducible** — no bootloader or partitions |

## Offline (no Mender server)

```bash
cd device-container
STANDALONE=true docker compose up -d --build

cd ..
TAG=v1 bash device-container/build-artifact.sh          # -> output/app-nginx-v1.mender
docker cp output/app-nginx-v1.mender mender-k3s-device:/tmp/
docker exec mender-k3s-device mender-update install /tmp/app-nginx-v1.mender
curl localhost:8080
```

## Connected to hosted Mender

```bash
cd device-container
printf 'TENANT_TOKEN=%s\nSERVER_URL=https://hosted.mender.io\n' '<tenant token>' > .env
docker compose up -d --build
```

Accept the device (hostname `edge-docker-01`) in **Devices → Pending** and add it to a group. Then either:

- **GitHub Actions**: set the variables `MENDER_DEVICE_TYPE=generic-x86_64` and
  `TARGET_PLATFORM=linux/amd64`, then push to `main`. An arm64 image from buildx is rejected
  by the amd64 node (`ctr: image might be filtered out`).
- **From this machine**:
  `MENDER_TOKEN=<personal access token> MENDER_DEVICE_GROUP=<group> bash device-container/build-artifact.sh`

Useful commands:

```bash
docker exec -it mender-k3s-device kubectl get pods -A
docker exec mender-k3s-device tail -f /var/log/k3s.log
docker compose down        # add -v to also wipe the device identity and k3s state
```
