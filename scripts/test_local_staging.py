#!/usr/bin/env python3
"""Synthetic local production packaging; native subprocess fallback is forbidden."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch
import signed_staging as base
import local_staging as s

PIN, HEAD = "A" * 40, "b" * 40


class Commands:
    def __init__(self, root):
        self.root, self.calls, self.fail_at = root, [], None
        self.dirty = self.changed = self.missing = self.race = self.outside = self.linked_binary = False
        self.untrusted = False
        self.bad_target = self.bad_kind = None
        self.signed = {}

    def __call__(self, command, cwd):
        assert cwd == self.root
        tool, args = Path(command[0]).name, command[1:]
        self.calls.append((tool, args))
        if len(self.calls) == self.fail_at:
            raise s.StagingError("synthetic command failure")
        if tool == "git":
            if args[0] == "status": return (b"dirty" if self.dirty else b""), b""
            if len(self.calls) > 10 and self.race:
                destination = self.root / "dist/local-signed-staging/candidate"
                destination.mkdir(); (destination / "preserve").write_text("winner")
            return (("c" * 40 if self.changed and len(self.calls) > 10 else HEAD).encode(), b"")
        if tool == "xcrun" and args == ["--find", "swift"]: return b"/synthetic/swift", b""
        if tool == "security":
            assert args == ["find-identity", "-p", "codesigning"]
            suffix = " (CSSMERR_TP_NOT_TRUSTED)" if self.untrusted else ""
            return (b"" if self.missing else f' 1) {PIN} "Dedicated Fixture"{suffix}\n'.encode()), b""
        if tool == "swift":
            output = (self.root / "outside") if self.outside else Path(args[args.index("--scratch-path") + 1]) / "release"
            output.mkdir(parents=True, exist_ok=True)
            for binary in ("PaneManagement", "PaneAlwaysOn", "SigningProbeDaemon", "SigningProbeNegative", "AlwaysOnChecks"):
                p = output / binary
                if not p.exists(): p.write_bytes(binary.encode())
            if self.linked_binary and not (output / "PaneAlwaysOn").is_symlink():
                (output / "PaneAlwaysOn").unlink(); (output / "PaneAlwaysOn").symlink_to(output / "SigningProbeDaemon")
            return str(output).encode(), b""
        if tool == "iconutil":
            Path(args[args.index("--output") + 1]).write_bytes(b"icon")
            return b"", b""
        if tool == "codesign":
            target = Path(args[-1]); identifier = s.HELPER_ID if target.name == "PaneAlwaysOn" else s.APP_ID
            damaged = target.name == self.bad_target
            if "--sign" in args:
                self.signed[str(target)] = (args[args.index("--sign") + 1], args[args.index("--identifier") + 1])
            elif "--verify" in args:
                expected = f'=identifier "{identifier}" and certificate leaf = H"{PIN}"'
                assert args[args.index("-R") + 1] == expected
                assert self.signed[str(target)] == (PIN, identifier)
                if damaged and self.bad_kind == "pin": raise s.StagingError("certificate mismatch")
            elif "--entitlements" in args:
                return plistlib.dumps({"com.apple.security.cs.disable-library-validation": True} if damaged and self.bad_kind == "entitlement" else {}), b""
            elif "--display" in args:
                if damaged and self.bad_kind == "id": identifier = "wrong.identifier"
                runtime = "none" if damaged and self.bad_kind == "runtime" else "runtime"
                return b"", f"Identifier={identifier}\nCodeDirectory v=20500 flags=0x10000({runtime}) hashes=1\n".encode()
            else: raise AssertionError("Unknown codesign action")
            assert not (self.root / "dist/local-signed-staging/candidate").exists()
            return b"", b""
        raise AssertionError("Unexpected command: " + repr(command))


class Checks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        original = Path(__file__).resolve().parent.parent
        for name in ("Info.plist", s.DAEMON_PLIST):
            target = self.root / "Resources" / name; target.parent.mkdir(exist_ok=True)
            target.write_bytes((original / "Resources" / name).read_bytes())
        (self.root / "Icons/AppIcon.iconset").mkdir(parents=True)
        (self.root / "Icons/AppIcon.iconset/icon.png").write_bytes(b"icon")
        glyph = self.root / "Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf"
        glyph.parent.mkdir(parents=True); glyph.write_bytes(b"glyph")
        self.fake = Commands(self.root)
        self.subject = s.LocalStaging(self.root, run=self.fake, candidate_name="candidate")
        guard = patch.object(base.subprocess, "run", side_effect=AssertionError("Native commands forbidden"))
        guard.start(); self.addCleanup(guard.stop)

    def stage(self): return self.subject.stage(s.arguments(["--identity", PIN]))

    def refused(self):
        with self.assertRaises((s.StagingError, OSError, ValueError)): self.stage()
        directory = self.root / "dist/local-signed-staging"
        self.assertFalse(directory.exists() and list(directory.iterdir()))

    def test_arguments(self):
        for args in ([], ["--identity", "-"], ["--identity", "a" * 39], ["--identity", "z" * 40],
                     ["--preflight", "--identity", PIN], ["--preflight", "--preflight"],
                     ["--identity", PIN, "--identity", PIN], ["--iden", PIN], ["--team-id", "TEAM"]):
            with self.subTest(args=args), contextlib.redirect_stderr(io.StringIO()), self.assertRaises((s.StagingError, SystemExit)):
                s.arguments(args)
        self.assertEqual(s.arguments(["--identity", PIN.lower()]).identity, PIN)

    def test_help_names_production(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as result:
            s.arguments(["--help"])
        self.assertEqual(result.exception.code, 0)
        self.assertIn("production candidate", output.getvalue())
        self.assertNotIn("harmless", output.getvalue())

    def test_preflight_inert(self):
        result = self.subject.stage(s.arguments(["--preflight"]))
        self.assertFalse(result["signed"])
        self.assertEqual([t for t, _ in self.fake.calls], ["git", "git", "xcrun"])
        self.assertFalse((self.root / "dist").exists())

    def test_success_only_production_and_manifest(self):
        result = self.stage(); artifacts = Path(result["candidate"])
        self.assertEqual(set(p.name for p in artifacts.iterdir()), {"Pane Management.app", "manifest.json"})
        contents = artifacts / "Pane Management.app/Contents"
        self.assertEqual(set(str(p.relative_to(contents)) for p in contents.rglob("*") if p.is_file()), {
            "MacOS/PaneManagement", "MacOS/PaneAlwaysOn", "Info.plist", "Library/LaunchDaemons/" + s.DAEMON_PLIST,
            "Resources/AppIcon.icns", "Resources/MenuBarIconTemplate.pdf"})
        self.assertFalse(plistlib.loads((contents / "Info.plist").read_bytes())["LSUIElement"])
        self.assertEqual((contents / "Resources/MenuBarIconTemplate.pdf").read_bytes(), b"glyph")
        signed = [a for t, a in self.fake.calls if t == "codesign" and "--sign" in a]
        self.assertEqual(len(signed), 2)
        self.assertTrue(signed[0][-1].endswith("PaneAlwaysOn")); self.assertTrue(signed[1][-1].endswith("Pane Management.app"))
        self.assertTrue(all("--timestamp=none" in a and "runtime" in a and a[a.index("--sign") + 1] == PIN for a in signed))
        self.assertEqual(sum(t == "codesign" and "-R" in a for t, a in self.fake.calls), 2)
        self.assertEqual(set(t for t, _ in self.fake.calls), {"git", "xcrun", "swift", "security", "codesign", "iconutil"})
        manifest = json.loads((artifacts / "manifest.json").read_text())
        self.assertEqual(manifest["source"], HEAD); self.assertEqual(manifest["certificateFingerprint"], PIN)
        self.assertEqual(manifest["appIdentifier"], s.APP_ID); self.assertEqual(manifest["helperIdentifier"], s.HELPER_ID)
        self.assertEqual(len(manifest["sha256"]), 2)
        for p, digest in manifest["sha256"].items(): self.assertEqual(digest, hashlib.sha256((artifacts / p).read_bytes()).hexdigest())
        self.assertNotIn("notarization", manifest)

    def test_untrusted_explicit_identity(self):
        self.fake.untrusted = True; self.assertTrue(self.stage()["signed"])

    def test_nonmatching_certificate_refused(self):
        with self.assertRaises(s.StagingError): self.subject.stage(s.arguments(["--identity", "B" * 40]))
        self.assertFalse((self.root / "dist").exists())

    def test_command_failures_cleanup_and_retry(self):
        self.stage(); count = len(self.fake.calls); shutil.rmtree(self.root / "dist")
        self.assertEqual(count, 17)
        for position in range(1, count + 1):
            with self.subTest(command=position):
                self.fake.calls = []; self.fake.fail_at = position; self.refused()
                self.fake.calls = []; self.fake.fail_at = None; self.stage(); shutil.rmtree(self.root / "dist")

    def test_bad_prerequisites(self):
        for attribute in ("dirty", "changed", "missing", "outside", "linked_binary"):
            with self.subTest(attribute=attribute):
                setattr(self.fake, attribute, True); self.fake.calls = []; self.refused(); setattr(self.fake, attribute, False)

    def test_both_signature_boundaries(self):
        for target in ("PaneAlwaysOn", "Pane Management.app"):
            for kind in ("pin", "id", "runtime", "entitlement"):
                with self.subTest(target=target, kind=kind):
                    self.fake.bad_target, self.fake.bad_kind = target, kind; self.refused()
        self.fake.bad_target = None; self.stage()

    def test_metadata(self):
        for name, key, value in ((s.DAEMON_PLIST, "Label", "wrong"), ("Info.plist", "LSUIElement", True), ("Info.plist", "CFBundleIconFile", "wrong")):
            p = self.root / "Resources" / name; original = p.read_bytes()
            data = plistlib.loads(original); data[key] = value; p.write_bytes(plistlib.dumps(data))
            self.refused(); p.write_bytes(original)

    def test_linked_paths(self):
        for relative in ("Resources", "Icons", "Icons/AppIcon.iconset/icon.png", "Icons/Assets.xcassets", "dist", "dist/local-signed-staging"):
            with self.subTest(path=relative):
                path = self.root / relative; path.parent.mkdir(parents=True, exist_ok=True)
                outside = self.root / "linked-target"
                existed = path.exists()
                if existed: path.rename(outside)
                else: outside.mkdir()
                path.symlink_to(outside, target_is_directory=outside.is_dir())
                with self.assertRaises(s.StagingError): self.stage()
                path.unlink()
                if existed: outside.rename(path)
                else: self.assertEqual(list(outside.iterdir()), []); outside.rmdir()

    def test_existing_race_invalid_destination_preserved(self):
        output = self.root / "dist/local-signed-staging/candidate"
        output.mkdir(parents=True); (output / "preserve").write_text("existing")
        with self.assertRaises(s.StagingError): self.stage()
        self.assertEqual((output / "preserve").read_text(), "existing")
        shutil.rmtree(output); self.fake.race = True
        with self.assertRaises(OSError): self.stage()
        self.assertEqual((output / "preserve").read_text(), "winner")
        self.assertEqual(list(output.parent.iterdir()), [output])
        self.fake.race = False; self.subject.candidate_name = "../escape"
        with self.assertRaises(s.StagingError): self.stage()
        self.assertFalse((output.parent.parent / "escape").exists())

    def test_publication_failure_recoverable(self):
        with patch.object(Path, "rename", side_effect=OSError("publication failure")): self.refused()
        self.stage()


if __name__ == "__main__": unittest.main()
