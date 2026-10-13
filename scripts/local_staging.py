#!/usr/bin/env python3
"""Stage a locally signed production candidate; never install or start it."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import sys
import tempfile
import uuid
from signed_staging import APP_ID, HELPER_ID, DAEMON_PLIST, Staging, StagingError, require
from probe_staging import ProbeStaging, arguments as probe_arguments


def arguments(argv):
    return probe_arguments(argv, description=__doc__)


class LocalStaging(ProbeStaging):
    def preflight(self):
        head = self.source()
        # Reject linked ancestors and children before reading/copying artwork.
        for relative in ("Resources", "Icons/AppIcon.iconset",
                         "Icons/Assets.xcassets/MenuBarIconTemplate.imageset"):
            path = self.root
            for component in Path(relative).parts:
                path /= component
                require(path.is_dir() and not path.is_symlink(), "Missing or linked packaging directory; repair source and retry.")
            require(all(not p.is_symlink() for p in path.rglob("*")), "Linked packaging asset; repair source and retry.")
        Staging.layout(self)
        info = plistlib.loads((self.root / "Resources/Info.plist").read_bytes())
        require(info.get("CFBundleIconFile") == "AppIcon", "App icon metadata drift; repair source and retry.")
        for tool in ("git", "swift", "security", "codesign", "iconutil", "xcrun"):
            require(Path("/usr/bin/" + tool).is_file(), "Missing staging tool: " + tool)
        require(self.call("xcrun", "--find", "swift")[0].strip(), "Swift unavailable; repair developer tools and retry.")
        return head

    def stage(self, args):
        head = self.preflight()
        if args.preflight:
            return {"source": head, "preflight": "passed", "signed": False}
        listing = self.call("security", "find-identity", "-p", "codesigning")[0].decode()
        matches = re.findall(r'^\s*\d+\)\s+([a-fA-F0-9]{40})\s+"[^"\n]+"(?:\s+\([^\)\n]*\))?\s*$', listing, re.M)
        require(args.identity in [pin.upper() for pin in matches],
                "Selected local identity/private key unavailable. Make the chosen identity available, then retry.")
        parent = self.root
        for component in ("dist", "local-signed-staging"):
            parent /= component
            require(not parent.is_symlink(), "Linked staging output rejected; use an ordinary directory and retry.")
            parent.mkdir(mode=0o700, exist_ok=True)
        name = self.candidate_name or head + "-" + str(uuid.uuid4())
        require(bool(re.fullmatch(r"[A-Za-z0-9-]+", name)), "Invalid candidate name; retry with a new candidate.")
        destination = parent / name
        require(not destination.exists() and not destination.is_symlink(), "Candidate already exists; preserved. Retry with a new candidate.")
        owned = False
        try:
            with tempfile.TemporaryDirectory(prefix=".partial-", dir=parent) as temporary:
                temporary = Path(temporary); payload = temporary / "payload"; payload.mkdir(mode=0o700)
                scratch = temporary / "build"
                self.call("swift", "build", "-c", "release", "--scratch-path", scratch)
                binaries = Path(self.call("swift", "build", "-c", "release", "--scratch-path", scratch, "--show-bin-path")[0].decode().strip())
                require(binaries.resolve().is_relative_to(scratch.resolve()) and binaries.is_dir(), "Unexpected build path; repair build output and retry.")
                app = payload / "Pane Management.app"; contents = app / "Contents"
                for folder in ("MacOS", "Resources", "Library/LaunchDaemons"):
                    (contents / folder).mkdir(parents=True)
                for executable in ("PaneManagement", "PaneAlwaysOn"):
                    binary = binaries / executable
                    require(binary.is_file() and not binary.is_symlink(), "Missing or linked production binary; repair build output and retry.")
                    shutil.copy2(binary, contents / "MacOS" / executable)
                shutil.copy2(self.root / "Resources/Info.plist", contents / "Info.plist")
                shutil.copy2(self.root / "Resources" / DAEMON_PLIST, contents / "Library/LaunchDaemons" / DAEMON_PLIST)
                self.call("iconutil", "--convert", "icns", "--output", contents / "Resources/AppIcon.icns", self.root / "Icons/AppIcon.iconset")
                shutil.copy2(self.root / "Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf", contents / "Resources/MenuBarIconTemplate.pdf")
                helper = contents / "MacOS/PaneAlwaysOn"
                for target, identifier in ((helper, HELPER_ID), (app, APP_ID)):
                    self.call("codesign", "--force", "--sign", args.identity, "--identifier", identifier, "--options", "runtime", "--timestamp=none", target)
                for target, identifier in ((helper, HELPER_ID), (app, APP_ID)):
                    self.verify_probe(target, identifier, args.identity, label="Production candidate")
                require(self.source() == head, "Source changed during staging; commit intended source and retry.")
                manifest = {"source": head, "certificateFingerprint": args.identity,
                            "appIdentifier": APP_ID, "helperIdentifier": HELPER_ID,
                            "verification": ["exact leaf certificate and fixed identifiers", "hardened runtime", "no entitlements"],
                            "sha256": {str(p.relative_to(payload)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (contents / "MacOS/PaneManagement", helper)}}
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
        print(json.dumps(LocalStaging(Path(__file__).resolve().parent.parent).stage(arguments(sys.argv[1:])), indent=2))
    except (StagingError, OSError, ValueError, plistlib.InvalidFileException) as error:
        print("Local staging stopped: " + str(error), file=sys.stderr)
        sys.exit(1)
