#!/usr/bin/env python3
"""Isolated Developer ID staging. Importable ports let checks stay entirely inert."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

APP_ID = "local.snapbridge.app"
HELPER_ID = "local.snapbridge.alwayson.service"
DAEMON_PLIST = HELPER_ID + ".plist"
TOOLS = {name: "/usr/bin/" + name for name in
         ("git", "swift", "security", "codesign", "iconutil", "ditto", "xcrun")}
TOOLS["spctl"] = "/usr/sbin/spctl"


class StagingError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise StagingError(message)


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--preflight", action="store_true")
    for name in ("identity", "team-id", "notary-profile"):
        parser.add_argument("--" + name)
    # argparse otherwise accepts the last duplicate silently.
    keys = [arg.split("=", 1)[0] for arg in argv if arg.startswith("--")]
    require(len(keys) == len(set(keys)), "Duplicate arguments are not accepted.")
    args = parser.parse_args(argv)
    if args.preflight:
        require(not any((args.identity, args.team_id, args.notary_profile)),
                "Preflight accepts no signing options.")
    else:
        require(bool(args.identity and re.fullmatch(r"[0-9A-Fa-f]{40}", args.identity)),
                "Supply an explicit forty-hex Developer ID certificate fingerprint.")
        require(bool(args.team_id and re.fullmatch(r"[A-Z0-9]{10}", args.team_id)),
                "Supply the ten-character Team ID.")
        require(bool(args.notary_profile and len(args.notary_profile) <= 200
                     and not args.notary_profile.startswith("-")
                     and all(32 <= ord(c) < 127 for c in args.notary_profile)),
                "Supply an existing Keychain notary profile name.")
        args.identity = args.identity.upper()
    return args


def native_run(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, check=False)
    operation = Path(command[0]).name
    # Only fixed operation words; never print profile names or raw service output.
    if operation == "xcrun":
        operation += " " + " ".join(command[1:3])
    elif operation in ("codesign", "git", "swift"):
        operation += " " + command[1]
    require(result.returncode == 0,
            "Command failed at " + operation + ". Correct that prerequisite and retry; no candidate was published.")
    return result.stdout, result.stderr


class Staging:
    def __init__(self, root, run=native_run, candidate_name=None):
        self.root = Path(root).resolve()
        self.run = run
        self.candidate_name = candidate_name

    def call(self, tool, *args):
        return self.run([TOOLS[tool], *map(str, args)], self.root)

    def source(self):
        require(not self.call("git", "status", "--porcelain", "--untracked-files=all")[0].strip(),
                "Source is dirty. Commit or isolate the intended changes, then retry.")
        head = self.call("git", "rev-parse", "HEAD")[0].decode().strip()
        require(bool(re.fullmatch(r"[0-9a-f]{40}", head)), "Invalid source commit.")
        return head

    def layout(self):
        resources = self.root / "Resources"
        info = plistlib.loads((resources / "Info.plist").read_bytes())
        daemon = plistlib.loads((resources / DAEMON_PLIST).read_bytes())
        require(info.get("CFBundleIdentifier") == APP_ID
                and info.get("CFBundleExecutable") == "PaneManagement"
                and info.get("CFBundlePackageType") == "APPL"
                and info.get("LSUIElement") is False, "App metadata drift; repair source before retrying.")
        require(daemon == {"Label": HELPER_ID, "BundleProgram": "Contents/MacOS/PaneAlwaysOn",
                           "MachServices": {HELPER_ID: True}, "RunAtLoad": True,
                           "KeepAlive": True, "ProcessType": "Background"},
                "Helper metadata drift; repair source before retrying.")
        for path in (resources / "Info.plist", resources / DAEMON_PLIST,
                     self.root / "Icons/AppIcon.iconset",
                     self.root / "Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf"):
            require(path.exists() and not path.is_symlink(), "Missing or linked packaging asset.")

    def preflight(self):
        head = self.source()
        self.layout()
        for tool in TOOLS:
            require(Path(TOOLS[tool]).is_file(), "Missing required tool: " + tool)
        for tool in ("swift", "notarytool", "stapler"):
            require(self.call("xcrun", "--find", tool)[0].strip(), "Missing developer tool: " + tool)
        return head

    def identity(self, args):
        listing = self.call("security", "find-identity", "-v", "-p", "codesigning")[0].decode()
        matches = re.findall(r'^\s*\d+\)\s+([A-Fa-f0-9]{40})\s+"([^"\n]+)"\s*$', listing, re.M)
        require(any(fingerprint.upper() == args.identity
                    and label.startswith("Developer ID Application: ")
                    and label.endswith(" (" + args.team_id + ")")
                    for fingerprint, label in matches),
                "The selected Developer ID Application identity and team are unavailable. Obtain that identity, then retry.")

    def verify(self, target, identifier, team, deep=False):
        requirement = ('=anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists '
                       'and certificate leaf[field.1.2.840.113635.100.6.1.13] exists '
                       f'and certificate leaf[subject.OU] = "{team}" and identifier "{identifier}"')
        self.call("codesign", "--verify", "--strict", *(["--deep"] if deep else []),
                  "-R", requirement, target)
        out, err = self.call("codesign", "--display", "--verbose=4", target)
        metadata = (out + err).decode()
        fields = dict(re.findall(r"^([A-Za-z]+)=(.*)$", metadata, re.M))
        require(fields.get("Identifier") == identifier and fields.get("TeamIdentifier") == team,
                "Signature identifier/team mismatch; repair signing configuration and retry.")
        require(bool(re.search(r"^CodeDirectory .*flags=0x[0-9a-fA-F]+\([^\n)]*\bruntime\b", metadata, re.M)),
                "Hardened runtime is missing.")
        require(bool(fields.get("Timestamp")) and fields["Timestamp"].lower() not in ("none", "not set"),
                "Secure signing timestamp is missing.")
        entitlements, _ = self.call("codesign", "--display", "--entitlements", "-", "--xml", target)
        if entitlements.strip():
            values = plistlib.loads(entitlements)
            require(isinstance(values, dict) and not values.get("com.apple.security.get-task-allow", False),
                    "Debugging entitlement is forbidden.")

    def stage(self, args):
        head = self.preflight()
        if args.preflight:
            return {"preflight": "passed", "source": head, "signed": False}
        self.identity(args)
        # Reject linked output ancestors; this path is exclusively for new candidates.
        parent = self.root
        for component in ("dist", "signed-staging"):
            parent = parent / component
            require(not parent.is_symlink(), "Staging output must not be a symlink.")
            parent.mkdir(mode=0o700, exist_ok=True)
            require(parent.is_dir(), "Staging output is not a directory.")
        name = self.candidate_name or (head + "-" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + str(uuid.uuid4()))
        require(bool(re.fullmatch(r"[A-Za-z0-9-]+", name)), "Invalid candidate name.")
        destination = parent / name
        require(not destination.exists() and not destination.is_symlink(), "Candidate already exists; no output was replaced.")
        owned_destination = False
        try:
            with tempfile.TemporaryDirectory(prefix=".partial-", dir=parent) as temporary:
                partial = Path(temporary)
                payload = partial / "payload"
                payload.mkdir(mode=0o700)
                scratch = partial / "swift-build"
                self.call("swift", "build", "-c", "release", "--scratch-path", scratch)
                bin_dir = Path(self.call("swift", "build", "-c", "release", "--scratch-path", scratch,
                                         "--show-bin-path")[0].decode().strip())
                require(bin_dir.resolve().is_relative_to(scratch.resolve()) and bin_dir.is_dir(), "Unexpected build output path.")
                app = payload / "Pane Management.app"
                contents = app / "Contents"
                for directory in ("MacOS", "Resources", "Library/LaunchDaemons"):
                    (contents / directory).mkdir(parents=True)
                for executable in ("PaneManagement", "PaneAlwaysOn"):
                    shutil.copy2(bin_dir / executable, contents / "MacOS" / executable)
                shutil.copy2(self.root / "Resources/Info.plist", contents / "Info.plist")
                shutil.copy2(self.root / "Resources" / DAEMON_PLIST, contents / "Library/LaunchDaemons" / DAEMON_PLIST)
                self.call("iconutil", "--convert", "icns", "--output", contents / "Resources/AppIcon.icns",
                          self.root / "Icons/AppIcon.iconset")
                shutil.copy2(self.root / "Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf",
                             contents / "Resources/MenuBarIconTemplate.pdf")
                helper = contents / "MacOS/PaneAlwaysOn"
                for target, identifier in ((helper, HELPER_ID), (app, APP_ID)):
                    self.call("codesign", "--force", "--sign", args.identity, "--identifier", identifier,
                              "--options", "runtime", "--timestamp", target)
                for target, identifier in ((helper, HELPER_ID), (app, APP_ID)):
                    self.verify(target, identifier, args.team_id, deep=target == app)
                submission = partial / "submission.zip"
                self.call("ditto", "-c", "-k", "--keepParent", app, submission)
                response = self.call("xcrun", "notarytool", "submit", submission, "--keychain-profile",
                                     args.notary_profile, "--wait", "--output-format", "json")[0]
                receipt = json.loads(response)
                submission_id = receipt.get("id") if isinstance(receipt, dict) else None
                require(isinstance(receipt, dict) and receipt.get("status") == "Accepted" and isinstance(submission_id, str)
                        and str(uuid.UUID(submission_id)) == submission_id,
                        "Notarization was not accepted. Resolve the submission result and retry; nothing was published.")
                self.call("xcrun", "stapler", "staple", app)
                self.call("xcrun", "stapler", "validate", app)
                for target, identifier in ((helper, HELPER_ID), (app, APP_ID)):
                    self.verify(target, identifier, args.team_id, deep=target == app)
                self.call("spctl", "--assess", "--type", "execute", app)
                archive = payload / "Pane Management.zip"
                self.call("ditto", "-c", "-k", "--keepParent", app, archive)
                require(self.source() == head, "Source changed during staging; commit/isolate changes and retry.")
                manifest = {"source": head, "appIdentifier": APP_ID, "helperIdentifier": HELPER_ID,
                            "teamIdentifier": args.team_id, "certificateFingerprint": args.identity,
                            "notarization": {"id": submission_id, "status": "Accepted"},
                            "verification": ["Developer ID requirements", "hardened runtime", "secure timestamp",
                                             "no debugging entitlement", "stapled ticket", "Gatekeeper assessment"],
                            "sha256": {str(path.relative_to(payload)): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in (archive, contents / "MacOS/PaneManagement", helper)}}
                (payload / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
                # Exclusive mkdir reserves publication only AFTER every gate. Never overwrite a race winner.
                destination.mkdir(mode=0o700)
                owned_destination = True
                payload.rename(destination / "artifacts")
            return {"candidate": str(destination / "artifacts"), "source": head, "signed": True}
        except BaseException:
            if owned_destination:
                shutil.rmtree(destination)
            raise


def main(argv=None):
    try:
        args = arguments(sys.argv[1:] if argv is None else argv)
        result = Staging(Path(__file__).resolve().parent.parent).stage(args)
        print(json.dumps(result, indent=2))
        return 0
    except (StagingError, OSError, ValueError, plistlib.InvalidFileException) as error:
        print("Staging stopped: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
