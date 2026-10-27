# Phase 0: hardware facts and spike results

Recorded 2026-10-26 on the build Mac.

## Machine

| Item | Value |
|---|---|
| macOS | 27.0.1 (build 26A434) |
| Chip | Apple M5 |
| Swift | 6.3.2 (Xcode toolchain) |

## Docked (lid closed, KVM + HDMI connected)

| Check | Result |
|---|---|
| `defaults read -g com.apple.swipescrolldirection` | `0` (Natural OFF) |
| `AppleClamshellState` | `Yes` (lid closed) |
| `AppleClamshellCausesSleep` | `No` (externals keep it awake) |
| Built-in display in the online list | **No**, it drops out in clamshell mode |

Displays reported by CoreGraphics:

| Name | Path | Vendor | Model | Serial | Built-in |
|---|---|---|---|---|---|
| LG ULTRAGEAR (3440x1440 @ 85 Hz, main) | KVM | 7789 | 30798 | 402653440 | no |
| XV272U W2 (1440x2560 @ 144 Hz, rotated 90°) | HDMI | 1138 | 4664 | 16843009 | no |

USB devices that come through the KVM (decimal IDs):

| Device | Vendor ID | Product ID |
|---|---|---|
| USB3.1 Hub (KVM hub) | 1507 | 1574 |
| USB2.1 Hub (KVM hub) | 1507 | 1552 |
| Gaming Keyboard | 9610 | 268 |
| USB Receiver (Logitech mouse receiver) | 1133 | 50489 |
| WCH UART TO KB-MS_V1.8 | 6790 | 57897 |

## Undocked

Not recorded yet: the Mac was docked during the build session. Run the commands in SPEC
section 0.1 the next time the lid is open with cables pulled and add the results here. The
app does not depend on these values. Only the built-in display being online matters, and
the evaluator also reads the lid state from `AppleClamshellState`.

## 0.2 Live toggle

`Spike/toggle-test.swift` (`make spike`) on macOS 27.0.1:

- `dlopen` of `PreferencePanesSupport.framework` succeeded.
- `setSwipeScrollDirection` and `swipeScrollDirection` were both found.
- Flip test: `start false` → `flipped true` (`defaults` read `1`) → `restored false`
  (`defaults` read `0`). The stored value follows the call right away, which is what System
  Settings does.
- The live effect matches what the earlier `scrolldir` launchd helper, which calls the same
  function, did on this Mac every day before this build.

**Chosen method: private API.** Backup method A (`Spike/backup-a-test.swift`) is built in as
a fallback that only runs if the private function goes away.

## 0.3 Display detection

`Spike/display-watch.swift` prints every CoreGraphics reconfiguration. One cable pull
usually fires several callbacks (remove, then mode changes on the remaining displays),
which is why the app waits for 2 s of quiet before it acts.
