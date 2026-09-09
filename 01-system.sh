#!/bin/bash

### Use Ubuntu 24.04 as base

apt-get update
apt-get install -y joe jq yq open-iscsi nfs-common cifs-utils cryptsetup && systemctl enable iscsid
echo 'dm_crypt' > /etc/modules-load.d/dm_crypt.conf
echo 'iscsi_tcp' > /etc/modules-load.d/iscsi_tcp.conf
modprobe iscsi_tcp
modprobe dm_crypt

systemctl disable multipathd.service
systemctl disable multipathd.socket

ln -snf /usr/share/zoneinfo/Europe/Helsinki /etc/localtime
echo "Europe/Helsinki" > /etc/timezone

sed -i -e 's/^# \(fi_.*\)$/\1/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale
echo "#LC_TIME=fi_FI.UTF-8" >> /etc/default/locale

### Other Tools
apt-get -y install \
  iptables iproute2 net-tools \
  argon2 apache2-utils sqlite3 \
  sshpass ansible libssl-dev

cat <<'EOF' > /etc/sysctl.d/20-inotify.conf
fs.inotify.max_user_watches=60086
fs.inotify.max_user_instances=1024
fs.inotify.max_queued_events=16384
EOF

# Force load modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/modules-load.d/rke2.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-rke2.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# Apply changes immediately
sudo sysctl --system

# Turn off Swap (Required by Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


grep -q "alias df"       ~/.profile || echo "alias df='df -x overlay -x tmpfs -x vfat -x efivarfs'" >> ~/.profile
grep -q "alias kubeseal" ~/.profile || echo "alias kubeseal='kubeseal --controller-name=sealed-secrets -o yaml'" >> ~/.profile

### Kube Tools
snap install kubectl --classic
snap install kubeadm --classic
snap install helm --classic
helm plugin install https://github.com/chartmuseum/helm-push --verify=false
snap install kustomize
snap install aws-cli --classic
snap install google-cloud-cli --classic

## ArgoCD CLI
[ -e /usr/local/bin/argocd ] || (curl -L https://github.com/argoproj/argo-cd/releases/download/v2.1.6/argocd-linux-amd64 -o /usr/local/bin/argocd && chmod 755 /usr/local/bin/argocd)

## Minio
if [ ! -e /usr/local/bin/mc ]; then
	curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
	chmod 755 /usr/local/bin/mc
fi

## Kubeseal
VER=v0.16.0
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/${VER}/kubeseal-linux-amd64 -O kubeseal
install -o root -g root -m 755 kubeseal /usr/local/bin/kubeseal && rm -f kubeseal

## Buildah & Skopeo
#. /etc/os-release
#curl -sL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/Release.key|sudo apt-key add -
#sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
#sudo apt-get update -qq
#sudo apt-get -qq -y install buildah skopeo
