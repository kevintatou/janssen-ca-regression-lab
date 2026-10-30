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

## Threat model and limits

An attacker who controls a compromised intermediate signing key could issue fraudulent TLS server certificates. If a Janssen Java component accepts that chain on an outbound HTTPS call (for example to Microsoft Entra), the attacker may impersonate the destination **only if they can also intercept or redirect the connection** (such as through DNS, routing, proxy, or network control). Compromise of a CA alone does not give remote access to Janssen.

This lab now checks six public chain fixtures (DV G3B, OV G3C, EV G3B, plus their AAA cross-signed variants) against **both** JDK and JRE image digests used by Janssen PR #15521. It is not proof of coverage for all eight compromised intermediates or all possible alternate encodings. Do not label the whole system safe based solely on this workflow.

### Before using in production

- Ensure deployed Janssen images actually contain the patched runtime; check image digest and rollout, not just Helm chart version.
- Inspect JVM `javax.net.ssl.trustStore`, mounted `cacerts`, `JAVA_TOOL_OPTIONS`, application-specific HTTP clients, proxy settings, and custom TrustManagers. A mounted old truststore can undo the base-image mitigation.
- Check non-Java components, OS trust bundles, ingress/egress proxies and sidecars separately.
- Require TLS hostname verification and certificate validation; never disable them as a workaround.
- Control outbound DNS, proxy and egress destinations; protect OAuth client secrets and tokens, and review relevant logs if exposure is suspected.
- Test actual Janssen-to-Entra flows in a **nonproduction** environment using authorized accounts and endpoints.

The lab performs no intrusive testing against Entra or production Janssen installations.
