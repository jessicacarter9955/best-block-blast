from pathlib import Path


index = Path("build/web/index.html")
html = index.read_text(encoding="utf-8")
sdk = '<script src="https://www.youtube.com/game_api/v1"></script>'
if sdk not in html:
    marker = '<script src="flutter_bootstrap.js" async></script>'
    if marker not in html:
        raise SystemExit("Flutter bootstrap tag not found in build/web/index.html")
    index.write_text(html.replace(marker, f"{sdk}\n  {marker}"), encoding="utf-8")
