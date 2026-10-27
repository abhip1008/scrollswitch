# Phase 6: test pass

Two layers:

1. **Automated** (`make test`, 49 tests). The decision logic runs against fake displays,
   USB devices, lid state and a fake toggler, so every rule and timing case is covered
   without touching hardware.
2. **Hardware** (the table below). These need cables to be plugged and pulled by hand.

Status as of 2026-10-26, build Mac on macOS 27.0.1. "Unit" names the automated test that
covers the same logic. "Live" means it was checked on the real Mac.

| # | Starting state | Action | Expected result | Unit coverage | Hardware |
|---|---|---|---|---|---|
| 1 | Undocked, Natural ON | Plug KVM, then HDMI, close lid | One flip to OFF | `testBurstOfEventsCausesOneFlip` | pending |
| 2 | Docked, Natural OFF | Unplug both, open lid | Natural ON | `testManualChangeIsNotUndoneUntilNextChange` | pending |
| 3 | Docked | Unplug only HDMI | Stays OFF (KVM monitor still there) | `testAnyExternalDockedWithOneOrTwoExternals` | pending |
| 4 | Docked | Unplug only KVM | Stays OFF with "any external" rule | `testAnyExternalDockedWithOneOrTwoExternals` | pending |
| 5 | Docked | Switch KVM to another computer | Stays OFF (HDMI still there) | `testAnyDeskDisplayMatchesSavedMonitor` | pending |
| 6 | Undocked | Plug only HDMI | OFF with "any external"; depends on rule otherwise | evaluator rule tests | pending |
| 7 | Docked, lid closed | Sleep, unplug all, open lid | Natural ON after wake | `testUnpluggedWhileAsleepGivesNaturalOnAfterWake` | pending |
| 8 | Undocked, asleep | Plug everything, wake with keyboard | Natural OFF | `testWakeForcesReapply` | pending |
| 9 | Docked | Restart Mac | Natural OFF after login | `testLaunchAppliesDocked` | pending |
| 10 | Undocked | Restart Mac | Natural ON after login | `testAlreadyCorrectValueIsNotWritten` | pending |
| 11 | Docked | Manually turn Natural ON in System Settings | App leaves it ON until next unplug | `testManualChangeIsNotUndoneUntilNextChange` | **live: pass** (set ON from outside, app logged it and left it) |
| 12 | Desk rule on | Plug into a non-desk monitor/projector | Stays ON | `testDeskRuleIgnoresProjector` | pending |
| 13 | Paused 1 hr | Unplug | No change; resumes after the hour | `testPausedIgnoresUnplugAndResumeApplies`, `testTimedPauseBlocksThenResumesWithForce` | pending |
| 14 | Docked | Monitor goes to sleep and wakes on its own | No flip-flop | `testManualChangeIsNotUndoneUntilNextChange` (noise event) | pending |
| 15 | Any | Plug/unplug KVM fast 5 times | Ends in the correct state, only 1 to 2 flips logged | `testBurstOfEventsCausesOneFlip` | pending |
| 16 | Any | Quit app | Setting stays where it was, nothing breaks | n/a (quit does not write) | pending |

Also checked live on 2026-10-26:

- Installed to `/Applications`, launched, menu bar icon shows the mouse (Natural OFF).
- Launch decision logged: `Docked: 2 external displays, lid closed. Natural scrolling already OFF [launch]`.
- Registered as a login item (`sfltool dumpbtm` shows it enabled, one entry).
- `scrollswitch-cli status` reads both desk monitors, lid closed, and the app's decision.

## How to run the hardware rows

```bash
# Watch the app's decisions live while you plug and unplug
log stream --predicate 'subsystem == "com.abhirampurohit.scrollswitch"' --info

# Current value (1 = Natural ON)
defaults read -g com.apple.swipescrolldirection
```

Or open **Recent activity…** from the menu. Each automatic switch is one `→` line.
