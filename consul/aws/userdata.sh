#!/bin/bash
PATH=$PATH:/usr/local/bin
NAME=${NAME}
ROLE=${ROLE}
DATACENTER=${CLUSTER_TAG_VALUE}

CONSUL_CA=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates/ca.pem --with-decryption | jq '.Parameter.Value' | tr -d '"')
CONSUL_CERT=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates/server-cert --with-decryption | jq '.Parameter.Value' | tr -d '"')
CONSUL_KEY=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates/server-key.pem --with-decryption | jq '.Parameter.Value' | tr -d '"')
CONSUL_LICENSE=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/license --with-decryption | jq -r '.Parameter.Value')
GOSSIP_ENCRYPTION_KEY=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/gossip-key --with-decryption | jq -r '.Parameter.Value')

echo $CONSUL_LICENSE > /opt/consul/config/license.hclic
export CONSUL_LICENSE_PATH=/opt/consul/config/license.hclic

# Remove ACL configuration
rm -f /opt/consul/config/acl.json
rm -f /opt/consul/config/tls.json


#Set Up Certscript 
echo $CONSUL_CA | sed -e 's/\\n/\n/g' > /opt/consul/tls/ca.pem
echo $CONSUL_CERT | sed -e 's/\\n/\n/g' > /opt/consul/tls/server-cert.pem
echo $CONSUL_KEY | sed -e 's/\\n/\n/g' > /opt/consul/tls/server-key.pem
#Set up Vault Agent
sed -i "s/VAULTADDR/${VAULT_ADDR}/g" /opt/vault/agent-config.hcl
sed -i "s/VAULTNAMESPACE/${VAULT_NAMESPACE}/g" /opt/vault/agent-config.hcl

# execute certscript
/opt/consul/tls/certscript.sh


# Import Trust
sudo bash /opt/consul/tls/update-certificate-store.sh --cert-file-path /opt/consul/tls/server-cert.pem

# Import License
echo "license_path = \"/opt/consul/config/license.hclic\"" >> /opt/consul/config/default.hcl

# Startup

/opt/consul/bin/run-consul.sh --server --cluster-tag-key "Name" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --datacenter $DATACENTER --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --ca-path "/opt/consul/tls/ca.pem" --cert-file-path "/opt/consul/tls/server-cert.pem" --key-file-path "/opt/consul/tls/server-key.pem"
