#!/bin/bash
PATH=$PATH:/usr/local/bin
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
NODEIP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
VAULT_CERTS=$(aws ssm get-parameter --name /${CLUSTER_TAG_VALUE}/certificates --with-decryption | jq '.Parameter.Value')

echo $VAULT_CERTS | sed -e 's/\\n/\n/g' > /opt/vault/tls/bundle.crt
echo $VAULT_CERTS | jq -r '.cert_bundle.ca' | sed -e 's/\\n/\n/g' > /opt/vault/tls/ca.crt.pem
echo $VAULT_CERTS | jq -r '.cert_bundle.private' | sed -e 's/\\n/\n/g' > /opt/vault/tls/vault.key.pem
echo $VAULT_CERTS | jq -r '.cert_bundle.public' | sed -e 's/\\n/\n/g' > /opt/vault/tls/vault.crt.pem



cat << EOF > /opt/vault/config/vault.hcl
storage "raft" {
  path = "/opt/vault/data"
  node_id = "$NODEIP"
  retry_join {
     auto_join = "provider=aws tag_key=${CLUSTER_TAG_KEY} tag_value=${CLUSTER_TAG_VALUE}"
     auto_join_scheme = "http"
  }
}
listener "tcp" {
  address        = "0.0.0.0:8200"
  #tls_cert_file  = "/opt/vault/tls/vault.crt.pem"
  #tls_key_file   = "/opt/vault/tls/vault.key.pem"
  tls_disable = true
}
seal "awskms" {
  region     = "${REGION}"
  kms_key_id = "${KMSID}"
}

ui=true
disable_mlock    = true
api_addr         = "http://$NODEIP:8200"
cluster_addr     = "http://$NODEIP:8201"
license_path     = "/opt/vault/config/license.hclic"
EOF

aws ssm get-parameter --name vault-license --with-decryption | jq -r '.Parameter.Value' > /opt/vault/config/license.hclic
chown -R vault:vault /opt/vault
runuser -u vault -- vault server -config /opt/vault/config/vault.hcl 