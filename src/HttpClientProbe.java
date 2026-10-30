import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import javax.net.ssl.SSLException;

/** Exercise JDK HttpClient outbound TLS (not a Janssen application integration). */
public final class HttpClientProbe {
  public static void main(String[] args) throws Exception {
    if (args.length != 2) System.exit(2);
    boolean reject = args[0].equals("reject");
    try {
      HttpClient client = HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NEVER).build();
      client.send(HttpRequest.newBuilder(URI.create(args[1])).GET().build(),
        HttpResponse.BodyHandlers.discarding());
      System.out.println("HTTP_CLIENT_TLS_ACCEPTED " + args[1]);
      if (reject) System.exit(1);
    } catch (SSLException e) {
      boolean certificateFailure = false;
      for (Throwable t=e; t!=null; t=t.getCause())
        if (t instanceof java.security.cert.CertificateException ||
            t instanceof java.security.cert.CertPathBuilderException ||
            t instanceof java.security.cert.CertPathValidatorException) certificateFailure = true;
      if (!certificateFailure) { e.printStackTrace(); System.exit(2); }
      System.out.println("HTTP_CLIENT_TLS_REJECTED " + args[1]);
      if (!reject) System.exit(1);
    } catch (java.io.IOException e) {
      e.printStackTrace();
      System.exit(2);
    }
  }
}
