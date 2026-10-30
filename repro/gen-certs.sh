#!/usr/bin/env bash
# Generate a local CA and two server certs: one with CN=localhost (good), one with CN=wronghost (mismatch).
# All self-contained, loopback only. No production systems.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)/certs"
mkdir -p "$D"
cd "$D"

# 1. Local CA
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=JansTestCA/O=JansRegressionLab" \
  -keyout ca.key -out ca.crt 2>/dev/null

# 2. Good server cert: CN + SAN = localhost
openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=localhost/O=JansRegressionLab" \
  -keyout server-good.key -out server-good.csr 2>/dev/null
cat > server-good.ext <<'EOF'
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF
openssl x509 -req -in server-good.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 3650 -extfile server-good.ext -out server-good.crt 2>/dev/null

# 3. Hostname-mismatch server cert: CN + SAN = wronghost.example
openssl req -newkey rsa:2048 -nodes \
  -subj "/CN=wronghost.example/O=JansRegressionLab" \
  -keyout server-bad.key -out server-bad.csr 2>/dev/null
cat > server-bad.ext <<'EOF'
subjectAltName=DNS:wronghost.example
EOF
openssl x509 -req -in server-bad.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 3650 -extfile server-bad.ext -out server-bad.crt 2>/dev/null

# 4. Untrusted (self-signed, different CA) server cert: CN=localhost but NOT signed by our CA
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=localhost/O=Untrusted" \
  -keyout server-untrusted.key -out server-untrusted.crt 2>/dev/null

# 5. Combine cert+key into PEM for the Java HttpsServer (uses keystore; we'll build PKCS12)
openssl pkcs12 -export -out server-good.p12 -inkey server-good.key -in server-good.crt \
  -certfile ca.crt -passout pass:changeit 2>/dev/null
openssl pkcs12 -export -out server-bad.p12 -inkey server-bad.key -in server-bad.crt \
  -certfile ca.crt -passout pass:changeit 2>/dev/null
openssl pkcs12 -export -out server-untrusted.p12 -inkey server-untrusted.key -in server-untrusted.crt \
  -passout pass:changeit 2>/dev/null

# 6. Truststore containing ONLY our CA (so 'good' and 'bad' chain-trust, 'untrusted' does not)
#    We pass the CA cert PEM to the test which builds an in-memory truststore.
echo "Generated certs in $D:"
ls -1 "$D"
