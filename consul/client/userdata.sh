#!/bin/bash
PATH=$PATH:/usr/local/bin
NAME=${NAME}
ROLE=${ROLE}
DATACENTER=${CLUSTER_TAG_VALUE}

CONSUL_CERT=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates --with-decryption | jq '.Parameter.Value')
CONSUL_KEY=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/keys --with-decryption | jq '.Parameter.Value')
CONSUL_LICENSE=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/license --with-decryption | jq -r '.Parameter.Value')
GOSSIP_ENCRYPTION_KEY=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/gossip-key --with-decryption | jq -r '.Parameter.Value')


echo $CONSUL_CERT > /opt/consul/tls/consul-agent-ca.pem
echo $CONSUL_KEY > /opt/consul/tls/consul-agent-ca-key.pem
echo $CONSUL_LICENSE > /opt/consul/config/license.hclic
export CONSUL_LICENSE_PATH=/opt/consul/config/license.hclic

# Remove ACL configuration
rm -f /opt/consul/config/acl.json
rm -f /opt/consul/config/tls.json

# Startup

/opt/consul/bin/run-consul.sh --cluster-tag-key "Name" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --datacenter $DATACENTER --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --cert-file-path "/opt/consul/tls/consul-agent-ca.pem" --key-file-path "/opt/consul/tls/consul-agent-ca-key.pem"
