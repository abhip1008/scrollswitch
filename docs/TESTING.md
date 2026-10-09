# Testing

## Automated

```sh
make test
```

Covers spec section 13.1. Nothing here touches your real scroll setting: `ScrollController`
is tested against `MemoryScrollSetter`, and `DockDetector` runs on a hand-driven
`ManualDebouncer` so there are no sleeps and no flaky timing.

| Area | Tests |
|------|-------|
| Docking rules | every rule, the markers fallback, the lid modifier, unknown lid state |
| Debounce | first evaluation is immediate, a 5-event burst collapses to one transition, settling back where it started applies nothing, re-evaluate skips the window |
| Controller | direction per state, skip when already correct, pause, force, follow-again, manual override set / survives wake / expires on the next dock change, unsupported macOS never writes |
| Settings | defaults, round trip, partial JSON keeps defaults, store save and load |
| Log | 200-event cap, newest-first transcript |

## Manual matrix

Spec section 13.2. Open Show Log first; every step below should leave a trace.

| # | Start | Action | Expected | Pass |
|---|-------|--------|----------|------|
| 1 | Undocked, natural | Plug in the KVM, close the lid | Traditional within 3 s | [ ] |
| 2 | Docked, traditional | Unplug, open the lid | Natural within 3 s | [ ] |
| 3 | Docked | Switch the KVM to the other computer and back | Ends Docked, traditional | [ ] |
| 4 | Docked | Sleep 10 minutes, wake | Still traditional | [ ] |
| 5 | Docked | Sleep, unplug, wake undocked | Natural | [ ] |
| 6 | Any | Reboot | App auto-starts, direction correct | [ ] |
| 7 | Docked | Toggle the setting in System Settings | App leaves it alone, menu shows the override | [ ] |
| 8 | After 7 | Undock | Override cleared, natural applied | [ ] |
| 9 | Any | Pause Automation, then dock/undock | No changes made | [ ] |
| 10 | Docked | Open System Settings, Mouse pane | Checkbox matches the actual behaviour | [ ] |
| 11 | Any | Scroll in Safari, Chrome, Finder, VS Code after each switch | Correct everywhere, no relaunch needed | [ ] |

## Performance targets

Spec section 12. Check with Activity Monitor while docked and idle.

| Target | Expected |
|--------|----------|
| Idle CPU | effectively 0 percent, the app is event driven and never polls |
| Memory | under 30 MB |
| Plug-in to switch | under 3 s (1.5 s debounce plus display wake) |
| Wrong-direction states | zero over a week of daily docking |
