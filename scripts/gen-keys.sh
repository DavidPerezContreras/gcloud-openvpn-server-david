#!/bin/bash
set -e

# Always resolve KEYS_DIR relative to current working directory
KEYS_DIR="$(pwd)/volume"
PKI_DIR="$KEYS_DIR/pki"
EASYRSA_BIN="/usr/share/easy-rsa/easyrsa"
TA_KEY_PATH="$KEYS_DIR/ta.key"

echo "🔧 Generating keys in: $KEYS_DIR"

# Ensure volume directory exists
mkdir -p "$KEYS_DIR"

# Ensure output directories exist
mkdir -p "$PKI_DIR"
mkdir -p "$(dirname "$TA_KEY_PATH")"

cd "$KEYS_DIR"

# Generate TLS auth key in volume root first using OpenVPN's built-in method
if [ ! -f "$TA_KEY_PATH" ]; then
  echo "🔑 Generating ta.key in: $TA_KEY_PATH"
  sudo openvpn --genkey --secret "$TA_KEY_PATH"
fi

export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="OpenVPN-Server"

# Initialize PKI if needed
if [ ! -d "$PKI_DIR/private" ]; then
  "$EASYRSA_BIN" init-pki
fi

# Build CA if not already present
if [ ! -f "$PKI_DIR/ca.crt" ]; then
  "$EASYRSA_BIN" build-ca nopass
fi

# Generate server cert and key if not already present
if [ ! -f "$PKI_DIR/issued/server.crt" ] || [ ! -f "$PKI_DIR/private/server.key" ]; then
  "$EASYRSA_BIN" build-server-full server nopass
fi

# Generate DH params if not already present
if [ ! -f "$PKI_DIR/dh.pem" ]; then
  "$EASYRSA_BIN" gen-dh
fi

# Fix ownership of all generated files
echo "🔧 Setting ownership to ciber:ciber in $KEYS_DIR"
sudo chown ciber:ciber -R "$KEYS_DIR"

echo "✅ Server keys generated in $KEYS_DIR"
