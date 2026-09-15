#!/usr/bin/env python3
"""Pinned migration inventory. Uses git objects, never executes upstream code.

snapshot requires local source repositories; check/report work offline in CI.
Completeness accounting is deliberately separate from functional test results.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "migration"
SOURCES = {
    "official": {
        "url": "https://gitlab.com/bfbps-group/chimera-mud-skrypty",
        "commit": "2e6c3372220483b4e70b3f5cb24a4777437d5c6c",
    },
    "vip": {
        "url": "https://github.com/gnomidlo/ChimeraVIP",
        "commit": "a5e5951661ec53295663587769057cc25c5b867f",
    },
}
KINDS = {x + ".json": x for x in ("aliases", "triggers", "keys", "timers", "scripts")}
FIRST_RELEASE_CAPABILITIES = {
    "independent_boot", "vip_features", "own_ui", "gmcp_state",
    "mapper_view_position", "mapper_navigation", "data_preservation", "package_lifecycle",
}


def git(repo, *args, data=None):
    return subprocess.run(["git", "-C", str(repo), *args], input=data,
                          check=True, stdout=subprocess.PIPE).stdout


def source_files(repo, commit):
    """Read the committed tree including binary assets, ignoring dirty worktrees."""
    tree = git(repo, "ls-tree", "-r", "-z", commit).split(b"\0")
    entries = []
    for line in filter(None, tree):
        meta, name = line.split(b"\t", 1)
        mode, kind, oid = meta.decode().split()
        if kind != "blob" or mode not in ("100644", "100755"):
            raise ValueError("Unsupported tree entry: " + name.decode())
        entries.append((name.decode(), oid, mode))
    raw = git(repo, "cat-file", "--batch",
              data=("\n".join(x[1] for x in entries) + "\n").encode())
    pos = 0
    result = []
    for name, oid, mode in entries:
        end = raw.index(b"\n", pos)
        actual, kind, size = raw[pos:end].decode().split()
        if actual != oid or kind != "blob":
            raise ValueError("Invalid git batch response")
        size = int(size)
        content = raw[end + 1:end + 1 + size]
        if len(content) != size:
            raise ValueError("Truncated git object")
        pos = end + size + 2
        result.append((name, mode, content))
    return result


def definitions(path, data, available):
    """Keep every node, including disabled nodes, folders and duplicate names.

    JSON pointers identify duplicates. Script metadata is not execution: Mudlet
    parent-folder activation and Muddler inheritance still need porting.
    """
    def walk(nodes, pointer="", parents=()):
        if not isinstance(nodes, list):
            raise ValueError(path + ": definitions must be a list")
        for index, node in enumerate(nodes):
            if not isinstance(node, dict) or not isinstance(node.get("name"), str):
                raise ValueError(path + ": malformed definition")
            at = pointer + "/" + str(index)
            name = node["name"]
            external = str(PurePosixPath(path).parent / (name + ".lua"))
            # Do not guess whether a command-only or highlighting node needs Lua.
            script = "inline" if "script" in node else (
                external if external in available else None)
            yield {
                "pointer": at, "name": name, "parents": list(parents),
                "folder": node.get("isFolder") in (True, "yes", "true"),
                "activation": node.get("isActive", "default"),
                "script": script,
                "properties": sorted(k for k in node if k != "children"),
                "sha256": hashlib.sha256(json.dumps(
                    {k: v for k, v in node.items() if k != "children"},
                    sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
            }
            yield from walk(node.get("children", []), at + "/children", parents + (name,))
    return list(walk(data))


def snapshot(source, repo):
    spec = SOURCES[source]
    files = source_files(repo, spec["commit"])
    available = {name for name, _, _ in files}
    records = []
    for name, mode, content in files:
        record = {"path": name, "mode": mode, "size": len(content),
                  "sha256": hashlib.sha256(content).hexdigest()}
        if name.startswith("src/") and PurePosixPath(name).name in KINDS:
            record["definitions"] = definitions(name, json.loads(content), available)
        records.append(record)
    return {"schema": 1, "source": source, **spec, "files": records}


def obligations(inventories):
    """All source files AND all Mudlet definitions must receive a disposition.

    Assets are included. Repository docs/tests/build tooling stay inventoried,
    but are not counted as gameplay functionality.
    """
    result = {}
    for inv in inventories:
        source = inv["source"]
        for record in inv["files"]:
            path = record["path"]
            if path.startswith("src/"):
                result[source + ":file:" + path] = record["sha256"]
            for node in record.get("definitions", []):
                result[source + ":node:" + path + "#" + node["pointer"]] = node["sha256"]
    return result


def read_inventories(base):
    inventories = []
    lock = json.loads((base / "inventory-lock.json").read_text())
    for source, spec in SOURCES.items():
        raw = (base / (source + "-inventory.json")).read_bytes()
        if hashlib.sha256(raw).hexdigest() != lock.get(source):
            raise ValueError("Inventory changed; regenerate from pinned sources: " + source)
        inv = json.loads(raw)
        if inv.get("schema") != 1 or inv.get("source") != source:
            raise ValueError("Invalid inventory: " + source)
        if any(inv.get(k) != v for k, v in spec.items()):
            raise ValueError("Source revision changed: " + source)
        paths = set()
        for record in inv["files"]:
            path = record["path"]
            if path in paths or PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
                raise ValueError("Invalid or duplicate source path: " + path)
            paths.add(path)
            if len(record["sha256"]) != 64 or record["size"] < 0:
                raise ValueError("Invalid source digest: " + path)
            pointers = set()
            for node in record.get("definitions", []):
                if node["pointer"] in pointers:
                    raise ValueError("Duplicate definition: " + path)
                pointers.add(node["pointer"])
        inventories.append(inv)
    return inventories


def local_file(root, path):
    if not isinstance(path, str) or not path:
        return False
    candidate = (root / path).resolve()
    return not Path(path).is_absolute() and candidate.is_relative_to(root.resolve()) and candidate.is_file()


def check(inventories, decisions, root=ROOT):
    required = obligations(inventories)
    if decisions.get("schema") != 1 or not isinstance(decisions.get("items"), list):
        raise ValueError("Invalid decisions schema")
    resolved = set()
    for item in decisions["items"]:
        key = item["id"]
        if key not in required or key in resolved:
            raise ValueError("Unknown or duplicate decision: " + key)
        if item.get("source_sha256") != required[key]:
            raise ValueError("Decision is stale: " + key)
        if item.get("status") not in ("ported", "replaced"):
            raise ValueError("A dropped/deferred item is not a completed migration: " + key)
        if not item.get("reason", "").strip():
            raise ValueError("Missing rationale: " + key)
        for field in ("targets", "tests"):
            if not isinstance(item.get(field), list) or not item[field]:
                raise ValueError("Missing " + field + ": " + key)
            if not all(local_file(root, p) for p in item[field]):
                raise ValueError("Missing/outside-repository " + field + ": " + key)
        resolved.add(key)
    return sorted(set(required) - resolved), len(resolved)


def release_status(inventories, decisions, scope, root=ROOT):
    """VIP + mapper readiness, distinct from full upstream inventory accounting."""
    if scope.get("schema") != 1 or scope.get("required_sources") != ["vip"]:
        raise ValueError("First release must preserve the VIP source scope")
    if scope.get("official_policy") != "reference-and-optional-backlog":
        raise ValueError("Invalid official source policy")
    missing, _ = check(inventories, decisions, root)
    required = [key for key in missing if key.startswith("vip:")]
    capabilities = scope.get("capabilities")
    if not isinstance(capabilities, list):
        raise ValueError("Missing first-release capabilities")
    seen = set()
    pending = []
    for capability in capabilities:
        key = capability["id"]
        if key in seen or key not in FIRST_RELEASE_CAPABILITIES:
            raise ValueError("Unknown or duplicate capability: " + key)
        seen.add(key)
        if capability.get("status") not in ("pending", "verified"):
            raise ValueError("Invalid capability status: " + key)
        if not isinstance(capability.get("evidence"), list):
            raise ValueError("Invalid capability evidence: " + key)
        if not capability.get("label", "").strip():
            raise ValueError("Missing capability label: " + key)
        if capability["status"] == "verified":
            if not capability["evidence"] or not all(local_file(root, p) for p in capability["evidence"]):
                raise ValueError("Missing capability evidence: " + key)
        else:
            pending.append(key)
    if seen != FIRST_RELEASE_CAPABILITIES:
        raise ValueError("Incomplete first-release capability list")
    return required, pending


def report(inventories, decisions, scope=None):
    missing, done = check(inventories, decisions)
    if scope is None:
        scope = json.loads((BASE / "scope.json").read_text())
    required, pending = release_status(inventories, decisions, scope)
    rows = ["# Kompletność migracji ChimeraVIP 2.0", "",
            "Raport generowany przez `python3 tools/migration_audit.py report`.", "",
            "Pierwsze wydanie: **obecne funkcje VIP + samodzielny mapper**.",
            "Oficjalna Chimera pozostaje zainstalowana i wyłączona.", "",
            "Pełny spis obu repozytoriów służy jako materiał odniesienia. Nie wymaga",
            "przeniesienia całej oficjalnej paczki. Foldery, definicje nieaktywne",
            "i zasoby pozostają w spisie, także jeśli nie należą do pierwszego wydania.", "",
            "| Źródło | Pliki repozytorium | Pliki src | Definicje Mudleta (z folderami) |",
            "|---|---:|---:|---:|"]
    for inv in inventories:
        records = inv["files"]
        rows.append("| {} | {} | {} | {} |".format(
            inv["source"], len(records), sum(r["path"].startswith("src/") for r in records),
            sum(len(r.get("definitions", [])) for r in records)))
    rows += ["", "Ukończone pozycje: **{}**. Nierozliczone: **{}**.".format(done, len(missing)),
             "", "Powyższe liczby dotyczą pełnej ewidencji źródeł, a nie zakresu wydania 2.0.",
             "", "## Gotowość pierwszego wydania", "",
             "Nierozliczone pozycje VIP: **{}**. Niepotwierdzone kryteria: **{}**.".format(len(required), len(pending)),
             "", "**VIP + mapper: " + ("NIEGOTOWE" if required or pending else "ewidencja kompletna") + ".**", "",
             "Brak odpowiedników opcjonalnych funkcji oficjalnej Chimery nie blokuje tego zakresu.",
             "Kryteria i dowody: `migration/scope.json`.", "",
             "Nawet kompletna ewidencja nie potwierdza działania w Mudlecie ani zgodności z serwerem.",
             "Istnienie pliku testu nie oznacza jego wykonania; za uruchomienie odpowiada CI.", "",
             "## Definicje oficjalnej paczki", "",
             "| Typ | Wszystkie | Foldery | Jawnie nieaktywne |", "|---|---:|---:|---:|"]
    groups = {}
    for inv in inventories:
        if inv["source"] != "official":
            continue
        for r in inv["files"]:
            if "definitions" in r:
                groups.setdefault(PurePosixPath(r["path"]).name, []).extend(r["definitions"])
    for kind, nodes in sorted(groups.items()):
        rows.append("| {} | {} | {} | {} |".format(kind, len(nodes),
            sum(n["folder"] for n in nodes),
            sum(n["activation"] in (False, "no", "false") for n in nodes)))
    counts = Counter(key.split(":file:", 1)[-1].split("/")[1]
                     for key in missing if key.startswith("official:file:src/"))
    rows += ["", "## Nierozliczone pliki oficjalnej paczki", "",
             "| Katalog src | Pliki |", "|---|---:|"]
    rows += ["| {} | {} |".format(k, v) for k, v in sorted(counts.items())]
    rows += ["", "Szczegóły: `migration/official-inventory.json`, `migration/vip-inventory.json`.",
             "Decyzje: `migration/decisions.json`. Brak decyzji dla VIP oznacza pracę do wykonania.",
             "Nierozliczone źródła oficjalne pozostają materiałem do selektywnego wykorzystania później.",
             "Ten raport nie uruchamia ani nie kopiuje kodu upstreamu.", ""]
    return "\n".join(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    capture = commands.add_parser("snapshot")
    capture.add_argument("--official", type=Path, required=True)
    capture.add_argument("--vip", type=Path, default=ROOT)
    commands.add_parser("check")
    commands.add_parser("report")
    commands.add_parser("release-gate")
    args = parser.parse_args(argv)
    if args.command == "snapshot":
        BASE.mkdir(exist_ok=True)
        lock = {}
        for source in SOURCES:
            inv = snapshot(source, getattr(args, source))
            raw = (json.dumps(inv, indent=2, ensure_ascii=False) + "\n").encode()
            (BASE / (source + "-inventory.json")).write_bytes(raw)
            lock[source] = hashlib.sha256(raw).hexdigest()
        (BASE / "inventory-lock.json").write_text(json.dumps(lock, indent=2) + "\n")
        return 0
    inventories = read_inventories(BASE)
    decisions = json.loads((BASE / "decisions.json").read_text())
    missing, done = check(inventories, decisions)
    scope = json.loads((BASE / "scope.json").read_text())
    required, pending = release_status(inventories, decisions, scope)
    if args.command == "report":
        print(report(inventories, decisions), end="")
    else:
        print("Inventory valid: {} accounted for, {} unresolved.".format(done, len(missing)))
    if args.command == "release-gate" and (required or pending):
        print("BLOCKED: VIP + mapper: {} unresolved VIP items, {} unverified capabilities.".format(
            len(required), len(pending)), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        sys.exit(1)
