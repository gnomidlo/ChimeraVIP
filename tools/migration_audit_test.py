import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import migration_audit as audit


class MigrationAuditTest(unittest.TestCase):
    def test_all_definitions_including_disabled_and_duplicate_names(self):
        nodes = [
            {"name": "folder", "isFolder": "yes", "isActive": "no", "children": [
                {"name": "same", "script": "first"},
                {"name": "same", "command": "n"}]},
            {"name": "external"}, {"name": "highlight", "highlight": True}]
        result = audit.definitions("src/triggers/triggers.json", nodes,
                                   {"src/triggers/external.lua"})
        self.assertEqual(len(result), 5)
        self.assertEqual(len({x["pointer"] for x in result}), 5)
        self.assertEqual(result[1]["script"], "inline")
        self.assertIsNone(result[2]["script"])
        self.assertEqual(result[3]["script"], "src/triggers/external.lua")
        self.assertEqual(result[0]["activation"], "no")
        self.assertEqual(result[1]["parents"], ["folder"])
        self.assertNotEqual(result[1]["sha256"], result[2]["sha256"])

    def test_snapshot_reads_commit_not_worktree_and_preserves_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return audit.git(root, *args)
            git("init", "-q")
            (root / "src").mkdir()
            (root / "src/a.lua").write_text("committed")
            (root / "src/image.png").write_bytes(b"\0\xff\n")
            git("add", "src")
            git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                "commit", "-qm", "fixture")
            revision = git("rev-parse", "HEAD").decode().strip()
            (root / "src/a.lua").write_text("dirty")
            (root / "src/untracked.lua").write_text("untracked")
            files = {name: content for name, _, content in audit.source_files(root, revision)}
            self.assertEqual(files, {"src/a.lua": b"committed", "src/image.png": b"\0\xff\n"})

    def fixture(self):
        return [{"source": "official", "files": [
            {"path": "src/one.lua", "sha256": "a" * 64},
            {"path": "src/triggers/triggers.json", "sha256": "b" * 64,
             "definitions": [{"pointer": "/0", "sha256": "c" * 64}]},
            {"path": "README.md", "sha256": "d" * 64}]}]

    def test_all_source_files_and_nodes_are_obligations(self):
        missing, done = audit.check(self.fixture(), {"schema": 1, "items": []})
        self.assertEqual(len(missing), 3)
        self.assertEqual(done, 0)

    def test_decisions_require_matching_source_target_and_test(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "target.lua").touch()
            (root / "test.lua").touch()
            item = {"id": "official:file:src/one.lua", "source_sha256": "a" * 64,
                    "status": "replaced", "reason": "Native equivalent",
                    "targets": ["target.lua"], "tests": ["test.lua"]}
            def validate(value):
                return audit.check(self.fixture(), {"schema": 1, "items": value}, root)
            self.assertEqual(validate([item])[1], 1)
            for changes in ({"status": "deferred"}, {"status": "dropped"},
                            {"source_sha256": "z" * 64}, {"targets": []},
                            {"tests": ["missing.lua"]}, {"targets": ["../target.lua"]},
                            {"id": "nonexistent"}, {"reason": ""}):
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    validate([{**item, **changes}])
            with self.assertRaises(ValueError):
                validate([item, item])

    def test_inventory_mutation_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in audit.BASE.glob("*-inventory.json"):
                (root / path.name).write_bytes(path.read_bytes())
            (root / "inventory-lock.json").write_bytes((audit.BASE / "inventory-lock.json").read_bytes())
            audit.read_inventories(root)
            path = root / "official-inventory.json"
            data = json.loads(path.read_text())
            data["files"].pop()
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "Inventory changed"):
                audit.read_inventories(root)

    def scope(self, status="pending"):
        return {"schema": 1, "required_sources": ["vip"],
                "official_policy": "reference-and-optional-backlog",
                "capabilities": [{"id": key, "label": key, "status": status,
                                  "evidence": ["proof.md"] if status == "verified" else []}
                                 for key in sorted(audit.FIRST_RELEASE_CAPABILITIES)]}

    def test_optional_official_sources_do_not_block_vip_mapper_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "proof.md").touch()
            (root / "native.lua").touch()
            inventories = self.fixture() + [{"source": "vip", "files": [
                {"path": "src/feature.lua", "sha256": "e" * 64}]}]
            decision = {"id": "vip:file:src/feature.lua", "source_sha256": "e" * 64,
                        "status": "replaced", "reason": "Standalone feature",
                        "targets": ["native.lua"], "tests": ["proof.md"]}
            decisions = {"schema": 1, "items": [decision]}
            self.assertEqual(len(audit.check(inventories, decisions, root)[0]), 3)
            self.assertEqual(audit.release_status(inventories, decisions, self.scope("verified"), root), ([], []))
            decisions["items"] = []
            missing, pending = audit.release_status(inventories, decisions, self.scope("verified"), root)
            self.assertEqual(missing, ["vip:file:src/feature.lua"])
            self.assertEqual(pending, [])

    def test_mapper_and_independence_require_verified_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "proof.md").touch()
            decisions = {"schema": 1, "items": []}
            scope = self.scope()
            _, pending = audit.release_status(self.fixture(), decisions, scope, root)
            self.assertIn("mapper_navigation", pending)
            self.assertIn("independent_boot", pending)
            scope = self.scope("verified")
            scope["capabilities"][0]["evidence"] = []
            with self.assertRaisesRegex(ValueError, "Missing capability evidence"):
                audit.release_status(self.fixture(), decisions, scope, root)
            scope = self.scope()
            scope["capabilities"].pop()
            with self.assertRaisesRegex(ValueError, "Incomplete first-release"):
                audit.release_status(self.fixture(), decisions, scope, root)
            scope = self.scope()
            scope["required_sources"] = []
            with self.assertRaisesRegex(ValueError, "preserve the VIP"):
                audit.release_status(self.fixture(), decisions, scope, root)

    def test_committed_report_is_current(self):
        inventories = audit.read_inventories(audit.BASE)
        decisions = json.loads((audit.BASE / "decisions.json").read_text())
        self.assertEqual(audit.report(inventories, decisions),
                         (audit.ROOT / "docs/standalone-v2-coverage.md").read_text())


if __name__ == "__main__":
    unittest.main()
