#!/usr/bin/env python3
"""All commands injected; tests cannot fall through to signing or service work."""
import contextlib
import io
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import signed_staging as base
import probe_staging as s

PIN, HEAD = "A" * 40, "b" * 40


class Commands:
    def __init__(self, root):
        self.root, self.calls, self.fail_at = root, [], None
        self.dirty, self.changed, self.missing, self.bad, self.entitlements = False, False, False, False, {}
        self.race = False
        self.untrusted = False

    def __call__(self, command, cwd):
        assert cwd == self.root
        tool, args = Path(command[0]).name, command[1:]
        self.calls.append((tool, args))
        if len(self.calls) == self.fail_at:
            raise s.StagingError("synthetic failure")
        if tool == "git":
            if args[0] == "status":
                return (b"dirty" if self.dirty else b""), b""
            if len(self.calls) > 10 and self.race:
                destination = self.root / "dist/signing-probe/candidate"
                destination.mkdir(); (destination / "preserve").write_text("winner")
            return (("c" * 40 if self.changed and len(self.calls) > 10 else HEAD).encode(), b"")
        if tool == "xcrun" and args == ["--find", "swift"]:
            return b"/synthetic/swift", b""
        if tool == "security" and args in (["find-identity", "-v", "-p", "codesigning"], ["find-identity", "-p", "codesigning"]):
            suffix = " (CSSMERR_TP_NOT_TRUSTED)" if self.untrusted else ""
            return (b"" if self.missing else f' 1) {PIN} "Dedicated Fixture"{suffix}\n'.encode()), b""
        if tool == "swift":
            output = Path(args[args.index("--scratch-path") + 1]) / "release"
            output.mkdir(parents=True, exist_ok=True)
            for binary in ("SigningProbeApp", "SigningProbeDaemon", "SigningProbeNegative"):
                (output / binary).write_bytes(b"fixture")
            return str(output).encode(), b""
        if tool == "codesign":
            if "--entitlements" in args:
                return plistlib.dumps(self.entitlements), b""
            if "--display" in args:
                name = Path(args[-1]).name
                identifier = s.HELPER if name == "SigningProbeDaemon" else s.WRONG if name == "wrong-id" else s.APP
                metadata = f"Identifier={identifier}\nCodeDirectory v=20500 flags=0x10000(runtime) hashes=1\n"
                if name == "ad-hoc": metadata += "Signature=adhoc\n"
                return b"", ("bad" if self.bad else metadata).encode()
            assert not (self.root / "dist/signing-probe/candidate").exists()
            return b"", b""
        raise AssertionError("Unexpected command: " + repr(command))


class Checks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve(); resources = self.root / "Resources"; resources.mkdir()
        for name in (s.INFO, s.DAEMON):
            (resources / name).write_bytes((Path(__file__).resolve().parent.parent / "Resources" / name).read_bytes())
        self.fake = Commands(self.root)
        self.subject = s.ProbeStaging(self.root, run=self.fake, candidate_name="candidate")
        guard = patch.object(base.subprocess, "run", side_effect=AssertionError("Native commands forbidden"))
        guard.start(); self.addCleanup(guard.stop)

    def stage(self):
        return self.subject.stage(s.arguments(["--identity", PIN]))

    def refused(self):
        with self.assertRaises((s.StagingError, OSError, ValueError)):
            self.stage()
        directory = self.root / "dist/signing-probe"
        self.assertFalse(directory.exists() and list(directory.iterdir()))

    def test_arguments(self):
        for args in ([], ["--identity", "-"], ["--identity", "a" * 39], ["--identity", "z" * 40],
                     ["--preflight", "--identity", PIN], ["--preflight", "--preflight"],
                     ["--identity", PIN, "--identity", PIN], ["--iden", PIN]):
            with self.subTest(args=args), contextlib.redirect_stderr(io.StringIO()), self.assertRaises((s.StagingError, SystemExit)):
                s.arguments(args)

    def test_preflight_inert(self):
        result = self.subject.stage(s.arguments(["--preflight"]))
        self.assertFalse(result["signed"])
        self.assertEqual([t for t, _ in self.fake.calls], ["git", "git", "xcrun"])
        self.assertFalse((self.root / "dist").exists())

    def test_success_order_and_manifest(self):
        result = self.stage(); artifacts = Path(result["candidate"])
        self.assertEqual(set(p.name for p in artifacts.iterdir()), {"Local Signing Probe.app", "wrong-id", "wrong-pin", "ad-hoc", "manifest.json"})
        calls = self.fake.calls
        signed = [a for t, a in calls if t == "codesign" and "--sign" in a]
        certificate_signed = [a for a in signed if a[a.index("--sign") + 1] != "-"]
        self.assertTrue(certificate_signed[0][-1].endswith("SigningProbeDaemon"))
        self.assertTrue(certificate_signed[1][-1].endswith("Local Signing Probe.app"))
        self.assertTrue(all("--timestamp=none" in a and "runtime" in a for a in signed))
        required = [a[a.index("-R") + 1] for t, a in calls if t == "codesign" and "-R" in a]
        self.assertEqual(len(required), 4)
        self.assertTrue(all(PIN in value for value in required))
        self.assertTrue(any(s.WRONG in value for value in required))
        self.assertEqual(set(t for t, _ in calls), {"git", "xcrun", "swift", "security", "codesign"})
        manifest = json.loads((artifacts / "manifest.json").read_text())
        self.assertEqual(set(manifest), {"source", "certificateFingerprint", "sha256"})
        self.assertEqual(manifest["source"], HEAD); self.assertEqual(len(manifest["sha256"]), 5)

    def test_untrusted_explicit_identity(self):
        self.fake.untrusted = True
        self.assertTrue(self.stage()["signed"])

    def test_nonmatching_certificate_refused(self):
        with self.assertRaises(s.StagingError):
            self.subject.stage(s.arguments(["--identity", "B" * 40]))
        self.assertFalse((self.root / "dist").exists())

    def test_identity_lookup_includes_local_certificates(self):
        self.stage()
        listing = [args for tool, args in self.fake.calls if tool == "security"]
        self.assertEqual(listing, [["find-identity", "-p", "codesigning"]])

    def test_command_failures_cleanup_and_retry(self):
        self.stage(); count = len(self.fake.calls)
        import shutil
        shutil.rmtree(self.root / "dist")
        for position in range(1, count + 1):
            with self.subTest(command=position):
                self.fake.calls = []; self.fake.fail_at = position; self.refused()
                self.fake.calls = []; self.fake.fail_at = None; self.stage()
                shutil.rmtree(self.root / "dist")

    def test_bad_prerequisites(self):
        for attribute in ("dirty", "changed", "missing", "bad"):
            with self.subTest(attribute=attribute):
                setattr(self.fake, attribute, True); self.fake.calls = []; self.refused(); setattr(self.fake, attribute, False)
        for entitlement in ("com.apple.security.get-task-allow", "com.apple.security.cs.disable-library-validation"):
            self.fake.entitlements = {entitlement: True}; self.refused()

    def test_metadata_and_linked_paths(self):
        file = self.root / "Resources" / s.DAEMON
        original = file.read_bytes(); file.write_bytes(plistlib.dumps({"Label": "wrong"})); self.refused(); file.write_bytes(original)
        outside = self.root / "outside"; outside.mkdir(); (self.root / "dist").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(s.StagingError): self.stage()
        self.assertEqual(list(outside.iterdir()), [])

    def test_existing_and_race_output_preserved(self):
        output = self.root / "dist/signing-probe/candidate"
        output.mkdir(parents=True); (output / "preserve").write_text("existing")
        with self.assertRaises(s.StagingError): self.stage()
        self.assertEqual((output / "preserve").read_text(), "existing")
        import shutil
        shutil.rmtree(output); self.fake.race = True
        with self.assertRaises(OSError): self.stage()
        self.assertEqual((output / "preserve").read_text(), "winner")
        self.assertEqual(list(output.parent.iterdir()), [output])

    def test_publication_failure_recoverable(self):
        with patch.object(Path, "rename", side_effect=OSError("publication failure")):
            self.refused()
        self.stage()


if __name__ == "__main__":
    unittest.main()
