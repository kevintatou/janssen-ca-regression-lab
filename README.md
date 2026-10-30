# Janssen CA regression lab

Independent public experiment for the October 2026 eMudhra Java certificate-trust incident. Not affiliated with the Janssen Project; no employer data.

## Run

Requires Docker and JDK 17.

```bash
mkdir -p build
javac --release 17 -d build src/TlsProbe.java
bash scripts/check-images.sh
```

GitHub Actions runs the same test on pushes, PRs and manual dispatch.

The script compares the **exact image digests** in [Janssen PR #15521](https://github.com/JanssenProject/jans/pull/15521). The old image is an observation-only baseline. The patched image must reject the incident test certificate chain and accept a legitimate HTTPS chain.

A timeout, DNS failure, or other network error is **inconclusive**, not a security pass. The test depends on a public incident test host and is not a complete audit of all affected intermediates, cross-signatures, alternate encodings, or custom truststores.

## Existing work

- [BellSoft's incident analysis and fixed runtime versions](https://bell-sw.com/blog/distrusting-compromised-emudhra-intermediates-in-java/)
- [DC2-DanielKrueger/EmudhraTrustRemoval](https://github.com/DC2-DanielKrueger/EmudhraTrustRemoval) — Java trust checking and mitigation
- [endorlabs/eMudhra_mitigation](https://github.com/endorlabs/eMudhra_mitigation) — container image trust-store auditing and remediation

## Upstream contribution

Follow [Janssen's CONTRIBUTING guide](https://github.com/JanssenProject/jans/blob/main/docs/CONTRIBUTING.md): Conventional Commits, GPG signing, DCO sign-off, component-prefixed branches, tests and docs, Apache-2.0 license headers, and applicable CLA requirements.

License: Apache-2.0.
