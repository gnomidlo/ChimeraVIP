#!/usr/bin/env python3
"""Build the offline Mudlet package reproducibly using the standard library."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'packages' / 'ChimeraVIP2.mpackage'
EVENTS = ('sysLoadEvent', 'sysInstallPackage', 'sysUninstallPackage', 'sysExitEvent')


def build(root=ROOT):
    bootstrap = (root / 'standalone/package.lua').read_text(encoding='utf-8')
    init = (root / 'standalone/init.lua').read_text(encoding='utf-8')
    version = re.search(r'C.version = "([^"]+)"', init).group(1)
    features = (root / 'standalone/features.lua').read_text(encoding='utf-8')
    # Only the explicit reusable VIP sources, never the stable loader or updater.
    paths = set(re.findall(r"['\"](src/[^'\"]+\.lua)['\"]", features))
    paths.add('src/core/util.lua')
    paths.update(p.relative_to(root).as_posix() for p in (root / 'standalone').glob('*.lua'))
    entries = {path: (root / path).read_bytes() for path in sorted(paths)}
    handlers = ''.join('<string>' + event + '</string>' for event in EVENTS)
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE MudletPackage>\n'
           '<MudletPackage version="1.001"><ScriptPackage>'
           '<ScriptGroup isActive="yes" isFolder="yes"><name>ChimeraVIP2</name>'
           '<packageName>ChimeraVIP2</packageName><script></script><eventHandlerList/>'
           '<Script isActive="yes" isFolder="no"><name>chimeraVip2PackageEvent</name>'
           '<packageName>ChimeraVIP2</packageName><script>' + escape(bootstrap) + '</script>'
           '<eventHandlerList>' + handlers + '</eventHandlerList></Script>'
           '</ScriptGroup></ScriptPackage></MudletPackage>\n')
    entries['ChimeraVIP2.xml'] = xml.encode('utf-8')
    entries['config.lua'] = (
        'mpackage = "ChimeraVIP2"\n'
        'title = "ChimeraVIP 2.0 (wersja deweloperska)"\n'
        f'version = "{version}"\n'
        'author = "gnomidlo"\n'
        'description = [[Samodzielne VIP i mapper. Oficjalna Chimera i VIP 1.x musza byc wylaczone przed restartem profilu.]]\n'
    ).encode('utf-8')
    entries['CONTENTS.json'] = (json.dumps({
        'package': 'ChimeraVIP2', 'version': version,
        'sha256': {path: hashlib.sha256(data).hexdigest() for path, data in sorted(entries.items())},
    }, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path, data in sorted(entries.items()):
            info = zipfile.ZipInfo(path, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compresslevel=9)
    return output.getvalue()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = build()
    if args.check:
        if not args.output.exists() or args.output.read_bytes() != data:
            raise SystemExit('Package is missing or stale; run python3 tools/build_standalone.py')
        print('PASS standalone package matches its sources')
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(data)
        print(f'{args.output}: {len(data)} bytes, SHA256 {hashlib.sha256(data).hexdigest()}')
