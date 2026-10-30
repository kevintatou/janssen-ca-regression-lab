/*
 * This software is available under the Apache-2.0 license.
 * See https://www.apache.org/licenses/LICENSE-2.0.txt for full text.
 *
 * Copyright (c) 2026, Contributors to janssen-ca-regression-lab.
 */

import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.net.URL;
import java.security.cert.CertPathValidatorException;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLException;

/** Verify TLS trust decisions using the JVM's default trust configuration. */
public final class TlsProbe {
    private TlsProbe() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 2 || !(args[0].equals("reject") || args[0].equals("accept"))) {
            System.err.println("Usage: TlsProbe <reject|accept> <https-url>");
            System.exit(2);
        }
        boolean expectReject = args[0].equals("reject");
        try {
            HttpsURLConnection connection = (HttpsURLConnection) new URL(args[1]).openConnection();
            connection.setConnectTimeout(12000);
            connection.setReadTimeout(12000);
            try {
                connection.connect();
                System.out.println("TLS_ACCEPTED: " + args[1]);
                if (expectReject) {
                    System.err.println("FAIL: vulnerable certificate chain was accepted");
                    System.exit(1);
                }
                System.out.println("PASS: legitimate certificate chain accepted");
            } finally {
                connection.disconnect();
            }
        } catch (SSLException e) {
            boolean certFailure = false;
            for (Throwable cause = e; cause != null; cause = cause.getCause()) {
                if (cause instanceof CertPathValidatorException ||
                    cause instanceof java.security.cert.CertificateException ||
                    cause instanceof java.security.cert.CertPathBuilderException) {
                    certFailure = true;
                }
            }
            if (!certFailure) {
                System.err.println("INCONCLUSIVE: TLS failure not proven to be certificate validation: " + e);
                System.exit(2);
            }
            System.out.println("TLS_REJECTED: " + e.getClass().getSimpleName());
            if (!expectReject) {
                System.err.println("FAIL: legitimate certificate chain rejected");
                System.exit(1);
            }
            System.out.println("PASS: compromised certificate chain rejected");
        } catch (UnknownHostException | ConnectException | SocketTimeoutException e) {
            System.err.println("INCONCLUSIVE: endpoint unavailable: " + e);
            System.exit(2);
        } catch (java.io.IOException e) {
            System.err.println("INCONCLUSIVE: I/O failure: " + e);
            System.exit(2);
        }
    }
}
