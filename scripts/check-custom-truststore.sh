#!/usr/bin/env bash
set -euo pipefail
# Controlled demonstration: adding an incident intermediate as a custom trust anchor can
# defeat the patched runtime's default CA removal. Never use this truststore in production.
fixture="upstream-chains/chains/regular/dv-g3b-emudhra.we-have-a-problem.com.pem"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 - "$fixture" "$tmp/incident-anchor.pem" <<'PY'
import pathlib, re, sys
certs = re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', pathlib.Path(sys.argv[1]).read_text(), re.S)
assert len(certs) >= 3, "Expected a complete chain"
pathlib.Path(sys.argv[2]).write_text(certs[-1] + "\n")
PY
keytool -importcert -noprompt -trustcacerts -alias incident-intermediate -file "$tmp/incident-anchor.pem" -keystore "$tmp/unsafe.p12" -storetype PKCS12 -storepass changeit >/dev/null 2>&1
mkdir -p "$tmp/fixtures"
cp "$fixture" "$tmp/fixtures/chain.pem"
for image in \
  'bellsoft/liberica-openjdk-alpine:17.0.21@sha256:a16eb904aa472d560ff3fb6a77de0efc3482be938210d2caef0bd1f89c10d356' \
  'bellsoft/liberica-openjre-alpine:17.0.21@sha256:7b0cd77df19f413034a437f081ac4c3db892e6ce3d3cde56c76d5c51cf7b071a'; do
  echo "=== Patched runtime, default truststore: MUST reject ==="
  docker run --rm -v "$PWD/build:/probe:ro" -v "$tmp/fixtures:/fixtures:ro" --entrypoint java "$image" \
    -cp /probe OfflineChainProbe reject /fixtures/chain.pem
  echo "=== Patched runtime, deliberately unsafe truststore: demonstrate exposure ==="
  docker run --rm -v "$PWD/build:/probe:ro" -v "$tmp/fixtures:/fixtures:ro" -v "$tmp/unsafe.p12:/unsafe.p12:ro" \
    --entrypoint java "$image" -Djavax.net.ssl.trustStore=/unsafe.p12 \
    -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12 \
    -cp /probe OfflineChainProbe accept /fixtures/chain.pem
done
echo "PASS: patched runtimes reject by default; unsafe custom truststores can restore trust."
