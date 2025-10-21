FROM debian:bullseye

# Install OpenVPN and dependencies, including libmnl0 to fix iproute2 errors
RUN apt-get update && \
    apt-get install -y openvpn easy-rsa iproute2 iptables libmnl0 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /etc/openvpn

# Copy configuration and scripts
COPY server.conf /etc/openvpn/
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/gen-keys.sh /scripts/gen-keys.sh
COPY clients/create-client.sh /clients/create-client.sh

# Copy pre-generated keys from repo
COPY volume/ /etc/openvpn/keys/

# Ensure scripts are executable
RUN chmod +x /entrypoint.sh /scripts/*.sh /clients/*.sh

EXPOSE 1194/udp

ENTRYPOINT ["/entrypoint.sh"]
