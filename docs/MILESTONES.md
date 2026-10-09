# Milestones and requirement coverage

Tracking against `ScrollSwitch-Spec.md`.

## Milestones

| Milestone | Scope | Status |
|-----------|-------|--------|
| **M0** API spike | `scrollswitch-spike` target: probe the private symbol, flip live, restore | Built. Run `make spike` to confirm on your macOS version. |
| **M1** Manual toggle app | Menu bar app, Force Natural / Force Traditional, current state | Built. |
| **M2** Auto-detection | Display, device and power monitors, debounced DockDetector, any-external-display rule | Built. |
| **M3** Polish | Learn My Dock, markers, lid option, manual override, pause, launch at login, Preferences, log | Built. |
| **M4** Daily-use hardening | Unit tests, a week of real use | Tests written. The week of real use is yours. |

## Functional requirements

| ID | Requirement | Where |
|----|-------------|-------|
| FR-1 | Read the current value | `ScrollSetter.current` |
| FR-2 | Set it live, no logout | `ScrollSetter.apply` |
| FR-3 | Detect displays connecting and disconnecting | `DisplayMonitor` |
| FR-4 | Detect external pointers, including through the KVM hub | `DeviceMonitor` |
| FR-5 | Configurable rule plus debounce | `DockDetector.isDocked`, `DockDetector.submit` |
| FR-6 | Apply the configured direction on a transition | `ScrollController.handleTransition` |
| FR-7 | Re-check on wake and on launch | `PowerMonitor`, `ScrollSwitchCoordinator.reevaluate` |
| FR-8 | Menu bar icon and menu | `MenuView`, `ScrollSwitchCoordinator.menuBarSymbol` |
| FR-9 | Launch at login | `LaunchAtLogin` via `SMAppService` |
| FR-10 | Learn my dock | `ScrollSwitchCoordinator.learnMyDock` |
| FR-11 | Respect manual changes | `ScrollChangeWatcher`, `ScrollController.externalChangeDetected` |
| FR-12 | Optional lid signal | `LidMonitor`, `Settings.requireLidClosed` |
| FR-13 | Log viewer, last 200 events | `EventLog`, `LogView` |
| FR-14 | Optional notification on change | `Notifier`, `Settings.notifyOnChange` |

## Deliberate deviations from the spec

1. **SwiftPM instead of an `.xcodeproj`.** Spec section 14 sketches an Xcode project. This
   repo is a Swift package with the same internal layout (`Core/`, `Monitors/`, `UI/`,
   `Support/`), plus a `Makefile` that assembles and ad-hoc signs `ScrollSwitch.app`. The
   reason is that `swift test` and `swift build` run from a terminal with no project file
   to keep in sync, and the App Sandbox is off by default, which section 10 requires.
   Opening the package folder in Xcode still works if you prefer the IDE.

2. **`Settings.markerLabels` is an extra field.** Spec section 8 stores only the marker
   identities. Without a label the Preferences marker list reads as raw vendor and
   product numbers once the hardware is unplugged, so the learned name is kept alongside.

3. **The device notification is not usage-filtered in the matching dictionary.** Section
   6.2 suggests filtering on Generic Desktop Mouse/Pointer. In practice a mouse does not
   reliably declare Mouse in `PrimaryUsage`; some only do so in `DeviceUsagePairs`.
   `DeviceMonitor` therefore watches all `IOHIDDevice` services, selects pointers when it
   reads the registry, and swallows any event that leaves the pointer list unchanged, so a
   keyboard being plugged in costs nothing.

4. **Force is a mode, not a one-shot.** Section 9.2 lists Force Natural and Force
   Traditional next to Pause Automation. Here a forced direction stays pinned until you
   choose Follow Dock State Again, which is what makes it useful during a presentation.

## Open questions from the spec

1. Does `setSwipeScrollDirection` still work on macOS 27? **Unanswered.** Run `make spike`.
   The `Status` tab in Preferences answers the same question at any time.
2. Does the KVM drop its devices when switched away? Watch the log after a switch.
3. Is 1.5 s the right debounce? The slider in Preferences goes from 0.5 s to 5 s.
