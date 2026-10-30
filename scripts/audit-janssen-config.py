#!/usr/bin/env python3
"""Conservative static audit of a local Janssen configuration export or source tree.

Does not make network requests, modify files, or print configuration secrets.
Use with a sanitized nonproduction export only.
"""
import pathlib, re, sys
if len(sys.argv) != 2:
    sys.exit("Usage: python3 scripts/audit-janssen-config.py PATH_TO_SANITIZED_CONFIG")
root = pathlib.Path(sys.argv[1]).resolve()
if not root.exists(): sys.exit("Path does not exist")
patterns = {
    "Trust-all certificate manager": re.compile(r"TrustAll|InsecureTrustManager|NoopTrustManager|checkServerTrusted\s*\([^)]*\)\s*\{\s*\}", re.I),
    "Disabled hostname verification": re.compile(r"NoopHostnameVerifier|ALLOW_ALL_HOSTNAME_VERIFIER|setHostnameVerifier\s*\([^\n]*true|hostnameVerification\s*[:=]\s*false", re.I),
    "Custom JVM truststore (requires manual certificate audit)": re.compile(r"javax\.net\.ssl\.trustStore|trustStorePath|trust-store-file", re.I),
    "TLS verification disabled": re.compile(r"(verifySsl|verifyTls|sslVerification|tlsVerification|insecureSkipVerify)\s*[:=]\s*(false|true)", re.I),
}
allowed = {".java",".kt",".xml",".yaml",".yml",".properties",".json",".conf",".env",".sh",".txt"}
count=0
for p in ([root] if root.is_file() else root.rglob("*")):
    if not p.is_file() or p.suffix.lower() not in allowed or p.stat().st_size > 2_000_000: continue
    try: content = p.read_text(encoding="utf-8")
    except (OSError, UnicodeError): continue
    for label, pattern in patterns.items():
        for match in pattern.finditer(content):
            line=content.count("\n",0,match.start())+1
            print(f"{p.relative_to(root.parent if root.is_file() else root)}:{line}: REVIEW {label}")
            count+=1
print(f"Potential TLS configuration findings: {count}; inspect all findings manually.")
sys.exit(1 if count else 0)
