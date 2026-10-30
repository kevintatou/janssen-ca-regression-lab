#!/usr/bin/env bash
set -uo pipefail

# Exact image references from JanssenProject/jans PR #15521 (as reviewed 2026-10-30).
OLD='bellsoft/liberica-openjdk-alpine:17.0.20@sha256:1aa69057bcd3eafa77738ec58ba8b969fd621212e3f280d3774e64409bf6333d'
NEW='bellsoft/liberica-openjdk-alpine:17.0.21@sha256:a16eb904aa472d560ff3fb6a77de0efc3482be938210d2caef0bd1f89c10d356'
BAD_URL='https://dv-g3b-emudhra.we-have-a-problem.com/'
GOOD_URL='https://example.com/'

test_image() {
  local image="$1" expected="$2"
  docker run --rm --network bridge --entrypoint java \
    -v "$PWD/build:/probe:ro" "$image" -cp /probe TlsProbe "$expected" "$BAD_URL"
}

echo '=== Old image (observation only; acceptance indicates exposure) ==='
docker pull "$OLD"
if test_image "$OLD" reject; then
  echo 'Baseline unexpectedly rejects compromised chain.'
else
  echo 'Baseline did not pass; inspect whether it accepted the chain or was inconclusive.'
fi

echo '=== Patched image (required certificate rejection) ==='
docker pull "$NEW"
test_image "$NEW" reject || exit $?

echo '=== Patched image (legitimate HTTPS positive control) ==='
docker run --rm --network bridge --entrypoint java \
  -v "$PWD/build:/probe:ro" "$NEW" -cp /probe TlsProbe accept "$GOOD_URL" || exit $?

echo 'PASS: patched image rejects incident chain and accepts legitimate TLS.'
