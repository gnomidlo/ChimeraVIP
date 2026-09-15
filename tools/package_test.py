#!/usr/bin/env python3
"""Validate the actual archive and smoke-test its extracted Lua sources."""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

from build_standalone import ROOT, OUTPUT, EVENTS, build

lua = os.environ.get('LUA', 'lua5.1')
data = OUTPUT.read_bytes()
assert data == build(), 'Archive differs from its sources'
with tempfile.TemporaryDirectory(prefix='cvip2 package ') as temporary:
    directory = Path(temporary) / 'ChimeraVIP2'
    directory.mkdir()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names))
        assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in names)
        metadata = json.loads(archive.read('CONTENTS.json'))
        assert set(metadata['sha256']) == set(names) - {'CONTENTS.json'}
        for name, digest in metadata['sha256'].items():
            assert hashlib.sha256(archive.read(name)).hexdigest() == digest
        assert 'loader.lua' not in names and 'src/core/updater.lua' not in names
        xml = ET.fromstring(archive.read('ChimeraVIP2.xml'))
        script = xml.find('.//Script')
        assert script.findtext('name') == 'chimeraVip2PackageEvent'
        assert tuple(e.text for e in script.findall('./eventHandlerList/string')) == EVENTS
        assert script.findtext('script') == archive.read('standalone/package.lua').decode('utf-8')
        archive.extractall(directory)
    embedded = directory / 'embedded.lua'
    embedded.write_text(script.findtext('script'), encoding='utf-8')
    # Check every Lua payload, including config and the XML's actual script.
    for path in directory.rglob('*.lua'):
        subprocess.run([lua, '-e', 'assert(loadfile(os.getenv("CHECK_LUA")))'],
                       env={**os.environ, 'CHECK_LUA': str(path)}, check=True)
    subprocess.run([lua, str(ROOT / 'tools/package_test.lua'), str(embedded)], check=True)
    # Launch only extracted sources from an unrelated cwd: no repository fallback.
    harness = directory / 'features_test.lua'
    shutil.copyfile(ROOT / 'tools/features_test.lua', harness)
    subprocess.run([lua, str(harness), str(directory), temporary, str(embedded)],
                   cwd=temporary, check=True)
print('PASS package contents, checksums, XML event wiring and extracted standalone modules')
