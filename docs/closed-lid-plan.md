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

- Architecture review completed read-only: public assertions do not block lid sleep; internal assertion modifiers require an Apple entitlement; the raw selector changes a shared power-management bit without caller-owned cleanup. The broad `pmset SleepDisabled` setting short-circuits native emergency sleep branches ([Apple source](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/iokit/Kernel/IOPMrootDomain.cpp#L7803-L7868)). Slice 2 is blocked pending the user's scope decision. No runtime sleep settings or privileged installation were changed; Dock slice 1 proceeds independently.
- Native reviewer initially stopped on the older model self-check; user authorized current model and review resumed. No files were changed in that stopped attempt.

## Recovery acceptance

For Dock work, closing Settings leaves the app accessible through both icons, Dock reopen restores Settings, Quit exits the app, and existing snap chooser reopen exclusions remain intact.

For coding mode, review off, armed/open, active/closed, missing or denied capability, failed activation, failed restoration, process crash and reboot. A state may only be described as active after observed success; recovery must be available from visible UI.
