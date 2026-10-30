#!/usr/bin/env bash
# Reproduce and verify the Janssen CIBA HTTP client bugs against the REAL upstream
# ClientUtil.createHttpClient, using loopback HTTPS servers and synthetic certs only.
#
#   - Pinned (buggy) upstream source  -> expect "Connection pool shut down"
#   - Patched source (this repo)      -> expect success, hostname mismatch rejected,
#                                        untrusted cert rejected
#
# Requires: JDK 17 (javac, keytool), openssl, Maven (for dependency resolution).
# No external or production systems are contacted.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
UPSTREAM_UTIL="${1:-$ROOT/upstream-jans/jans-auth-server/client/src/main/java/io/jans/as/client/util/ClientUtil.java}"
WORK="$ROOT/build/ciba-repro"
M2_REPO="${M2_REPO:-$HOME/.m2/repository}"

echo "== CIBA HTTP client reproduction =="
echo "Upstream ClientUtil: $UPSTREAM_UTIL"
test -f "$UPSTREAM_UTIL" || { echo "MISSING upstream ClientUtil.java at $UPSTREAM_UTIL"; exit 2; }

rm -rf "$WORK"
mkdir -p "$WORK/certs" "$WORK/classes-buggy" "$WORK/classes-patched" "$WORK/src-buggy/io/jans/as/client/util"

# 1. Resolve Apache HttpClient + deps via the existing repro module's pom.
echo "-- resolving dependencies"
mvn -q -f "$HERE/pom.xml" -DincludeScope=runtime -Dmdep.outputFile="$WORK/cp.txt" \
    dependency:build-classpath >/dev/null
CP="$(cat "$WORK/cp.txt")"
test -n "$CP" || { echo "Failed to resolve dependency classpath"; exit 2; }

# 2. Generate synthetic certificates and a CA-only truststore.
echo "-- generating certificates"
bash "$HERE/gen-certs.sh" >/dev/null
cp -r "$HERE/certs/." "$WORK/certs/"
keytool -importcert -noprompt -alias janstestca -file "$WORK/certs/ca.crt" \
    -keystore "$WORK/certs/ca-truststore.p12" -storetype PKCS12 -storepass changeit >/dev/null 2>&1

# 3. Stage the pinned (buggy) upstream source and the patched source.
cp "$UPSTREAM_UTIL" "$WORK/src-buggy/io/jans/as/client/util/ClientUtil.java"

# 4. Compile both variants against the real repro harness.
echo "-- compiling buggy (pinned) and patched variants"
javac --release 17 -cp "$CP" -d "$WORK/classes-buggy" \
    "$WORK/src-buggy/io/jans/as/client/util/ClientUtil.java" "$HERE/CibaHttpClientRepro.java"
javac --release 17 -cp "$CP" -d "$WORK/classes-patched" \
    "$HERE/patched/io/jans/as/client/util/ClientUtil.java" "$HERE/CibaHttpClientRepro.java"

TS_PROPS=(-Djavax.net.ssl.trustStore="$WORK/certs/ca-truststore.p12"
          -Djavax.net.ssl.trustStorePassword=changeit
          -Djavax.net.ssl.trustStoreType=PKCS12)

run_variant() {
  local classes="$1"
  java "${TS_PROPS[@]}" -cp "$classes:$CP" CibaHttpClientRepro "$WORK/certs"
}

# 5. Run the buggy pinned source: lifecycle must fail with pool shutdown.
echo "-- running PINNED (buggy) upstream source"
BUGGY_OUT="$(run_variant "$WORK/classes-buggy")"
echo "$BUGGY_OUT" | sed 's/^/    /'
if echo "$BUGGY_OUT" | grep -q "LIFECYCLE request_failed IllegalStateException POOL_SHUT_DOWN"; then
  echo "OK: pinned source reproduced premature connection-manager close (pool shut down)"
else
  echo "FAIL: pinned source did NOT reproduce the connection-manager lifecycle bug"
  exit 1
fi

# 6. Run the patched source: lifecycle succeeds, hostname mismatch + untrusted rejected.
echo "-- running PATCHED source"
PATCHED_OUT="$(run_variant "$WORK/classes-patched")"
echo "$PATCHED_OUT" | sed 's/^/    /'
ok=1
echo "$PATCHED_OUT" | grep -q "LIFECYCLE request_ok status=200"            || { echo "FAIL: patched lifecycle did not succeed"; ok=0; }
echo "$PATCHED_OUT" | grep -q "HOSTNAME mismatch_rejected"                 || { echo "FAIL: patched hostname mismatch not rejected"; ok=0; }
echo "$PATCHED_OUT" | grep -q "UNTRUSTED rejected"                         || { echo "FAIL: patched untrusted cert not rejected"; ok=0; }
if [ "$ok" -ne 1 ]; then
  exit 1
fi

echo "PASS: pinned buggy source reproduces the lifecycle bug; patched source executes requests, rejects hostname mismatches and untrusted certificates."
