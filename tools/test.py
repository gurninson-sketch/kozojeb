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

for handler, examples in (
    ("onTeamShield", [
        ("Gror zaslania Morrida przed ciosami orka.", ("Gror", "Morrida")),
        ("Gror zrecznie zaslania Yarrima przed ciosami wrogow.", ("Gror", "Yarrima")),
    ]),
    ("onCoveredByLeader", [
        ("Morrid zaslania cie przed ciosami orka.", ("Morrid",)),
        ("Gror zrecznie zaslania cie przed ciosami wrogow.", ("Gror",)),
    ]),
    ("onTeamCombat", [
        ("Maly glupkowaty snotling ATAKUJE Yarrima.", ("Maly glupkowaty snotling", "Yarrima")),
        ("Yarrim ATAKUJE malego snotlinga.", ("Yarrim", "malego snotlinga")),
    ]),
):
    registered = re.search(
        r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.' + handler + r'\(.*?\)\]\]', source
    )
    assert registered, "Missing shield text trigger: " + handler
    for line, groups in examples:
        match = re.match(json.loads(registered.group(1)), line)
        assert match and match.groups() == groups, "Combat text captured the wrong actor or target: " + line

own_attack = re.search(
    r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.onTeamCombat\(matches\[2\], "cie", true\)\]\]', source
)
assert own_attack, "Missing own incoming attack trigger"
assert re.fullmatch(json.loads(own_attack.group(1)), "Maly glupkowaty snotling ATAKUJE CIE!").groups() == ("Maly glupkowaty snotling",)

golems_source = (ROOT / "src/KozojebGolems.lua").read_text()
armor_trigger = re.search(
    r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.G\.onText', golems_source
)
assert armor_trigger, "Missing armor confirmation trigger"
armor_pattern = json.loads(armor_trigger.group(1))
for line in ("Bierzesz powyginany pancerz plytowy.",
             "Przestajesz przeszukiwac powyginany pancerz plytowy.",
             "Przestajesz przeszukiwac zniszczony powyginany pancerz plytowy.",
             "Odkladasz powyginany pancerz plytowy.", "Wez co?", "Odloz co?"):
    assert re.fullmatch(armor_pattern, line), "Missing armor confirmation: " + line
assert not re.fullmatch(armor_pattern, "Zniszczony powyginany pancerz plytowy rozsypuje sie w proch.")
assert not re.fullmatch(armor_pattern, "Nie udalo ci sie znalezc niczego interesujacego.")

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
        assert scripts[0].findtext("script") == ((ROOT / "src/Chimera_Kozojeb.lua").read_text()
            + "\n" + (ROOT / "src/KozojebGolems.lua").read_text())
        assert 'local releaseRepository = "example/kozojeb"' in scripts[2].findtext("script")
        assert all(script.get("isActive") == "yes" for script in scripts)
        assert b'author = "Pipek (oryginalny KozoBot)"' in archive.read("config.lua")
        assert all(not name.endswith((".log", ".txt", ".dat")) for name in archive.namelist())
    build("example/kozojeb", target)
    assert first == package.read_bytes(), "Package build is not reproducible"
print("Package integrity, source equality, checksum and reproducibility passed")
