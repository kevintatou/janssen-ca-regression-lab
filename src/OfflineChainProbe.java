import javax.net.ssl.*;
import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.*;
import java.util.*;

/** Offline PKIX path building with the JVM's default trust anchors, no network. */
public final class OfflineChainProbe {
  public static void main(String[] args) throws Exception {
    if (args.length != 2) { System.err.println("Usage: OfflineChainProbe accept|reject chain.pem"); System.exit(2); }
    String expected = args[0];
    if (!expected.equals("accept") && !expected.equals("reject")) System.exit(2);
    Collection<? extends java.security.cert.Certificate> loaded;
    try (InputStream in = Files.newInputStream(Path.of(args[1]))) {
      loaded = CertificateFactory.getInstance("X.509").generateCertificates(in);
    }
    List<X509Certificate> certs = new ArrayList<>();
    for (java.security.cert.Certificate c : loaded) certs.add((X509Certificate)c);
    if (certs.size() < 2) throw new IllegalStateException("Fixture missing intermediate: " + args[1]);
    TrustManagerFactory factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
    factory.init((KeyStore)null);
    Set<TrustAnchor> anchors = new HashSet<>();
    for (TrustManager tm : factory.getTrustManagers()) {
      if (tm instanceof X509TrustManager) for (X509Certificate ca : ((X509TrustManager)tm).getAcceptedIssuers())
        anchors.add(new TrustAnchor(ca, null));
    }
    X509CertSelector target = new X509CertSelector();
    target.setCertificate(certs.get(0));
    PKIXBuilderParameters params = new PKIXBuilderParameters(anchors, target);
    params.setRevocationEnabled(false); // deterministic trust-path check, not CRL/OCSP coverage
    params.addCertStore(CertStore.getInstance("Collection", new CollectionCertStoreParameters(certs)));
    boolean accepted;
    try {
      CertPathBuilder.getInstance("PKIX").build(params);
      accepted = true;
    } catch (CertPathBuilderException e) {
      accepted = false;
    }
    System.out.println((accepted ? "ACCEPTED " : "REJECTED ") + args[1]);
    if (accepted != expected.equals("accept")) System.exit(1);
  }
}
