#!/usr/bin/env python3
"""Audit pinned public Janssen sources for outbound TLS bypass patterns.

Read-only, no secrets, no production endpoints. Findings are review signals,
not proof that an unsafe code path is reachable in a deployment.
"""
import pathlib, re, sys
root=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path("upstream-jans")
paths=[
 "jans-core/service/src/main/java/io/jans/service/net/BaseHttpService.java",
 "jans-auth-server/client/src/main/java/io/jans/as/client/util/ClientUtil.java",
 "jans-fido2/server/src/main/java/io/jans/fido2/service/readiness/WellKnownFetcher.java",
]
patterns={
 "trust-all strategy":r"(?i)TrustStrategy\s+\w+\s*=\s*\([^;]+?\)\s*->\s*true",
 "disabled hostname verification":r"NoopHostnameVerifier\.INSTANCE",
 "custom truststore":r"loadTrustMaterial\(new File\(trustStorePath\)",
}
missing=[]; hits=[]
for name in paths:
 p=root/name
 if not p.is_file(): missing.append(name); continue
 text=p.read_text(encoding="utf-8")
 for label,regex in patterns.items():
  for m in re.finditer(regex,text):
   line=text.count("\n",0,m.start())+1
   hits.append((name,line,label))
if missing:
 for name in missing: print("MISSING:",name,file=sys.stderr)
 sys.exit(2)
for name,line,label in hits: print(f"REVIEW {name}:{line}: {label}")
if not hits: sys.exit("No expected patterns found; review upstream changes before treating as clean")
print(f"Found {len(hits)} review signals in pinned Janssen sources; this is NOT an exploitability assessment.")
