"""Run the Lua simulations and verify the reproducible release package."""
import hashlib
import json
import os
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
             "Bierzesz cztery powyginane pancerze plytowe.",
             "Bierzesz trzy powyginane pancerze plytowe z otwartego skorzanego plecaka.",
             "Wkladasz powyginany pancerz plytowy do otwartego skorzanego plecaka.",
             "Przestajesz przeszukiwac powyginany pancerz plytowy.",
             "Przestajesz przeszukiwac zniszczony powyginany pancerz plytowy.",
             "Odkladasz powyginany pancerz plytowy.", "Wez co?", "Odloz co?",
             "   Powyginany pancerz plytowy jest zbyt ciezki."):
    assert re.fullmatch(armor_pattern, line), "Missing armor confirmation: " + line
assert not re.fullmatch(armor_pattern, "Zniszczony powyginany pancerz plytowy rozsypuje sie w proch.")
assert not re.fullmatch(armor_pattern, "Nie udalo ci sie znalezc niczego interesujacego.")
gem_trigger = re.search(
    r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.G\.onGemText', golems_source
)
assert gem_trigger, "Missing gem acquisition and handoff trigger"
gem_pattern = json.loads(gem_trigger.group(1))
gem_prefix = "Udaje ci sie otworzyc ukryta na piersi zgruchotanego golema klapke i zabierasz znajdujace sie pod"
for line in (gem_prefix + " ", "nia zrodlo mocy konstruktu, oliwkowozielony oliwin.",
             gem_prefix + " nia zrodlo mocy konstruktu, oliwkowozielony oliwin.",
             "Dajesz oliwkowozielony oliwin Grorowi."):
    assert re.fullmatch(gem_pattern, line), "Missing gem event: " + line
assert not re.fullmatch(gem_pattern, "Morrid mowi: nia zrodlo mocy konstruktu, oliwkowozielony oliwin.")

for prefix, succeeded in (("Zaslaniasz", "true"), ("Probujesz zaslonic", "false")):
    own_reply = re.search(
        r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.onShieldResult\(matches\[2\], '
        + succeeded + r', matches\[3\]\)\]\]', source
    )
    assert own_reply, "Missing NPC description in own shield reply"
    line = prefix + " Grora przed ciosami pekatego skrzypiacego golema"
    line += "." if succeeded == "true" else ", lecz nie jestes w stanie tego uczynic."
    match = re.match(json.loads(own_reply.group(1)), line)
    assert match and match.groups() == ("Grora", "pekatego skrzypiacego golema")

conflicts = re.findall(
    r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.onLoginConflict\(\)\]\]', source
)
for line in ("Nowe interaktywne polaczenie do twej postaci. Zamykam te sesje.",
             "Twoja postac jest juz w grze. Czy chcesz przejac nad nia kontrole? "):
    assert any(re.match(json.loads(pattern), line) for pattern in conflicts)

covers_source = (ROOT / "src/KozojebCovers.lua").read_text()
for handler,examples in (
    ("onTeamCover",[("Gror zaslania Yarrima przed ciosami pekatego nieforemnego golema.",
                     ("Gror","Yarrima","pekatego nieforemnego golema")),
                    ("Yergo zrecznie zaslania cie przed ciosami skrzypiacego golema.",
                     ("Yergo","cie","skrzypiacego golema"))]),
    ("onTeamFailure",[("Yergo probuje zaslonic Yarrima przed ciosami zgrzytajacego nieforemnego golema, lecz nie jest w",
                       ("Yergo","Yarrima","zgrzytajacego nieforemnego golema")),
                      ("Yergo probuje zaslonic cie przed ciosami pekatego porysowanego golema, lecz nie jest w stanie",
                       ("Yergo","cie","pekatego porysowanego golema"))]),
    ("onConsumed",[("Porysowany nieforemny golem zbliza sie do powyginanego pancerza plytowego, podnosi go i wciska do",
                    ("Porysowany nieforemny golem",))]),
):
    module, text = ("G", golems_source) if handler == "onConsumed" else ("C", covers_source)
    registered=re.search(r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.'+module+r'\.'+handler, text)
    assert registered, "Missing golem trigger: " + handler
    for line,groups in examples:
        match=re.match(json.loads(registered.group(1)),line)
        assert match and match.groups()==groups, "Wrong golem event: " + line

protected_failure=re.search(r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.C\.onTeamFailure\(matches\[2\],"cie",matches\[3\]\)',covers_source)
assert protected_failure, "Missing protected player's word order in failed cover"
match=re.match(json.loads(protected_failure.group(1)),
    "Yergo probuje cie zaslonic przed ciosami porysowanego nieforemnego golema, lecz nie jest w stanie tego uczynic.")
assert match and match.groups()==("Yergo","porysowanego nieforemnego golema")
walker_stop=re.search(r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.onWalkerAttackStop\(\)\]\]',source)
assert walker_stop and re.fullmatch(json.loads(walker_stop.group(1)),"(Chimera) Chodzik zatrzymany: atak.")
assert not re.fullmatch(json.loads(walker_stop.group(1)),"(Chimera) Chodzik zatrzymany: recznie.")

safety_source = (ROOT / "src/KozojebSafety.lua").read_text()
light_patterns = re.findall(r'tempRegexTrigger\(("(?:\\.|[^"\\])*"),\[\[kozojeb\.S\.onLight\(\)\]\]', safety_source)
for line in ("Zapalasz lampe.", "Zapalasz olejna lampe.", "Zapalasz pochodnie.",
             "Zapalasz latarnie.", "Olejna zapalona lampa jest juz zapalona."):
    assert any(re.fullmatch(json.loads(pattern), line) for pattern in light_patterns), "Missing light acknowledgement: " + line
assert not any(re.fullmatch(json.loads(pattern), "Gror zapala lampe.") for pattern in light_patterns)
flow_source = (ROOT / "src/KozojebFlow.lua").read_text()
trap_trigger = re.search(r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\[\[kozojeb\.F\.onTrap', flow_source)
assert trap_trigger, "Missing logged trap trigger"
trap_pattern = json.loads(trap_trigger.group(1))
for line in (
    "kociej wrecz zrecznosci udaje ci sie uniknac straszliwego ciecia oraz stracenia do otchlani.",
    "Nagle z boku z glosnym swistem wylatuje ostrze. Straszliwe ciecie obraca cie, niczym szmaciana",
    "lalke. Tracisz rownowage i spadasz w otchlan.",
):
    assert re.fullmatch(trap_pattern, line), "Missing wrapped bridge trap: " + line
assert not re.fullmatch(trap_pattern, "Ogromny golem rani cie w korpus.")
assert not re.fullmatch(trap_pattern, "Morrid mowi: Nagle z boku Straszliwe ciecie obraca cie.")
general_cover = re.search(r'tempRegexTrigger\(\s*("(?:\\.|[^"\\])*"),\s*\[\[kozojeb\.C\.onTeamCover', covers_source)
assert general_cover
for line, groups in (("Morrid zaslania Yarrima przed ciosami bladego zwinnego ozywienca.",
                      ("Morrid", "Yarrima", "bladego zwinnego ozywienca")),
                     ("Yergo zrecznie zaslania cie przed ciosami brutalnego smierdzacego orka.",
                      ("Yergo", "cie", "brutalnego smierdzacego orka"))):
    match = re.match(json.loads(general_cover.group(1)), line)
    assert match and match.groups() == groups

for test in ("roles.lua", "team_safety.lua", "sha256.lua", "updater.lua"):
    subprocess.run([sys.executable, "tools/run_lua.py", f"tests/{test}"], cwd=ROOT, check=True)

with tempfile.TemporaryDirectory() as directory:
    env = dict(os.environ, KOZO_COMBAT_LOG_TEST_DIR=directory)
    subprocess.run([sys.executable, "tools/run_lua.py", "tests/combat_log.lua"], cwd=ROOT, env=env, check=True)
    records = []
    for path in Path(directory).glob("*.jsonl*"):
        data = path.read_bytes()
        assert data.endswith(b"\n"), "Recorder left an incomplete JSON line"
        for line in data.decode("utf-8").splitlines():
            record = json.loads(line, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
            assert record["schema"] == 1 and isinstance(record["time"], (int, float))
            if record["kind"] == "state":
                assert all(isinstance(record[key], list) for key in ("members", "npcs", "covers", "relations"))
                assert isinstance(record["shield"]["checks"], list)
            records.append(record)
    assert len(records) >= 20
    assert {"state", "shield_sent", "shield_reply", "stop", "exit", "reload", "sysDisconnectionEvent"} <= {r["kind"] for r in records}
print("Recorder JSONL structure, UTF-8, finite numbers and complete records passed")

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
            + "\n" + (ROOT / "src/KozojebGolems.lua").read_text()
            + "\n" + (ROOT / "src/KozojebCovers.lua").read_text()
            + "\n" + (ROOT / "src/KozojebSafety.lua").read_text()
            + "\n" + (ROOT / "src/KozojebFlow.lua").read_text()
            + "\n" + (ROOT / "src/KozojebCombatLog.lua").read_text())
        assert 'local releaseRepository = "example/kozojeb"' in scripts[2].findtext("script")
        assert all(script.get("isActive") == "yes" for script in scripts)
        assert b'author = "Pipek (oryginalny KozoBot)"' in archive.read("config.lua")
        assert all(not name.endswith((".log", ".txt", ".dat")) for name in archive.namelist())
    build("example/kozojeb", target)
    assert first == package.read_bytes(), "Package build is not reproducible"
print("Package integrity, source equality, checksum and reproducibility passed")
