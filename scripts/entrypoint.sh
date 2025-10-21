#!/bin/bash
set -e

echo "Running entrypoint script..."

KEY_DIR="/etc/openvpn/keys"
PKI_DIR="$KEY_DIR/pki"
CONF_FILE="/etc/openvpn/server.conf"

# List of required files
REQUIRED_FILES=(
  "$PKI_DIR/ca.crt"
  "$PKI_DIR/issued/server.crt"
  "$PKI_DIR/private/server.key"
  "$PKI_DIR/dh.pem"
  "$KEY_DIR/ta.key"
  "$CONF_FILE"
)

echo "🔍 Checking required files..."

MISSING=0
for FILE in "${REQUIRED_FILES[@]}"; do
  if [ -f "$FILE" ]; then
    echo "✅ Found: $FILE"
  else
    echo "❌ Missing: $FILE"
    MISSING=1
  fi
done

# Generate keys if any are missing (excluding server.conf)
if [ "$MISSING" -eq 1 ]; then
  echo "⚠️ Some keys are missing — generating now..."
  /scripts/gen-keys.sh "$KEY_DIR"
else
  echo "✅ All required files are present. Starting OpenVPN server..."
fi

# Final check for server.conf before launching
if [ ! -f "$CONF_FILE" ]; then
  echo "❌ server.conf not found at $CONF_FILE — aborting."
  exit 1
fi

echo "🔧 Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "🌐 Setting up NAT (masquerading) for VPN traffic..."
EXT_IF=$(ip route | grep default | awk '{print $5}')
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$EXT_IF" -j MASQUERADE

echo "🚀 Launching OpenVPN..."
exec openvpn --config "$CONF_FILE"