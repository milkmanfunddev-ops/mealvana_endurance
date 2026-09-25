#!/usr/bin/env python3
"""Bundle the Fuel Timeline standalone source into a true single-file artifact.

Inputs (fetched from the Claude Design project 1844f744-…):
  v_standalone.html   — the "Fuel Timeline -standalone source-" body
  support.js          — the dc-runtime, verbatim
  deps/<Name>.dc.html — the eight dc-import component dependencies
Fonts come from this repo's assets/fonts/ (same families the project ships).

Transform: fonts → data: URIs in the main document; each dep → base64
data: URL in a window.__resources remap (the runtime treats __resources as a
URL remap and fetches the value), with dep-level duplicate @font-face rules
stripped; support.js inlined. React/ReactDOM/Babel stay on unpkg (SRI-pinned).
"""
import io, base64, re, sys
from urllib.parse import quote

SRC, SUPPORT, DEPS_DIR, OUT = sys.argv[1:5]
FONTS = "assets/fonts"
FONT_MAP = {
    "fonts/Apercu-Light.otf":     (FONTS + "/Apercu/Apercu-Light.otf", "font/otf"),
    "fonts/Apercu-Regular.otf":   (FONTS + "/Apercu/Apercu Regular.otf", "font/otf"),
    "fonts/Apercu-Medium.otf":    (FONTS + "/Apercu/Apercu-Medium.otf", "font/otf"),
    "fonts/Apercu-Bold.otf":      (FONTS + "/Apercu/Apercu-Bold.otf", "font/otf"),
    "fonts/Apercu-Mono.otf":      (FONTS + "/Apercu/Apercu-Mono.otf", "font/otf"),
    "fonts/Compadre-Regular.otf": (FONTS + "/Compadre/Compadre-Demo-Regular.otf", "font/otf"),
    "fonts/Compadre-Wide.otf":    (FONTS + "/Compadre/Compadre-Demo-Wide.otf", "font/otf"),
    "fonts/Sansita-Bold.ttf":     (FONTS + "/Sansita/Sansita-Bold.ttf", "font/ttf"),
}
DEPS = ["Day Header", "Day Nav", "Ride Fuel Sheet", "Add Food Sheet",
        "Breakdown Pager", "Full Breakdown Sheet", "Active Energy Sheet",
        "Energy Breakdown Sheet"]

src = io.open(SRC, encoding="utf-8").read()
support = io.open(SUPPORT, encoding="utf-8").read()
assert "</script>" not in support

for rel, (path, mime) in FONT_MAP.items():
    data = "data:%s;base64,%s" % (mime, base64.b64encode(open(path, "rb").read()).decode())
    tag = 'url("%s")' % rel
    assert src.count(tag) >= 1, rel
    src = src.replace(tag, 'url("%s")' % data)

resources = {}
for name in DEPS:
    c = io.open("%s/%s.dc.html" % (DEPS_DIR, name), encoding="utf-8").read()
    c = re.sub(r'@font-face\{[^}]*\}\n?', '', c)
    resources["./" + quote(name) + ".dc.html"] = \
        "data:text/html;base64," + base64.b64encode(c.encode()).decode()

res_js = "window.__resources = {\n" + ",\n".join(
    '  "%s": "%s"' % (k, v) for k, v in resources.items()) + "\n};"
tag = '<script src="./support.js"></script>'
assert src.count(tag) == 1
src = src.replace(tag, "<script>\n%s\n</script>\n<script>\n%s\n</script>" % (res_js, support))
io.open(OUT, "w", encoding="utf-8").write(src)
print(OUT, len(src.encode()), "bytes")
