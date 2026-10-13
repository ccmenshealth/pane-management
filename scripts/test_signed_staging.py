#!/usr/bin/env python3
"""Synthetic staging checks: no subprocess port is ever used."""
import contextlib
import io
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import signed_staging as s

FINGERPRINT = "A" * 40
TEAM = "ABCDEFGHIJ"
HEAD = "b" * 40
SUBMISSION = "11111111-1111-4111-8111-111111111111"
ARGV = ["--identity", FINGERPRINT, "--team-id", TEAM, "--notary-profile", "existing-profile"]


class FakeCommands:
    def __init__(self, root):
        self.root = root
        self.calls = []
        self.fail_at = None
        self.dirty = False
        self.changed = False
        self.identities = f'  1) {FINGERPRINT} "Developer ID Application: Example ({TEAM})"\n'
        self.bad_metadata = None
        self.entitlements = {}
        self.receipt = {"id": SUBMISSION, "status": "Accepted"}
        self.final_seen = None
        self.race = False

    def __call__(self, command, cwd):
        assert cwd == self.root
        tool, args = Path(command[0]).name, command[1:]
        self.calls.append((tool, args))
        if self.fail_at == len(self.calls):
            raise s.StagingError("Injected command failure")
        if tool == "git":
            if args[0] == "status":
                return (b" M dirty" if self.dirty else b""), b""
            if self.changed and len(self.calls) > 5:
                return b"c" * 40, b""
            return HEAD.encode(), b""
        if tool == "security":
            return self.identities.encode(), b""
        if tool == "xcrun" and args[0] == "--find":
            return b"/synthetic/developer/tool", b""
        if tool == "swift":
            scratch = Path(args[args.index("--scratch-path") + 1])
            output = scratch / "release"
            output.mkdir(parents=True, exist_ok=True)
            for binary in ("PaneManagement", "PaneAlwaysOn"):
                (output / binary).write_bytes(b"synthetic binary")
            return str(output).encode(), b""
        if tool == "iconutil":
            Path(args[args.index("--output") + 1]).write_bytes(b"synthetic icon")
            return b"", b""
        if tool == "codesign":
            if "--entitlements" in args:
                return plistlib.dumps(self.entitlements), b""
            if "--display" in args:
                identifier = s.HELPER_ID if args[-1].endswith("PaneAlwaysOn") else s.APP_ID
                metadata = f"Identifier={identifier}\nTeamIdentifier={TEAM}\nCodeDirectory v=20500 flags=0x10000(runtime) hashes=1\nTimestamp=Oct 12, 2026 at 12:00:00\n"
                if self.bad_metadata:
                    old, new = self.bad_metadata
                    metadata = metadata.replace(old, new)
                return b"", metadata.encode()
            return b"", b""
        if tool == "ditto":
            Path(args[-1]).write_bytes(b"synthetic zip")
            return b"", b""
        if tool == "xcrun" and args[:2] == ["notarytool", "submit"]:
            return json.dumps(self.receipt).encode(), b""
        if tool == "xcrun" and args[0] == "stapler":
            return b"", b""
        if tool == "spctl":
            self.final_seen = self.root / "dist/signed-staging/candidate"
            assert not self.final_seen.exists(), "Published before verification finished"
            if self.race:
                self.final_seen.mkdir()
                (self.final_seen / "preserve").write_text("race winner")
            return b"", b""
        raise AssertionError("Unrecognized synthetic command: " + repr(command))


class StagingChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        resources = self.root / "Resources"
        resources.mkdir()
        (resources / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": s.APP_ID, "CFBundleExecutable": "PaneManagement",
                      "CFBundlePackageType": "APPL", "LSUIElement": False}))
        (resources / s.DAEMON_PLIST).write_bytes(plistlib.dumps({"Label": s.HELPER_ID, "BundleProgram": "Contents/MacOS/PaneAlwaysOn",
                      "MachServices": {s.HELPER_ID: True}, "RunAtLoad": True,
                      "KeepAlive": True, "ProcessType": "Background"}))
        (self.root / "Icons/AppIcon.iconset").mkdir(parents=True)
        glyph = self.root / "Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf"
        glyph.parent.mkdir(parents=True)
        glyph.write_bytes(b"glyph")
        self.fake = FakeCommands(self.root)
        self.subject = s.Staging(self.root, run=self.fake, candidate_name="candidate")
        # A faulty test wiring must fail, never fall through to real signing/commands.
        self.guard = patch.object(s.subprocess, "run", side_effect=AssertionError("Native command forbidden"))
        self.guard.start()
        self.addCleanup(self.guard.stop)

    def stage(self):
        return self.subject.stage(s.arguments(ARGV))

    def refused(self):
        with self.assertRaises((s.StagingError, OSError, ValueError)):
            self.stage()
        parent = self.root / "dist/signed-staging"
        self.assertFalse(parent.exists() and list(parent.iterdir()))

    def test_arguments(self):
        for argv in ([], ["--identity", "-"], ARGV + ["--identity", FINGERPRINT],
                     ["--preflight", "--identity", FINGERPRINT], ARGV[:-1],
                     ["--unknown"], ["--preflight", "--preflight"], ARGV + ["--iden", FINGERPRINT],
                     ["--identity", "f" * 39, "--team-id", TEAM, "--notary-profile", "profile"],
                     ["--identity", FINGERPRINT, "--team-id", "bad", "--notary-profile", "profile"]):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises((s.StagingError, SystemExit)):
                    s.arguments(argv)
        self.assertEqual(s.arguments(ARGV).identity, FINGERPRINT)

    def test_preflight_has_no_artifacts_or_identity_lookup(self):
        result = self.subject.stage(s.arguments(["--preflight"]))
        self.assertEqual(result["preflight"], "passed")
        self.assertFalse((self.root / "dist").exists())
        self.assertEqual([name for name, _ in self.fake.calls], ["git", "git", "xcrun", "xcrun", "xcrun"])

    def test_fixed_tool_paths(self):
        self.assertEqual(s.TOOLS["spctl"], "/usr/sbin/spctl")
        for name, path in s.TOOLS.items():
            self.assertTrue(Path(path).is_file(), name)

    def test_non_object_notary_has_actionable_error(self):
        self.fake.receipt = []
        with self.assertRaisesRegex(s.StagingError, "Notarization was not accepted"):
            self.stage()

    def test_command_error_identifies_operation_without_profile(self):
        from types import SimpleNamespace
        with patch.object(s.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout=b"", stderr=b"private diagnostic")):
            with self.assertRaisesRegex(s.StagingError, "xcrun notarytool submit") as caught:
                s.native_run(["/usr/bin/xcrun", "notarytool", "submit", "archive", "--keychain-profile", "private-profile"], self.root)
        self.assertNotIn("private", str(caught.exception))

    def test_dirty_source(self):
        self.fake.dirty = True
        self.refused()
        self.assertEqual(len(self.fake.calls), 1)

    def test_missing_and_wrong_identity(self):
        for identity in ("", self.fake.identities.replace(FINGERPRINT, "F" * 40),
                         self.fake.identities.replace(TEAM, "OTHERTEAM1"),
                         self.fake.identities.replace("Developer ID Application: Example", "VCMC Cerner Agent Developer")):
            self.fake.identities = identity
            self.refused()
        self.assertFalse(any(tool == "swift" for tool, _ in self.fake.calls))

    def test_metadata_drift(self):
        path = self.root / "Resources" / s.DAEMON_PLIST
        path.write_bytes(plistlib.dumps({"Label": "wrong"}))
        self.refused()

    def test_existing_destination_preserved(self):
        path = self.root / "dist/signed-staging/candidate"
        path.mkdir(parents=True)
        (path / "preserve").write_text("original")
        with self.assertRaises(s.StagingError):
            self.stage()
        self.assertEqual((path / "preserve").read_text(), "original")
        self.assertFalse(any(tool == "swift" for tool, _ in self.fake.calls))

    def test_output_symlink_refused(self):
        (self.root / "dist").symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(s.StagingError):
            self.stage()
        self.assertFalse((self.root / "signed-staging").exists())

    def test_bad_signature_metadata(self):
        for mutation in ((TEAM, "OTHERTEAM1"), (s.APP_ID, "wrong"), ("(runtime)", "(none)"),
                         ("Timestamp=Oct 12, 2026 at 12:00:00", "Timestamp=none"),
                         ("Timestamp=", "Signed Time=")):
            with self.subTest(mutation=mutation):
                self.fake.bad_metadata = mutation
                self.refused()
        self.fake.bad_metadata = None
        self.fake.entitlements = {"com.apple.security.get-task-allow": True}
        self.refused()

    def test_notary_rejections(self):
        for receipt in ({"id": SUBMISSION, "status": "Invalid"}, {}, [],
                        {"id": "bad", "status": "Accepted"}, {"id": 1, "status": "Accepted"}):
            with self.subTest(receipt=receipt):
                self.fake.receipt = receipt
                self.refused()

    def test_source_change_discards_candidate(self):
        self.fake.changed = True
        self.refused()

    def test_publish_race_preserves_winner(self):
        self.fake.race = True
        with self.assertRaises(FileExistsError):
            self.stage()
        path = self.root / "dist/signed-staging/candidate"
        self.assertEqual((path / "preserve").read_text(), "race winner")
        self.assertEqual(list(path.parent.iterdir()), [path])

    def test_publication_filesystem_failure_cleans_owned_destination(self):
        with patch.object(Path, "rename", side_effect=OSError("Injected publication failure")):
            self.refused()
        self.assertTrue(Path(self.stage()["candidate"]).is_dir())

    def test_success_order_and_manifest(self):
        result = self.stage()
        artifact = Path(result["candidate"])
        manifest = json.loads((artifact / "manifest.json").read_text())
        self.assertEqual(manifest["source"], HEAD)
        self.assertEqual(manifest["notarization"], {"id": SUBMISSION, "status": "Accepted"})
        self.assertEqual(len(manifest["sha256"]), 3)
        self.assertNotIn("existing-profile", json.dumps(manifest))
        calls = self.fake.calls
        signatures = [args for tool, args in calls if tool == "codesign" and "--sign" in args]
        self.assertEqual(len(signatures), 2)
        self.assertTrue(signatures[0][-1].endswith("PaneAlwaysOn"))
        self.assertTrue(signatures[1][-1].endswith("Pane Management.app"))
        for args in signatures:
            self.assertIn("--timestamp", args)
            self.assertIn("runtime", args)
            self.assertNotIn("--deep", args)
        requirements = [args[args.index("-R") + 1] for tool, args in calls if tool == "codesign" and "-R" in args]
        self.assertEqual(len(requirements), 4)
        for requirement in requirements:
            self.assertTrue(requirement.startswith("=anchor apple generic"))
            for expected in ("1.2.840.113635.100.6.2.6", "1.2.840.113635.100.6.1.13", TEAM):
                self.assertIn(expected, requirement)
        self.assertEqual(len([1 for tool, _ in calls if tool == "ditto"]), 2)
        self.assertEqual(len(list(artifact.parent.parent.iterdir())), 1)

    def test_failure_at_every_command_leaves_retry_available(self):
        self.stage()
        count = len(self.fake.calls)
        self.assertGreater(count, 30)
        import shutil
        shutil.rmtree(self.root / "dist")
        for failure in range(1, count + 1):
            with self.subTest(command=failure):
                self.fake.calls = []
                self.fake.fail_at = failure
                self.refused()
        self.fake.fail_at = None
        self.fake.calls = []
        self.assertTrue(Path(self.stage()["candidate"]).is_dir())


if __name__ == "__main__":
    unittest.main(verbosity=2)
