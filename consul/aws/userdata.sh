#!/bin/bash
PATH=$PATH:/usr/local/bin
NAME=${NAME}
ROLE=${ROLE}

CONSUL_CERTS=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates --with-decryption | jq '.Parameter.Value')
CONSUL_LICENSE=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/license --with-decryption | jq -r '.Parameter.Value')
CONSUL_GOSSIP=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/gossip-key --with-decryption | jq -r '.Parameter.Value')

echo $CONSUL_LICENSE > /opt/consul/config/license.hclic

# Remove ACL configuration
rm -f /opt/consul/config/acl.json
rm -f /opt/consul/config/tls.json


#Set Up Certscript 
sed -ie "s/ROLE/${ROLE}/g" /opt/consul/tls/certscript.sh
sed -ie "s/APPNAME/${NAME}/g" /opt/consul/tls/certscript.sh
sed -ie "s/VAULTADDR/${VAULT_ADDR}/g" /opt/consul/tls/certscript.sh
sed -ie "s/VAULTNAMESPACE/${VAULT_NAMESPACE}/g" /opt/consul/tls/certscript.sh
#Set up Vault Agent
sed -ie "s/VAULTADDR/${VAULT_ADDR}/g" /opt/vault/agent-config.hcl
sed -ie "s/VAULTNAMESPACE/${VAULT_NAMESPACE}/g" /opt/vault/agent-config.hcl

# execute certscript
/opt/consul/tls/certscript.sh

# Import Gossip Encryption Key
GOSSIP_ENCRYPTION_KEY=$CONSUL_GOSSIP

# Import Trust
sudo bash /opt/consul/tls/update-certificate-store.sh --cert-file-path /opt/consul/certificate.json

# Import License
echo "license_path = \"/opt/consul/config/license.hclic\"" >> /opt/consul/config/default.hcl

# Startup

/opt/consul/config/bin/run-consul --server --cluster-tag-key "${CLUSTER_TAG_KEY}" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --ca-path "/opt/consul/tls/ca.crt.pem" --cert-file-path "/opt/consul/tls/${NAME}.crt.pem" --key-file-path "/opt/consul/tls/${NAME}.key.pem"
