#!/usr/bin/env python3
"""Build a separately signed, harmless local acceptance probe; never installs it."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import sys
import tempfile
import uuid
from signed_staging import Staging, StagingError, require

APP = "local.snapbridge.signingprobe"
HELPER = APP + ".service"
WRONG = APP + ".negative"
INFO = "SigningProbeInfo.plist"
DAEMON = HELPER + ".plist"


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--identity")
    keys = [a.split("=", 1)[0] for a in argv if a.startswith("--")]
    require(len(keys) == len(set(keys)), "Duplicate options rejected.")
    args = parser.parse_args(argv)
    require((args.preflight and args.identity is None) or
            (not args.preflight and bool(re.fullmatch(r"[A-Fa-f0-9]{40}", args.identity or ""))),
            "Use --preflight alone or an explicit --identity forty-hex certificate fingerprint.")
    if args.identity:
        args.identity = args.identity.upper()
    return args


class ProbeStaging(Staging):
    def preflight(self):
        head = self.source()
        resources = self.root / "Resources"
        for name in (INFO, DAEMON):
            require(not resources.is_symlink() and not (resources / name).is_symlink(), "Linked probe metadata rejected.")
        info = plistlib.loads((resources / INFO).read_bytes())
        require(info.get("CFBundleIdentifier") == APP and info.get("CFBundleExecutable") == "SigningProbeApp"
                and info.get("CFBundlePackageType") == "APPL" and info.get("LSUIElement") is False,
                "Probe app metadata drift.")
        require(plistlib.loads((resources / DAEMON).read_bytes()) == {
            "Label": HELPER, "BundleProgram": "Contents/MacOS/SigningProbeDaemon",
            "MachServices": {HELPER: True}, "RunAtLoad": True, "ProcessType": "Background"}, "Probe daemon metadata drift.")
        for tool in ("git", "swift", "security", "codesign"):
            require(Path("/usr/bin/" + tool).is_file(), "Missing probe tool: " + tool)
        require(self.call("xcrun", "--find", "swift")[0].strip(), "Swift unavailable.")
        return head

    def verify_probe(self, target, identifier, pin):
        requirement = f'=identifier "{identifier}" and certificate leaf = H"{pin}"'
        self.call("codesign", "--verify", "--deep", "--strict", *(["-R", requirement] if pin else []), target)
        out, err = self.call("codesign", "--display", "--verbose=4", target)
        text = (out + err).decode()
        require(re.search(r"^Identifier=" + re.escape(identifier) + r"$", text, re.M)
                and re.search(r"^CodeDirectory .*flags=0x[0-9a-fA-F]+\([^\n)]*\bruntime\b", text, re.M),
                "Probe identifier or hardened runtime verification failed.")
        require(pin is not None or re.search(r"^Signature=adhoc$", text, re.M), "Negative fixture must be ad-hoc signed.")
        entitlements, _ = self.call("codesign", "--display", "--entitlements", "-", "--xml", target)
        require(not entitlements.strip() or plistlib.loads(entitlements) == {}, "Probe must have no entitlements.")

    def stage(self, args):
        head = self.preflight()
        if args.preflight:
            return {"source": head, "preflight": "passed", "signed": False}
        listing = self.call("security", "find-identity", "-p", "codesigning")[0].decode()
        require(args.identity in [p.upper() for p in re.findall(r'^\s*\d+\)\s+([a-fA-F0-9]{40})\s+"[^"\n]+"(?:\s+\([^\)\n]*\))?\s*$', listing, re.M)],
                "Selected identity unavailable. Create the dedicated certificate only after approval, then retry.")
        parent = self.root
        for component in ("dist", "signing-probe"):
            parent = parent / component
            require(not parent.is_symlink(), "Linked output rejected.")
            parent.mkdir(mode=0o700, exist_ok=True)
        name = self.candidate_name or head + "-" + str(uuid.uuid4())
        require(bool(re.fullmatch(r"[A-Za-z0-9-]+", name)), "Invalid candidate name.")
        destination = parent / name
        require(not destination.exists() and not destination.is_symlink(), "Candidate already exists; preserved.")
        owned = False
        try:
            with tempfile.TemporaryDirectory(prefix=".partial-", dir=parent) as temporary:
                temporary = Path(temporary); payload = temporary / "payload"; payload.mkdir(mode=0o700)
                scratch = temporary / "build"
                self.call("swift", "build", "-c", "release", "--scratch-path", scratch)
                binaries = Path(self.call("swift", "build", "-c", "release", "--scratch-path", scratch, "--show-bin-path")[0].decode().strip())
                require(binaries.resolve().is_relative_to(scratch.resolve()) and binaries.is_dir(), "Unexpected probe build path.")
                app = payload / "Local Signing Probe.app"; contents = app / "Contents"
                (contents / "MacOS").mkdir(parents=True)
                (contents / "Library/LaunchDaemons").mkdir(parents=True)
                for executable in ("SigningProbeApp", "SigningProbeDaemon"):
                    shutil.copy2(binaries / executable, contents / "MacOS" / executable)
                shutil.copy2(self.root / "Resources" / INFO, contents / "Info.plist")
                shutil.copy2(self.root / "Resources" / DAEMON, contents / "Library/LaunchDaemons" / DAEMON)
                helper = contents / "MacOS/SigningProbeDaemon"
                targets = [(helper, HELPER), (app, APP)]
                for name, identifier in (("wrong-id", WRONG), ("wrong-pin", APP), ("ad-hoc", APP)):
                    path = payload / name
                    shutil.copy2(binaries / "SigningProbeNegative", path)
                    if name != "ad-hoc":
                        targets.append((path, identifier))
                    else:
                        self.call("codesign", "--force", "--sign", "-", "--identifier", APP, "--options", "runtime", "--timestamp=none", path)
                        self.verify_probe(path, APP, None)
                for target, identifier in targets:
                    self.call("codesign", "--force", "--sign", args.identity, "--identifier", identifier,
                              "--options", "runtime", "--timestamp=none", target)
                    self.verify_probe(target, identifier, args.identity)
                require(self.source() == head, "Source changed during staging; retry from committed source.")
                hashed = [contents / "MacOS/SigningProbeApp", helper, *(payload / n for n in ("wrong-id", "wrong-pin", "ad-hoc"))]
                manifest = {"source": head, "certificateFingerprint": args.identity,
                            "sha256": {str(p.relative_to(payload)): hashlib.sha256(p.read_bytes()).hexdigest() for p in hashed}}
                (payload / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
                destination.mkdir(mode=0o700); owned = True
                payload.rename(destination / "artifacts")
            return {"candidate": str(destination / "artifacts"), "source": head, "signed": True}
        except BaseException:
            if owned:
                shutil.rmtree(destination)
            raise


if __name__ == "__main__":
    try:
        print(json.dumps(ProbeStaging(Path(__file__).resolve().parent.parent).stage(arguments(sys.argv[1:])), indent=2))
    except (StagingError, OSError, ValueError, plistlib.InvalidFileException) as error:
        print("Probe staging stopped: " + str(error), file=sys.stderr)
        sys.exit(1)
