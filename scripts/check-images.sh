#!/usr/bin/env bash
set -uo pipefail

# Exact pinned image digests in Janssen PR #15521, reviewed 2026-10-30.
JDK_OLD='bellsoft/liberica-openjdk-alpine:17.0.20@sha256:1aa69057bcd3eafa77738ec58ba8b969fd621212e3f280d3774e64409bf6333d'
JDK_NEW='bellsoft/liberica-openjdk-alpine:17.0.21@sha256:a16eb904aa472d560ff3fb6a77de0efc3482be938210d2caef0bd1f89c10d356'
JRE_OLD='bellsoft/liberica-openjre-alpine:17.0.20@sha256:b052d402e9146bca23524922cdbe9a11849cd2e6af0d2661eaa10400a124c19d'
JRE_NEW='bellsoft/liberica-openjre-alpine:17.0.21@sha256:7b0cd77df19f413034a437f081ac4c3db892e6ce3d3cde56c76d5c51cf7b071a'

# Researcher-operated endpoints, sourced from endorlabs/eMudhra_mitigation/scripts/probe.sh.
# Six public examples, NOT an exhaustive test of all eight compromised intermediates.
HOSTS=(dv-g3b ov-g3c ev-g3b dv-g3b-aaa ov-g3c-aaa ev-g3b-aaa)
GOOD_URL='https://example.com/'
failed=0
inconclusive=0
baseline_accepted=0

probe() {
  local image="$1" expected="$2" url="$3"
  docker run --rm --network bridge --entrypoint java \
    -v "$PWD/build:/probe:ro" "$image" -cp /probe TlsProbe "$expected" "$url"
}

for kind in JDK JRE; do
  old_var="${kind}_OLD"
  new_var="${kind}_NEW"
  old_image="${!old_var}"
  new_image="${!new_var}"
  echo "=== ${kind}: pulling pinned images ==="
  docker pull "$old_image" || exit 2
  docker pull "$new_image" || exit 2

  echo "=== ${kind}: legitimate HTTPS control ==="
  if probe "$new_image" accept "$GOOD_URL"; then :; else
    echo "FAIL: positive control failed for $kind"
    exit 2
  fi

  for host in "${HOSTS[@]}"; do
    url="https://${host}-emudhra.we-have-a-problem.com/"
    echo "=== ${kind} ${host}: old baseline (expected to accept) ==="
    if probe "$old_image" accept "$url"; then
      baseline_accepted=$((baseline_accepted + 1))
    else
      echo "WARN: baseline did not accept $url; inspect for endpoint drift or partial mitigation"
      inconclusive=$((inconclusive + 1))
    fi

    echo "=== ${kind} ${host}: patched image (must reject) ==="
    if probe "$new_image" reject "$url"; then :; else
      echo "FAIL: patched image did not prove certificate rejection for $url"
      failed=$((failed + 1))
    fi
  done
done

echo "SUMMARY: patched failures=$failed, baseline acceptances=$baseline_accepted, baseline anomalies=$inconclusive"
if (( failed > 0 )); then exit 1; fi
if (( baseline_accepted == 0 || inconclusive > 0 )); then
  echo 'INCONCLUSIVE: old baseline behavior did not match expected exposure on every public fixture.'
  exit 2
fi
echo 'PASS: both patched Janssen base-image families reject six affected certificate-chain fixtures.'
