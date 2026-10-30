#!/usr/bin/env bash
set -euo pipefail
OLD_JDK='bellsoft/liberica-openjdk-alpine:17.0.20@sha256:1aa69057bcd3eafa77738ec58ba8b969fd621212e3f280d3774e64409bf6333d'
NEW_JDK='bellsoft/liberica-openjdk-alpine:17.0.21@sha256:a16eb904aa472d560ff3fb6a77de0efc3482be938210d2caef0bd1f89c10d356'
OLD_JRE='bellsoft/liberica-openjre-alpine:17.0.20@sha256:b052d402e9146bca23524922cdbe9a11849cd2e6af0d2661eaa10400a124c19d'
NEW_JRE='bellsoft/liberica-openjre-alpine:17.0.21@sha256:7b0cd77df19f413034a437f081ac4c3db892e6ce3d3cde56c76d5c51cf7b071a'
test -d upstream-chains/chains/regular
mapfile -t fixtures < <(find upstream-chains/chains/regular upstream-chains/chains/rollover -name '*.pem' | sort)
test "${#fixtures[@]}" -eq 16 || { echo "Expected 16 upstream fixtures; found ${#fixtures[@]}"; exit 2; }
for family in JDK JRE; do
  old_var="OLD_${family}"; new_var="NEW_${family}"
  old="${!old_var}"; new="${!new_var}"
  docker pull "$old"; docker pull "$new"
  for file in "${fixtures[@]}"; do
    echo "=== ${family} ${file} ==="
    # Baseline is diagnostic: a previous runtime may reject some fixtures for unrelated reasons.
    docker run --rm -v "$PWD/build:/probe:ro" -v "$PWD/upstream-chains:/fixtures:ro" \
      --entrypoint java "$old" -cp /probe OfflineChainProbe accept "/fixtures/${file#upstream-chains/}" || \
      echo "WARN: baseline did not accept $file"
    docker run --rm -v "$PWD/build:/probe:ro" -v "$PWD/upstream-chains:/fixtures:ro" \
      --entrypoint java "$new" -cp /probe OfflineChainProbe reject "/fixtures/${file#upstream-chains/}"
  done
done
echo "PASS: patched JDK and JRE rejected all ${#fixtures[@]} offline certificate chains"
