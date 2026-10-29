"""Run the Lua simulations and verify the reproducible release package."""
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from build import ROOT, build

# Sprawdzenie rzeczywistego zarejestrowanego wzorca, obok symulacji handlera.
source = (ROOT / "src/Chimera_Kozojeb.lua").read_text()
rejection = re.search(
    r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.onMovementExhausted\(\)\]\]', source
)
assert rejection, "Missing movement exhaustion trigger"
pattern = json.loads(rejection.group(1))
for line in ("Jestes tak zmeczony, ze nie mozesz isc.",
             "Jestes tak zmeczony, ze nie mozesz isc w tym kierunku."):
    assert re.fullmatch(pattern, line), "Logged movement refusal did not match: " + line
assert not re.fullmatch(pattern, "Nie widzisz zadnego wyjscia prowadzacego na zachod.")

for test in ("roles.lua", "sha256.lua", "updater.lua"):
    subprocess.run([sys.executable, "tools/run_lua.py", f"tests/{test}"], cwd=ROOT, check=True)

with tempfile.TemporaryDirectory() as directory:
    target = Path(directory)
    package = build("example/kozojeb", target)
    first = package.read_bytes()
    manifest = json.loads((target / "update.json").read_text())
    assert manifest["size"] == len(first)
    assert manifest["sha256"] == hashlib.sha256(first).hexdigest()
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None
        root = ET.fromstring(archive.read("Chimera_Kozojeb.xml"))
        scripts = root.findall(".//Script")
        assert len(scripts) == 3
        assert scripts[0].findtext("script") == (ROOT / "src/Chimera_Kozojeb.lua").read_text()
        assert 'local releaseRepository = "example/kozojeb"' in scripts[2].findtext("script")
        assert all(script.get("isActive") == "yes" for script in scripts)
        assert b'author = "Pipek (oryginalny KozoBot)"' in archive.read("config.lua")
        assert all(not name.endswith((".log", ".txt", ".dat")) for name in archive.namelist())
    build("example/kozojeb", target)
    assert first == package.read_bytes(), "Package build is not reproducible"
print("Package integrity, source equality, checksum and reproducibility passed")
