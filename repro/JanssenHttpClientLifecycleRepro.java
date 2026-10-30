import java.net.InetSocketAddress;
import java.io.IOException;
import com.sun.net.httpserver.HttpServer;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;

/** Minimal isolated reproduction of the connection-manager lifecycle pattern in Janssen ClientUtil. */
public class JanssenHttpClientLifecycleRepro {
  static CloseableHttpClient brokenFactory() {
    try (PoolingHttpClientConnectionManager cm = new PoolingHttpClientConnectionManager()) {
      return HttpClients.custom().setConnectionManager(cm).build();
    }
  }
  static CloseableHttpClient fixedFactory() {
    PoolingHttpClientConnectionManager cm = new PoolingHttpClientConnectionManager();
    return HttpClients.custom().setConnectionManager(cm).build();
  }
  public static void main(String[] args) throws Exception {
    HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext("/", exchange -> {
      byte[] body = "ok".getBytes(java.nio.charset.StandardCharsets.UTF_8);
      exchange.sendResponseHeaders(200, body.length);
      try (var out = exchange.getResponseBody()) { out.write(body); }
    });
    server.start();
    String url = "http://127.0.0.1:" + server.getAddress().getPort() + "/";
    try {
      try (CloseableHttpClient broken = brokenFactory()) {
        try {
          broken.execute(new HttpGet(url), response -> {
            throw new AssertionError("Unexpected request success with closed connection manager");
          });
          throw new AssertionError("Broken factory unexpectedly worked");
        } catch (IOException expected) {
          System.out.println("EXPECTED_FAILURE: closed manager: " + expected.getClass().getSimpleName());
        }
      }
      try (CloseableHttpClient fixed = fixedFactory()) {
        int status = fixed.execute(new HttpGet(url), response -> response.getStatusLine().getStatusCode());
        if (status != 200) throw new AssertionError("Fixed factory status " + status);
        System.out.println("PASS: manager owned by returned client: HTTP " + status);
      }
    } finally { server.stop(0); }
  }
}
