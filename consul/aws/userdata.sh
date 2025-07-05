#!/bin/bash
PATH=$PATH:/usr/local/bin

CONSUL_CERTS=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates --with-decryption | jq '.Parameter.Value')
CONSUL_LICENSE=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/license --with-decryption | jq -r '.Parameter.Value')
CONSUL_GOSSIP=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/gossip-key --with-decryption | jq -r '.Parameter.Value')


echo $CONSUL_CERTS | sed -e 's/\\n/\n/g' > /opt/consul/tls/bundle.crt
echo $CONSUL_CERTS | jq -r '.cert_bundle.ca' | sed -e 's/\\n/\n/g' > /opt/consul/tls/ca.crt.pem
echo $CONSUL_CERTS | jq -r '.cert_bundle.private' | sed -e 's/\\n/\n/g' > /opt/consul/tls/consul.key.pem
echo $CONSUL_CERTS | jq -r '.cert_bundle.public' | sed -e 's/\\n/\n/g' > /opt/consul/tls/consul.crt.pem
echo $CONSUL_LICENSE > /opt/consul/config/license.hclic

# Remove ACL configuration
rm -f /opt/consul/config/acl.json
rm -f /opt/consul/config/tls.json


#Set Up Certscript 
sed -ie "s/ROLE/$ROLE/g" /opt/consul/tls/certscript.sh
sed -ie "s/NAME/$NAME/g" /opt/consul/tls/certscript.sh
sed -ie "s/VAULTADDR/$VAULT_ADDR/g" /opt/consul/tls/certscript.sh
#Set up Vault Agent
sed -ie "s/VAULTADDR/$VAULT_ADDR/g" /opt/vault/agent-config.hcl


# Import Gossip Encryption Key
GOSSIP_ENCRYPTION_KEY=$CONSUL_GOSSIP

# Import Trust
sudo /tmp/update-certificate-store --cert-file-path /opt/consul/config/tls/ca.crt.pem 

# Import License
echo "license_path = \"/opt/consul/config/license.hclic\"" >> /opt/consul/config/default.hcl

# Startup

/opt/$NAME/config/bin/run-consul --server --cluster-tag-key "${CLUSTER_TAG_KEY}" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --ca-path "/opt/$NAME/tls/ca.crt.pem" --cert-file-path "/opt/$NAME/tls/$NAME.crt.pem" --key-file-path "/opt/$NAME/tls/$NAME.key.pem"
