#!/bin/bash
PATH=$PATH:/usr/local/bin
NAME=${NAME}
ROLE=${ROLE}
DATACENTER=${CLUSTER_TAG_VALUE}

CONSUL_CERTS=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates --with-decryption | jq '.Parameter.Value')
CONSUL_LICENSE=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/license --with-decryption | jq -r '.Parameter.Value')
GOSSIP_ENCRYPTION_KEY=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/gossip-key --with-decryption | jq -r '.Parameter.Value')

echo $CONSUL_LICENSE > /opt/consul/config/license.hclic
export CONSUL_LICENSE_PATH=/opt/consul/config/license.hclic

# Remove ACL configuration
rm -f /opt/consul/config/acl.json
rm -f /opt/consul/config/tls.json


#Set Up Certscript 
sed -i "s/ROLE/${ROLE}/g" /opt/consul/tls/certscript.sh
sed -i "s/APPNAME/${NAME}/g" /opt/consul/tls/certscript.sh
sed -i "s/VAULTADDR/${VAULT_ADDR}/g" /opt/consul/tls/certscript.sh
sed -i "s/VAULTNAMESPACE/${VAULT_NAMESPACE}/g" /opt/consul/tls/certscript.sh
#Set up Vault Agent
sed -i "s/VAULTADDR/${VAULT_ADDR}/g" /opt/vault/agent-config.hcl
sed -i "s/VAULTNAMESPACE/${VAULT_NAMESPACE}/g" /opt/vault/agent-config.hcl

# execute certscript
/opt/consul/tls/certscript.sh


# Import Trust
sudo bash /opt/consul/tls/update-certificate-store.sh --cert-file-path /opt/consul/tls/certificate.json

# Import License
echo "license_path = \"/opt/consul/config/license.hclic\"" >> /opt/consul/config/default.hcl

# Startup

/opt/consul/bin/run-consul.sh --server --cluster-tag-key "Name" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --datacenter $DATACENTER --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --ca-path "/opt/consul/tls/${NAME}.demo.internal.crt" --cert-file-path "/opt/consul/tls/${NAME}.demo.internal.crt" --key-file-path "/opt/consul/tls/${NAME}.demo.internal.key"
