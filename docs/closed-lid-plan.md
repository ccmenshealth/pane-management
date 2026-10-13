# Dock and closed-lid coding

## Locked user decisions — 2026-10-12

- D1: Pane Management appears in the Dock while running, retaining its menu-bar icon.
- D2: The eventual closed-lid coding switch is available in both the menu-bar menu and the Dock right-click menu, sharing one state.
- D3: When enabled, keep coding running on battery or AC with the lid closed. This specifically supports travel on battery.
- D4: With the lid open, ordinary display, built-in input, and sleep behavior apply. Opening the lid returns to ordinary use; the switch may remain armed for the next closure.
- D5: With the lid closed, the built-in screen and keyboard backlight are dark. Input hardware follows normal macOS lid behavior; no global keyboard/trackpad interception is requested.
- D6: No arbitrary 20% battery or high-thermal-pressure cutoff. The user subsequently clarified that native critical battery/heat sleep should remain available. Investigation of app-managed final-battery/critical-thermal release is authorized, but this is not acceptance of weaker emergency protection or approval to enable a power override.
- D7: Off is the default on launch. Turning off or quitting must release changes owned by this feature; crashes and restoration failures need an observable recovery path.
- D8: The user authorized the current Codex model for native builders/reviewers, overriding the older model pin in the gated-build skill. All other gates apply.
- D9: The user authorized investigation of the guarded approach. No power-setting changes, privileged installation, deliberate heat/battery stress, or physical sleep experiment is included in this investigation.

## Slices

1. **Dock presence and existing controls** — isolated PR. Make the running app visible in the Dock; keep reopen behavior and expose existing Settings/pause controls in its contextual menu. Do not expose an inoperative coding toggle. Verify native Dock/menu rendering and existing regression suite.
2. **Closed-lid mechanism and controls — investigation complete; no product implementation authorized.** Read-only review of both the original mechanism and a guarded global override found no validated match for the exact lid-only behavior and recovery requirements. See the investigation below. A normal idle-sleep assertion does not cover lid closure. Verify recoverability before product implementation; include independent security review for any privileged helper/IPC. Do not equate successful API calls with a successful physical lid-close run.
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

## Guarded override investigation — October 12, 2026

**Verdict:** feasible as a best-effort experimental design, not a demonstrated
replacement for native emergency sleep and not ready for backpack use. The lead
and a separate read-only architecture reviewer agree. No product code, installed
bundle, permissions, power settings, or background services changed during this
investigation. Host: Mac14,2, macOS 26.5.1 (25F80). Source versions inspected:
IOKitUser-100231.120.3, PowerManagement-1846.120.8.0.1, xnu-12377.121.6.
The reviewer used the user-authorized current model; exact model/effort metadata
was unavailable. The reviewer made no edits; the lead owns this documentation.

### Findings

1. A guard could observe final battery and critical thermal warnings and request
   removal of the sleep override. These are advisory signals, not acknowledgments
   that macOS's emergency sleep path has been preserved. The matching powerd
   source sets Final at **2% UI state of charge**, while the public header's older
   time estimate explicitly provides no minimum warning time. The battery getter
   returns None even for some failed/missing reads. Local Foundation headers state
   that unknown/unsupported thermal state returns Nominal. Polling and notifications
   therefore cannot by themselves prove that the readings are healthy or timely.
   Sources: [battery publisher](https://github.com/apple-oss-distributions/PowerManagement/blob/PowerManagement-1846.120.8.0.1/pmconfigd/BatteryTimeRemaining.m#L1278-L1359),
   [battery getter](https://github.com/apple-oss-distributions/IOKitUser/blob/IOKitUser-100231.120.3/ps.subproj/IOPowerSources.c#L53-L87),
   [Apple thermal guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/RespondToThermalStateChanges.html),
   host SDK `IOPowerSources.h:89–108` and `NSProcessInfo.h:214–227`.
2. `SleepDisabled` is a persistent system setting with no owner or expiry. Its
   setter copies and overwrites preferences, synchronizes, then posts notification;
   success is not proof that the machine has slept. In the kernel sleep check,
   the override is checked before the battery/thermal emergency exceptions. This
   finding concerns sleep; it does not establish that every hardware shutdown or
   thermal-throttling protection is disabled.
   Sources: [setter](https://github.com/apple-oss-distributions/IOKitUser/blob/IOKitUser-100231.120.3/pwr_mgt.subproj/IOPMEnergyPrefs.c#L1624-L1677),
   [sleep check](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/iokit/Kernel/IOPMrootDomain.cpp#L7803-L7868),
   [native emergency requests](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.121.6/iokit/Kernel/IOPMrootDomain.cpp#L8838-L8888).
3. A root helper, write-ahead recovery record, short heartbeat, launchd restart,
   and independent watchdog can reduce ordinary failure risk. They cannot make
   an unowned global preference automatically expire. The local `launchd.plist`
   manual documents restart throttling (default 10 seconds); KeepAlive restarts
   exited jobs, not hung jobs. Reboot does not itself undo this preference.
4. Reacting only after lid closure still races the sleep decision. Prearming the
   broad override affects open-lid sleep, contrary to D4. The narrower private
   clamshell selector avoids the broad emergency-sleep override but changes a
   shared powerd bit without caller cleanup; it is not a validated alternative.

### Failure analysis for a hypothetical prototype

| Event | Possible mitigation | Remaining limitation |
| --- | --- | --- |
| App quits/crashes | Helper clears override on disconnected/expired session | Helper must still execute successfully |
| Helper crashes after setting override | Write intent first; restart restores before accepting new sessions | Persistent override remains during restart; restart can fail |
| Helper hangs | Separate watchdog detects missing heartbeat and attempts restore | Watchdog or common OS services can fail too |
| Battery/thermal warning arrives | Restore and verify both preference and effective state | No promised warning lead time; delivery and restoration are asynchronous |
| Missing/stale telemetry | Refuse activation or stop session | Public APIs can disguise unknown state as normal |
| Reboot/update/uninstall | Recovery before activation; restore before removal | A missing/disabled helper cannot repair a persistent setting |
| Another app changes sleep policy | Refuse known conflicts; detect observable changes | No atomic ownership test; identical later values are indistinguishable |
| Restore fails | Show Recovery required and an explicit Restore normal sleep action; retry | User cannot rely on a visible action while the laptop is in a backpack |

### Scope of any next experiment

An isolated dry-run state machine could test journal ordering, startup recovery,
timeouts, telemetry failures, and conflicting writes using a fake power backend.
Its results would prove only its logic, not actual emergency behavior. A root
helper would additionally require authenticated IPC, a stable signing identity,
fixed operations, protected recovery storage, and independent security review.
Live fault injection would require a separately authorized test-Mac plan covering
crash, SIGKILL, hang, disabled helper, reboot, restore failure, concurrent writers,
and actual lid behavior. Do not deliberately overheat or exhaust this working Mac
to test it. No dry-run prototype or physical validation was performed here.

The present requirement is not satisfied. Proceeding with a best-effort prototype
would require an explicit scope decision about weaker recovery guarantees and
open-lid behavior; investigation approval alone does not supply that decision.
