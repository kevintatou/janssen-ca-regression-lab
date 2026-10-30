import com.sun.net.httpserver.HttpsConfigurator;
import com.sun.net.httpserver.HttpsServer;
import io.jans.as.client.util.ClientUtil;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLPeerUnverifiedException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.KeyStore;

/**
 * Drives the REAL Janssen ClientUtil.createHttpClient (compiled from the pinned or
 * patched upstream source) against loopback HTTPS servers with controlled certs.
 *
 * Expects -Djavax.net.ssl.trustStore=<ca.p12> trusting only the local test CA.
 * Args: <certsDir>
 * Exit 0 always; prints OBSERVED lines for CI assertion by the workflow.
 */
public class CibaHttpClientRepro {
    public static void main(String[] args) throws Exception {
        Path certs = Paths.get(args[0]);
        String[] ciphers = {"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"};

        HttpsServer good = start(certs.resolve("server-good.p12"));
        String goodUrl = "https://localhost:" + good.getAddress().getPort() + "/";
        try {
            lifecycle(goodUrl, ciphers);
            hostnameMismatch(certs, ciphers);
            untrusted(certs, ciphers);
        } finally {
            good.stop(0);
        }
        System.out.println("REPRO_DONE");
    }

    static void lifecycle(String url, String[] ciphers) {
        CloseableHttpClient client = ClientUtil.createHttpClient("TLSv1.2", ciphers);
        if (client == null) { System.out.println("LIFECYCLE factory_null"); return; }
        try {
            HttpResponse r = client.execute(new HttpGet(url));
            System.out.println("LIFECYCLE request_ok status=" + r.getStatusLine().getStatusCode());
        } catch (Exception e) {
            boolean pool = String.valueOf(e.getMessage()).toLowerCase().contains("connection pool shut down");
            System.out.println("LIFECYCLE request_failed " + e.getClass().getSimpleName() + (pool ? " POOL_SHUT_DOWN" : ""));
        } finally {
            try { client.close(); } catch (Exception ignored) {}
        }
    }

    static void hostnameMismatch(Path certs, String[] ciphers) throws Exception {
        HttpsServer bad = start(certs.resolve("server-bad.p12"));
        String url = "https://localhost:" + bad.getAddress().getPort() + "/";
        try {
            CloseableHttpClient client = ClientUtil.createHttpClient("TLSv1.2", ciphers);
            if (client == null) { System.out.println("HOSTNAME factory_null"); return; }
            try {
                HttpResponse r = client.execute(new HttpGet(url));
                System.out.println("HOSTNAME mismatch_accepted status=" + r.getStatusLine().getStatusCode());
            } catch (SSLPeerUnverifiedException e) {
                System.out.println("HOSTNAME mismatch_rejected");
            } catch (Exception e) {
                System.out.println("HOSTNAME error " + e.getClass().getSimpleName());
            } finally {
                try { client.close(); } catch (Exception ignored) {}
            }
        } finally {
            bad.stop(0);
        }
    }

    static void untrusted(Path certs, String[] ciphers) throws Exception {
        HttpsServer un = start(certs.resolve("server-untrusted.p12"));
        String url = "https://localhost:" + un.getAddress().getPort() + "/";
        try {
            CloseableHttpClient client = ClientUtil.createHttpClient("TLSv1.2", ciphers);
            if (client == null) { System.out.println("UNTRUSTED factory_null"); return; }
            try {
                HttpResponse r = client.execute(new HttpGet(url));
                System.out.println("UNTRUSTED accepted status=" + r.getStatusLine().getStatusCode());
            } catch (SSLHandshakeException e) {
                System.out.println("UNTRUSTED rejected");
            } catch (Exception e) {
                System.out.println("UNTRUSTED error " + e.getClass().getSimpleName());
            } finally {
                try { client.close(); } catch (Exception ignored) {}
            }
        } finally {
            un.stop(0);
        }
    }

    static HttpsServer start(Path p12) throws Exception {
        HttpsServer server = HttpsServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (InputStream in = Files.newInputStream(p12)) { ks.load(in, "changeit".toCharArray()); }
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(ks, "changeit".toCharArray());
        SSLContext ssl = SSLContext.getInstance("TLS");
        ssl.init(kmf.getKeyManagers(), null, null);
        server.setHttpsConfigurator(new HttpsConfigurator(ssl));
        server.createContext("/", ex -> {
            byte[] body = "ok".getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(200, body.length);
            try (OutputStream o = ex.getResponseBody()) { o.write(body); }
        });
        server.start();
        return server;
    }
}
