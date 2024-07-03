#!/bin/bash
PATH=$PATH:/usr/local/bin
export VAULT_SKIP_VERIFY=true
NODEIP=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r .network.interface[].ipv4.ipAddress[].privateIpAddress)
SUBID=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq -r .compute.subscriptionId)


az login --identity

cat << EOF > /opt/vault/config/vault.hcl
storage "raft" {
  path = "/opt/vault/data"
  node_id = "$NODEIP"
  retry_join {
  leader_tls_server_name  = "${LEADER_DNS_ADDR}"
  }
  retry_join {
  leader_api_addr  = "https://${LEADER_DNS_ADDR}"
  }
}
listener "tcp" {
  address        = "0.0.0.0:8200"
  tls_cert_file  = "/opt/vault/tls/vault.crt"
  tls_key_file   = "/opt/vault/tls/vault.key"
  #tls_disable = true
}
seal "azurekeyvault" {
  tenant_id      = "${TENANTID}"
  vault_name     = "${VAULTNAME}"
  key_name       = "${VAULTKEY}"
}
ui=true
disable_mlock    = true
api_addr         = "https://$NODEIP:8200"
cluster_addr     = "https://$NODEIP:8201"
license_path     = "/opt/vault/config/license.hclic"
EOF

az keyvault secret show --vault-name ${VAULTNAME} --name license | jq -r '.value' > /opt/vault/config/license.hclic
az keyvault secret show --vault-name ${VAULTNAME} --name tls-cert-file | jq -r '.value' | base64 -d > /opt/vault/tls/vault.crt
az keyvault secret show --vault-name ${VAULTNAME} --name tls-key-file | jq -r '.value' | base64 -d > /opt/vault/tls/vault.key


chown -R vault:vault /opt/vault
sudo /opt/vault/tls/update-certificate-store.sh --cert-file-path /opt/vault/tls/vault.crt
sudo -u vault vault server -tls-skip-verify -config /opt/vault/config/vault.hcl 