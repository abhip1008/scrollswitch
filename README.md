# ScrollSwitch

Automatic Natural scrolling toggle for macOS.

macOS has exactly one Natural scrolling switch, shared by the trackpad and the mouse.
If you want natural scrolling on the built-in trackpad and traditional scrolling on a
desk mouse, you have to flip that switch by hand in System Settings every time you dock
or undock. ScrollSwitch watches for the dock event and flips it for you, live, with no
logout and no System Settings window.

- **Undocked** (lid open, trackpad) becomes **Natural**
- **Docked** (clamshell, external displays, mouse) becomes **Traditional**

Menu bar only, no Dock icon, event driven so it costs effectively no CPU.

## Status

See `docs/ScrollSwitch-Spec.md` for the full specification this repo implements, and
`docs/MILESTONES.md` for what is done.

## Requirements

- macOS 13 Ventura or later (Apple silicon or Intel)
- Xcode 15 or later to build
- No third-party dependencies

## Build and run

```sh
make spike     # Milestone 0: prove the private API still flips scrolling live
make test      # unit tests
make app       # build ScrollSwitch.app into dist/
make install   # copy dist/ScrollSwitch.app into /Applications and launch it
```

`make app` ad-hoc signs the bundle, which is enough to run it on your own Mac.

## How it flips the setting

Writing `com.apple.swipescrolldirection` with `defaults` only changes the stored value --
the actual scroll behaviour does not change until you log out. System Settings applies it
live by calling a private function, `setSwipeScrollDirection(Bool)`, in
`PreferencePanesSupport.framework`. ScrollSwitch resolves that function with
`dlopen`/`dlsym` at runtime, writes the stored value to match, and posts
`SwipeScrollDirectionDidChangeNotification` so an open System Settings window redraws its
checkbox.

Because it is a private API, the app checks for it at launch. If a future macOS removes
it, the menu bar icon turns into a warning and the app does nothing harmful.

## Important build setting

The App Sandbox **must be off**. Writing to the global preferences domain fails inside the
sandbox. The SwiftPM build here is unsandboxed by default; if you ever move this into an
Xcode app target, set `Enable App Sandbox = No` in Build Settings.

No Accessibility or Input Monitoring permission is needed: the device monitor only watches
for devices appearing and disappearing, it never opens them.

## Credit

The private API, the distributed notification, and the sandbox gotcha come from
[Shadowfacts, A Mac Menu Bar App to Toggle Natural Scrolling (2021)](https://shadowfacts.net/2021/scrollswitcher/).

## License

MIT. See `LICENSE`.

## First run

1. `make spike` -- this is Milestone 0. It reports whether the private function resolved,
   flips your scroll direction for five seconds, then puts it back. If scrolling really
   inverts during those five seconds, everything else will work.
2. `make install` -- builds, signs, installs into `/Applications`, and launches it.
3. Plug into your dock, then open the menu and choose **Learn My Dock**. That records the
   displays and mouse that are attached right now and switches the rule from
   "any external display" to "dock markers", so a projector in a classroom no longer
   looks like your desk.
4. Dock and undock once with **Show Log...** open to confirm the transitions.

## Project layout

```
Sources/
  ScrollSwitchCore/        no UI, fully unit testable
    Core/                  Identity, Settings, ScrollSetter, Signals,
                           DockDetector, ScrollController, Coordinator
    Monitors/              DisplayMonitor, DeviceMonitor, LidMonitor, PowerMonitor
    Support/               Logger, ScrollChangeWatcher, LaunchAtLogin, Notifier
  ScrollSwitchApp/         @main, MenuBarExtra, Preferences, log viewer
  APISpike/                Milestone 0 command-line probe
Tests/ScrollSwitchTests/   rules, debounce, controller, settings, log
Resources/Info.plist       LSUIElement = YES
docs/                      the spec, milestone tracking, the test matrix
```

Only `ScrollSetter` touches the system setting, and only `ScrollController` calls it. That
is what makes it safe to unit test the decision logic against a fake.

## Documentation

- `docs/ScrollSwitch-Spec.md` -- the specification this implements
- `docs/MILESTONES.md` -- milestone and requirement coverage, and where it deviates
- `docs/TESTING.md` -- the automated coverage plus the manual dock/undock matrix
- `docs/RUNNING.md` -- how to verify it works and how to keep it running at login
