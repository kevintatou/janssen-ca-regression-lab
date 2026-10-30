# Janssen upstream PR: CIBA ping HTTP client lifecycle and hostname verification

Source revision investigated: 95f2eebb4bf725eae9415c5a8c69815dd92d4c80.

**Status: confirmed, fixed, and submitted upstream.**
- jans-auth-server PR: https://github.com/JanssenProject/jans/pull/15552
- jans-lock (identical copy) PR: https://github.com/JanssenProject/jans/pull/15553
- Reproduction CI (this lab): https://github.com/kevintatou/janssen-ca-regression-lab/pull/1

## Confirmed code path

- `PingCallbackClient.getApacheHttpClient4ExecutorForMTLS()` calls `ClientUtil.createHttpClient("TLSv1.2", ciphers)` when `fapiCompatibility` (FAPI CIBA) is enabled.
- `ClientUtil.createHttpClient()` built `SSLConnectionSocketFactory` with `NoopHostnameVerifier.INSTANCE`.
- It created `PoolingHttpClientConnectionManager` in a try-with-resources block and returned an HTTP client backed by that (now closed) manager.

## Confirmed behavior (loopback only, synthetic certs)

Drove the real upstream method against loopback HTTPS servers. No production systems contacted.

| Scenario | Before fix | After fix |
|---|---|---|
| Client executes a request after factory returns | `IllegalStateException: Connection pool shut down` | HTTP 200 |
| Server cert for a different host (`wronghost.example`) | Accepted (HTTP 200) via `NoopHostnameVerifier` | Rejected (`SSLPeerUnverifiedException`) |
| Untrusted self-signed cert | (masked by lifecycle defect) | Rejected (`SSLHandshakeException`) |

Origin of the lifecycle defect: a static-analysis (Sonar) auto-fix (`df29842513`) wrapped the
previously correct manager in try-with-resources. The hostname defect is original to the method.

## Fix applied

1. Use `DefaultHostnameVerifier` in the custom TLS socket factory (hostname verification enforced).
2. Keep the connection manager alive; its lifecycle is owned by the returned `CloseableHttpClient`.
3. Add `ClientUtilHttpClientTlsTest` (TestNG) covering valid cert, hostname mismatch, untrusted
   cert, and returned-client usability. The same tests fail against the unfixed code with
   `Connection pool shut down`.
4. TLS version and cipher restrictions (FAPI-CIBA) preserved unchanged.

## Test results

- Maven Surefire (`jans-auth-client`): new tests `Tests run: 3, Failures: 0, Errors: 0`; existing
  `io.jans.as.client.util.*Test` suites pass (8 tests). Full `test-compile` clean.
- Upstream CI on the PR is in `action_required` state (first-time-contributor approval needed);
  DCO and Snyk checks pass.

## Security characterization

The hostname-verification defect is a hardening gap reachable only via the FAPI-CIBA
ping-callback path, and is currently masked by the lifecycle defect (the client fails before any
TLS handshake). This is reported as a correctness fix plus TLS hardening, not as a demonstrated
in-the-wild exploit. Coordinate any stronger security claim through security@jans.io.

## Separate investigation

`BaseHttpService.getHttpsClientTrustAll()` explicitly disables certificate and hostname validation.
Treat as a separate API hardening discussion, not an established production vulnerability.
