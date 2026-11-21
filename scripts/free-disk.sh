#!/bin/bash
# Frees the runner's disk before the build: removes preinstalled toolchains this build never uses (the build runs in
# Docker; nothing here uses .NET, Android, Haskell, Java, Swift, PowerShell, browsers or the cloud command-line tools),
# removes every preinstalled Docker image, and, when the runner has a second disk at /mnt with room, moves Docker's data
# there so the builder and the finished image have both disks.
set -uo pipefail
echo "== before"; df -h / /mnt 2>/dev/null || df -h /
sudo rm -rf \
  /usr/share/dotnet /usr/local/lib/android /opt/ghc /usr/local/.ghcup /opt/hostedtoolcache /usr/local/share/boost \
  /usr/lib/jvm /usr/local/lib/node_modules /usr/share/swift /usr/local/share/powershell /usr/local/share/chromium \
  /opt/microsoft /opt/google /opt/az /usr/local/julia* /usr/lib/google-cloud-sdk /usr/share/miniconda /opt/pipx \
  /usr/local/aws-cli /usr/local/aws-sam-cli /opt/mssql-tools /usr/local/share/vcpkg /usr/local/n /opt/actionarchivecache \
  2>/dev/null || true
sudo docker system prune --all --force --volumes >/dev/null 2>&1 || true
MNT_FREE_GB=$(df --output=avail -BG /mnt 2>/dev/null | tail -1 | tr -dc 0-9)
ROOT_DEV=$(df --output=source / | tail -1)
MNT_DEV=$(df --output=source /mnt 2>/dev/null | tail -1)
if [ -n "${MNT_FREE_GB}" ] && [ "${MNT_FREE_GB}" -ge 40 ] && [ "${MNT_DEV}" != "${ROOT_DEV}" ]; then
  echo "== Docker's data moves to /mnt (${MNT_FREE_GB} GB free there)"
  sudo systemctl stop docker docker.socket
  sudo mkdir -p /mnt/docker
  if [ -s /etc/docker/daemon.json ]; then
    sudo jq '. + {"data-root": "/mnt/docker"}' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.new >/dev/null
  else
    echo '{"data-root": "/mnt/docker"}' | sudo tee /etc/docker/daemon.json.new >/dev/null
  fi
  sudo mv /etc/docker/daemon.json.new /etc/docker/daemon.json
  sudo systemctl start docker
else
  echo "== Docker's data stays on / (/mnt: ${MNT_FREE_GB:-none} GB free, device ${MNT_DEV:-none})"
fi
echo "== after"; df -h / /mnt 2>/dev/null || df -h /
echo "Docker root: $(docker info -f '{{.DockerRootDir}}')"
ROOT_FREE=$(df --output=avail -BG / | tail -1 | tr -dc 0-9)
DOCKER_FREE=$(df --output=avail -BG "$(docker info -f '{{.DockerRootDir}}')" | tail -1 | tr -dc 0-9)
echo "free: / ${ROOT_FREE} GB, Docker's disk ${DOCKER_FREE} GB"
echo "DOCKER_FREE_GB=${DOCKER_FREE}" >> "${GITHUB_ENV:-/dev/null}"
