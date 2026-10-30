# Janssen upstream PR candidate: CIBA ping HTTP client lifecycle and hostname verification

Source revision: 95f2eebb4bf725eae9415c5a8c69815dd92d4c80.

## Reproducible code path

- `PingCallbackClient.getApacheHttpClient4ExecutorForMTLS()` calls `ClientUtil.createHttpClient("TLSv1.2", ciphers)`.
- `ClientUtil.createHttpClient()` constructs `SSLConnectionSocketFactory` with `NoopHostnameVerifier.INSTANCE`.
- It also creates `PoolingHttpClientConnectionManager` in a try-with-resources block and returns an HTTP client backed by that manager. The manager is closed when the method returns.

## Proposed narrowly scoped upstream change

1. Use `DefaultHostnameVerifier` (or the library default) in the custom TLS socket factory.
2. Keep the connection manager alive until the returned HTTP client is closed; do not close it in the factory method.
3. Add a regression test for a valid local TLS certificate, a hostname mismatch, and an untrusted certificate. Verify the client can make a request after factory return.
4. Confirm the CIBA ping callback and FAPI mTLS behavior with maintainers before changing production semantics.

## Separate investigation

`BaseHttpService.getHttpsClientTrustAll()` explicitly disables certificate and hostname validation. GitHub code search found no production call site outside its declaration and a config-api test utility at the time of inspection. Treat as a separate API hardening discussion, not an established production vulnerability.

## Scope and safety

Do not use production hosts or private company configurations. This is a review proposal, not a tested upstream patch. Avoid reporting exploitability until reachability and integration tests are demonstrated.
