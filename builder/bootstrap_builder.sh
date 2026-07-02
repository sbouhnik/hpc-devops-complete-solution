#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git build-essential fakeroot devscripts equivs wget curl python3 python3-pip podman \
  libmunge-dev libmunge2 munge mariadb-client libmariadb-dev libpam0g-dev libjson-c-dev libhttp-parser-dev \
  libyaml-dev libjwt-dev liblz4-dev libhwloc-dev lua5.3 liblua5.3-dev pkg-config equivs
mkdir -p /vagrant/artifacts/debs /vagrant/artifacts/images
cd /tmp
if [ ! -d slurm ]; then git clone --depth 1 https://github.com/SchedMD/slurm.git; fi
cd slurm
mk-build-deps -i -t "apt-get -y --no-install-recommends" debian/control || true
debuild -b -uc -us || true
cp -v /tmp/*.deb /vagrant/artifacts/debs/ || true
cd /vagrant/gateway
podman build  --isolation=chroot -t metrics-gateway:local .
podman save metrics-gateway:local -o /vagrant/artifacts/images/metrics-gateway.tar
shutdown -h now || true
