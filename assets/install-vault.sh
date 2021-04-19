IP=$(hostname -i)
PORT=8200
VERSION=1.6.3
export VAULT_ADDR=http://$IP:$PORT

echo "Fetching Vault..."
cd /tmp
curl -sLo vault.zip https://releases.hashicorp.com/vault/${VERSION}/vault_${VERSION}_linux_amd64.zip

echo "Installing Vault..."
unzip vault.zip >/dev/null
chmod +x vault
mv vault /usr/bin/vault

# Setup Vault
mkdir -p /tmp/vault-data
mkdir -p /etc/vault.d
cat >/etc/vault.d/config.json <<EOF
ui = true
storage "file" {
  path = "/tmp/vault-data"
}

listener "tcp" {
 address     = "$IP:$PORT"
 tls_disable = "true"
}
EOF

cat >/etc/systemd/system/vault.service <<EOF
[Unit]
Description = "Vault"

[Service]
# Stop vault will not mark node as failed but left
KillSignal=INT
ExecStart=/usr/bin/vault server -config=/etc/vault.d/config.json
Restart=always
ExecStopPost=/bin/sleep 5
EOF

echo "Starting Vault..."
systemctl daemon-reload
systemctl enable vault
systemctl start vault
while ! curl -s $VAULT_ADDR/sys/health; do
  sleep 1;
done

echo "Unsealing Vault..."
vault operator init >&/tmp/vault.txt
for i in $(grep Unseal /tmp/vault.txt | head -3 | cut -f 4 -d " "); do
  vault operator unseal $i
done
vault login $(grep Initial /tmp/vault.txt | cut -f 4 -d " ")
vault secrets enable -version=2 -path=secret kv

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: portworx
---
apiVersion: v1
kind: Secret
metadata:
  name: px-vault
  namespace: portworx
type: Opaque
data:
  VAULT_ADDR: $(base64 <<<$VAULT_ADDR)
  VAULT_TOKEN: $(grep Initial /tmp/vault.txt | cut -f 4 -d " " | base64)
  VAULT_BACKEND_PATH: $(base64 <<<secret)
EOF

echo "Setting up roles for Vault..."
kubectl create serviceaccount vault-auth -n kube-system
kubectl create clusterrolebinding vault-tokenreview-binding --clusterrole=system:auth-delegator --serviceaccount=kube-system:vault-auth

cat >/tmp/px-policy.hcl <<EOF
# Read and List capabilities on mount to determine which version of kv backend is supported
path "sys/mounts/"
{
capabilities = ["read", "list"]
}

# V2 backends (Using default backend )
# Provide full access to the data/portworx subkey
# Provide -> VAULT_BASE_PATH=portworx to PX (optional)
path "secret/*"
{
capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

vault policy write portworx /tmp/px-policy.hcl
echo "export VAULT_ADDR=$VAULT_ADDR" >>/root/.bashrc

echo "Vault configuration complete."
