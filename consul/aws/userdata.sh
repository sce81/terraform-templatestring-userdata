#!/bin/bash
PATH=$PATH:/usr/local/bin

# Remove ACL configuration
rm -f /opt/$NAME/config/acl.json
rm -f /opt/$NAME/config/tls.json


#Pull from Secrets Manager
SECRETS=$(aws secretsmanager get-secret-value --secret-id ${SECRETID} --region=$REGION | jq '.SecretString | fromjson')


# Import Consul Certificates
echo $SECRETS | jq -r '.cert_bundle.private_key' | sed -e 's/\\n/\n/g' > /opt/$NAME/config/tls/$NAME.key.pem
echo $SECRETS | jq -r '.cert_bundle.certificate_body' | sed -e 's/\\n/\n/g' > /opt/$NAME/config/tls/$NAME.crt.pem
echo $SECRETS | jq -r '.cert_bundle.certificate_chain' | sed -e 's/\\n/\n/g' > /opt/$NAME/config/tls/ca.crt.pem

# Import Gossip Encryption Key
GOSSIP_ENCRYPTION_KEY=$(echo $SECRETS | jq -r '.gossip_encryption_key')

# Import Trust
sudo /tmp/update-certificate-store --cert-file-path /opt/consul/config/tls/ca.crt.pem 

# Import License
echo LICENSE | jq -r '.license' | sed -e 's/\\n/\n/g' > /opt/$NAME/config/license.hclic
echo "license_path = \"/opt/$NAME/config/license.hclic\"" >> /opt/$NAME/config/default.hcl

# Startup

/opt/$NAME/config/bin/run-consul --server --cluster-tag-key "${CLUSTER_TAG_KEY}" --cluster-tag-value "${CLUSTER_TAG_VALUE}" --enable-gossip-encryption --gossip-encryption-key "$GOSSIP_ENCRYPTION_KEY" --enable-rpc-encryption --ca-path "/opt/$NAME/config/tls/ca.crt.pem" --cert-file-path "/opt/$NAME/config/tls/$NAME.crt.pem" --key-file-path "/opt/$NAME/config/tls/$NAME.key.pem"
