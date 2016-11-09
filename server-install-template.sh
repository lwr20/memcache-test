#!/bin/bash
rpm -iUvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum update -y

# Install pre-reqs
yum install -y memcached tar ipset iptables conntrack-tools nc tcpdump docker-io

# Download and install felix pyinstaller bundle
curl -L __PYINSTALLER_URL__ -o /tmp/calico-felix.tgz
tar -xvzf /tmp/calico-felix.tgz -C /opt/

# Start docker
service docker start
chkconfig docker on

# Start memcached
service memcached start
chkconfig --levels 235 memcached on

# Run etcd (in a docker container)
docker run --detach \
--net=host \
--name calico-etcd quay.io/coreos/etcd:v2.3.6 \
--advertise-client-urls "http://127.0.0.1:2379" \
--listen-client-urls "http://127.0.0.1:2379"

# Make the directory for calico logs to appear in
mkdir -p /var/log/calico

# Create a felix init script:
cat > /etc/init/calico-felix.conf <<EOF
description "Calico Felix Agent"

start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]

limit nofile 32000 32000

respawn

pre-start script
  mkdir -p /var/run/calico
  chown root:root /var/run/calico
end script

script
  exec su -s /bin/sh -c "PATH=$PATH:/opt/calico-felix exec /opt/calico-felix/calico-felix" root
end script
EOF

# Start felix
initctl start calico-felix

# Set the felix Ready flag
curl http://127.0.0.1:2379/v2/keys/calico/v1/Ready -XPUT -d value="true"

