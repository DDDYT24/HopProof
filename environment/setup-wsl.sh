#!/usr/bin/env bash
# HopProof environment preparation. Run as root only inside the dedicated WSL distribution.
set -euo pipefail
test "${WSL_DISTRO_NAME:-}" = NetOpsLab24 || { echo 'Expected dedicated NetOpsLab24 WSL environment' >&2; exit 2; }
test "$(id -u)" = 0
. /etc/os-release
test "$ID:$VERSION_ID" = ubuntu:24.04
export DEBIAN_FRONTEND=noninteractive
export USER=root
apt-get update
apt-get install -y ca-certificates curl gnupg sudo python3.12 python3.12-venv openssh-client iproute2 util-linux
install -m 0755 -d /etc/apt/keyrings
curl --fail --show-error --location --max-time 60 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
download_dir=$(mktemp -d)
trap 'rm -f "$download_dir/containerlab.deb" "$download_dir/checksums.txt"; rmdir "$download_dir"' EXIT
curl --fail --show-error --location --max-time 180 https://github.com/srl-labs/containerlab/releases/download/v0.80.0/containerlab_0.80.0_linux_amd64.deb -o "$download_dir/containerlab.deb"
curl --fail --show-error --location --max-time 60 https://github.com/srl-labs/containerlab/releases/download/v0.80.0/checksums.txt -o "$download_dir/checksums.txt"
expected=$(awk '$2 == "containerlab_0.80.0_linux_amd64.deb" {print $1}' "$download_dir/checksums.txt")
test -n "$expected"
printf '%s  %s\n' "$expected" "$download_dir/containerlab.deb" | sha256sum --check
apt-get install -y "$download_dir/containerlab.deb"
id netops >/dev/null 2>&1 || useradd --create-home --shell /bin/bash netops
usermod -aG docker netops
usermod -aG clab_admins netops
printf 'netops ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/netops-lab
chmod 0440 /etc/sudoers.d/netops-lab
visudo -cf /etc/sudoers.d/netops-lab
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true
[user]
default=netops
EOF
printf '{"project":"netops-operations-lab","wsl_distribution":"NetOpsLab24"}\n' > /etc/netops-lab.json
systemctl enable --now docker
python3.12 -m venv /opt/netops-lab-venv
chown -R netops:netops /opt/netops-lab-venv
docker version
containerlab version
