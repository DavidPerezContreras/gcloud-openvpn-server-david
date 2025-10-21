#!/bin/bash
set -e

USERNAME="$1"
VPN_IP="35.227.9.221"
VPN_PORT="1194"
VPN_PROTO="udp"
EASYRSA_BIN="/usr/share/easy-rsa/easyrsa"
BASE_DIR="$(dirname "$0")/.."
PKI_DIR="$BASE_DIR/volume/pki"
TA_KEY="$BASE_DIR/volume/ta.key"
CLIENT_DIR="$BASE_DIR/clients/$USERNAME"

if [ -z "$USERNAME" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Ensure volume and PKI directories exist
mkdir -p "$BASE_DIR/volume"
mkdir -p "$PKI_DIR"

cd "$BASE_DIR"
export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="$USERNAME"
export EASYRSA_PKI="$PKI_DIR"

# Generate client cert and key
"$EASYRSA_BIN" build-client-full "$USERNAME" nopass

# Prepare client directory
mkdir -p "$CLIENT_DIR"
cp "$PKI_DIR/private/${USERNAME}.key" "$CLIENT_DIR/"
cp "$PKI_DIR/issued/${USERNAME}.crt" "$CLIENT_DIR/"
cp "$PKI_DIR/ca.crt" "$CLIENT_DIR/"

# Build .ovpn profile
cat > "$CLIENT_DIR/${USERNAME}.ovpn" <<EOF
client
nobind
dev tun
proto $VPN_PROTO
remote $VPN_IP $VPN_PORT
remote-cert-tls server

cipher AES-256-CBC
auth SHA256
data-ciphers AES-256-GCM:AES-128-GCM
data-ciphers-fallback AES-256-CBC

redirect-gateway def1
dhcp-option DNS 1.1.1.1
dhcp-option DNS 8.8.8.8

# IPv6 support
route-ipv6 2000::/3
dhcp-option DNS6 2606:4700:4700::1111
dhcp-option DNS6 2001:4860:4860::8888
EOF

# Embed CA, cert, key
{
  echo "<ca>"
  cat "$CLIENT_DIR/ca.crt"
  echo "</ca>"

  echo "<cert>"
  cat "$CLIENT_DIR/${USERNAME}.crt"
  echo "</cert>"

  echo "<key>"
  cat "$CLIENT_DIR/${USERNAME}.key"
  echo "</key>"
} >> "$CLIENT_DIR/${USERNAME}.ovpn"

# Embed TLS crypt key
if [ -f "$TA_KEY" ]; then
  echo "<tls-crypt>" >> "$CLIENT_DIR/${USERNAME}.ovpn"
  cat "$TA_KEY" >> "$CLIENT_DIR/${USERNAME}.ovpn"
  echo "</tls-crypt>" >> "$CLIENT_DIR/${USERNAME}.ovpn"
fi

echo "✅ OVPN profile for '$USERNAME' created at $CLIENT_DIR/${USERNAME}.ovpn"
