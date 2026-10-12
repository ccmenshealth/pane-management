# Dock and closed-lid coding

## Locked user decisions — 2026-10-12

- D1: Pane Management appears in the Dock while running, retaining its menu-bar icon.
- D2: The eventual closed-lid coding switch is available in both the menu-bar menu and the Dock right-click menu, sharing one state.
- D3: When enabled, keep coding running on battery or AC with the lid closed. This specifically supports travel on battery.
- D4: With the lid open, ordinary display, built-in input, and sleep behavior apply. Opening the lid returns to ordinary use; the switch may remain armed for the next closure.
- D5: With the lid closed, the built-in screen and keyboard backlight are dark. Input hardware follows normal macOS lid behavior; no global keyboard/trackpad interception is requested.
- D6: No application-defined battery-percentage or thermal-pressure cutoff. The user explicitly declined both. This does not authorize disabling native emergency protection.
- D7: Off is the default on launch. Turning off or quitting must release changes owned by this feature; crashes and restoration failures need an observable recovery path.
- D8: The user authorized the current Codex model for native builders/reviewers, overriding the older model pin in the gated-build skill. All other gates apply.

## Slices

1. **Dock presence and existing controls** — isolated PR. Make the running app visible in the Dock; keep reopen behavior and expose existing Settings/pause controls in its contextual menu. Do not expose an inoperative coding toggle. Verify native Dock/menu rendering and existing regression suite.
2. **Closed-lid mechanism and controls — blocked on scope decision.** Read-only feasibility review found no caller-owned mechanism satisfying the exact lid-only battery behavior and recovery requirements. A normal idle-sleep assertion does not cover lid closure. The lead has asked whether to leave this pending or design a broader manual override. Verify recoverability before product implementation; include independent security review for any privileged helper/IPC. Do not equate successful API calls with a successful physical lid-close run.
3. **Local installation and physical acceptance** — preserve bundle ID and existing install path. Privileged installation, if required, and a physical close/open drill need a concrete user-facing handoff. No silent system-wide settings changes.

## Gate requirements

Each builder names regression, Swift typecheck/build, metadata/shell/whitespace lint, packaging and signature checks. Every new automated test must fail on pre-fix source. Native AppKit UI requires a real native render; a browser is not an applicable runtime for this app. Independent and lead review use a pinned head, with clean reviewed worktree verification. CodeRabbit is unavailable by the explicit repository restriction. Do not publish screenshots of unrelated windows or personal content.

## Findings ledger

- **R1 — resolved, owner: Dock builder; independent delta and lead verdict: cleared.** Independent review of `ca9a781989c0051b14b223122ae71b6ab5595fc7` found structural menu mutation in `App.swift:52–54` during `menuWillOpen`. Local AppKit `NSMenu.h:279–281` explicitly prohibits changing menu structure/items in open/close callbacks. Fix `df335612a036637624eace16e4cdbcf64b7de013` moves both the existing menu-bar path and the new Dock path to `menuNeedsUpdate`; `applicationDockMenu` still returns freshly built controls. No delayed mutation or timing workaround is used. Local gates and code-head CI passed; native acceptance remains separate.
- **N1 — acceptance blocked, owner: lead.** Reviewed build 6 packaged and installed with a verified signature; Settings render/preference restoration and Quit/relaunch passed. CUA cannot target Dock (timeouts); actual Dock/status menu/reopen acceptance remains pending. Existing Accessibility/preview grants were not recognized after the ad-hoc update, blocking live chooser checks. Lead-directed rollback restored signed build 5 with its prior grants verified and enabled=true; no privacy change was made. Build 6 remains packaged in the builder's `dist/Pane Management.app`. Lead coordinates manual/native acceptance, with renewal of existing grants if required. See `VERIFICATION.md` for exact paths/evidence.
- Architecture review completed read-only: public assertions do not block lid sleep; internal assertion modifiers require an Apple entitlement; the raw selector changes a shared power-management bit without caller-owned cleanup. The broad `pmset SleepDisabled` setting short-circuits native emergency sleep branches ([Apple source](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/iokit/Kernel/IOPMrootDomain.cpp#L7803-L7868)). Slice 2 is blocked pending the user's scope decision. No runtime sleep settings or privileged installation were changed; Dock slice 1 proceeds independently.
- Native reviewer initially stopped on the older model self-check; user authorized current model and review resumed. No files were changed in that stopped attempt.

## Recovery acceptance

For Dock work, closing Settings leaves the app accessible through both icons, Dock reopen restores Settings, Quit exits the app, and existing snap chooser reopen exclusions remain intact.

For coding mode, review off, armed/open, active/closed, missing or denied capability, failed activation, failed restoration, process crash and reboot. A state may only be described as active after observed success; recovery must be available from visible UI.
