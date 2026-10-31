"""Build reproducible Mudlet packages and a GitHub Releases update descriptor."""
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def build(repository: str = "", output: Path | None = None) -> Path:
    if repository and not re.fullmatch(r"[A-Za-z0-9-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Expected GitHub OWNER/REPO")
    version = (ROOT / "VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("VERSION must contain major.minor.patch")
    core = (ROOT / "src/Chimera_Kozojeb.lua").read_text()
    core += "\n" + (ROOT / "src/KozojebGolems.lua").read_text()
    if f'K.version = "{version}"' not in core:
        raise ValueError("VERSION differs from the Lua core version")
    updater = (ROOT / "src/KozojebUpdater.lua").read_text().replace(
        "__KOZO_RELEASE_REPOSITORY__", repository
    )
    scripts = [
        (f"Kozojeb {version}", core),
        ("Kozojeb SHA-256", (ROOT / "src/Sha256.lua").read_text()),
        ("Kozojeb updater", updater),
    ]
    root = ET.Element("MudletPackage", version="1.001")
    for node in ("TriggerPackage", "TimerPackage", "AliasPackage", "ActionPackage"):
        ET.SubElement(root, node)
    package = ET.SubElement(root, "ScriptPackage")
    group = ET.SubElement(package, "ScriptGroup", isActive="yes", isFolder="yes")
    ET.SubElement(group, "name").text = "Chimera_Kozojeb"
    ET.SubElement(group, "packageName").text = "Chimera_Kozojeb"
    ET.SubElement(group, "script")
    ET.SubElement(group, "eventHandlerList")
    for name, source in scripts:
        script = ET.SubElement(group, "Script", isActive="yes", isFolder="no")
        ET.SubElement(script, "name").text = name
        ET.SubElement(script, "packageName").text = "Chimera_Kozojeb"
        ET.SubElement(script, "script").text = source
        ET.SubElement(script, "eventHandlerList")
    xml = b'<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE MudletPackage>\n'
    xml += ET.tostring(root, encoding="utf-8")
    config = f'''mpackage = "Chimera_Kozojeb"
author = "Pipek (oryginalny KozoBot)"
title = "Chimera Kozojeb"
description = [[Patrol, role druzynowe, zaslony i aktualizacje GitHub. /kozojeb help]]
version = "{version}"
dependencies = ""
created = "2026-10-06"
'''.encode()
    files = {
        "config.lua": config,
        "Chimera_Kozojeb.xml": xml,
        "INSTRUKCJA.md": (ROOT / "README.md").read_bytes(),
        "CHANGELOG.md": (ROOT / "CHANGELOG.md").read_bytes(),
        "NOTICE.md": (ROOT / "NOTICE.md").read_bytes(),
    }
    output = output or ROOT / "dist"
    output.mkdir(parents=True, exist_ok=True)
    path = output / "Chimera_Kozojeb.mpackage"
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in files.items():
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data)
    data = path.read_bytes()
    (output / f"Chimera_Kozojeb_v{version}.mpackage").write_bytes(data)
    if repository:
        descriptor = {
            "schema": 1, "package": "Chimera_Kozojeb", "version": version,
            "min_mudlet": "4.20.0", "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "url": f"https://github.com/{repository}/releases/download/v{version}/Chimera_Kozojeb.mpackage",
        }
        (output / "update.json").write_text(json.dumps(descriptor, indent=2) + "\n")
    else:
        (output / "update.json").unlink(missing_ok=True)
    print(f"Built {path.name} ({version}, {len(data)} bytes)")
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default="")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    build(args.repository, args.output)
