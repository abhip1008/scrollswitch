# Verifying it works, and keeping it running

Three checks, in order. Each one proves something the next depends on.

## 1. Does it build, and is the logic right?

```sh
cd ~/Documents/ScrollSwitch
make doctor
```

`make doctor` compiles everything, runs the unit tests, probes the private API, prints the
stored system value, and reports whether the app is installed and running. Expect
`Executed NN tests, with 0 failures` and `API supported: yes`.

## 2. Does the private API really change scrolling? (the only real risk)

```sh
make spike
```

It inverts your scroll direction for five seconds, then restores it. **Scroll in a window
that is already open** during those five seconds -- Safari or Finder, without relaunching
anything. That is the whole point: the setting has to take effect live.

If it reports `API supported: NO`, stop. The app will not work and will show a warning
icon instead of doing damage. Pick a fallback from spec section 7.2.

## 3. Does the app do the job?

```sh
make install
```

A menu bar icon appears:

| Icon | Meaning |
|------|---------|
| mouse | Docked, traditional scrolling |
| hand | Undocked, natural scrolling |
| pause circle | Paused, forced, or a manual override is in effect |
| warning triangle | The private API is gone on this macOS |

Open the menu, choose **Show Log...**, and leave that window up. Now dock. Within about
three seconds the log should read something like:

```
External displays: DELL U2723QE, DELL U2723QE
Now Docked
Docked: applied Traditional
```

Scrolling should change in apps you never restarted. Undock and watch it reverse.

Cross-check that it moved the real setting and not just its own idea of it:

- System Settings > Mouse > Natural scrolling checkbox should match
- `defaults read -g com.apple.swipescrolldirection` -- `1` natural, `0` traditional

Then, while plugged into the dock, choose **Learn My Dock**. That pins the rule to your
own monitors and mouse, so a projector in a classroom stops looking like your desk.

`TESTING.md` has the full eleven-case matrix from the spec as a checklist.

## Keeping it running

### The normal way: launch at login

On by default. The app registers itself with `SMAppService` the first time it starts.
To confirm: Preferences > **Status** tab should read `Launch at login: Enabled`. It should
also appear in System Settings > General > Login Items and Extensions.

If Status reads `Waiting for approval`, approve it in that System Settings pane.

Then reboot once and check the icon comes back.

Three things to know:

- **It has to run from `/Applications`.** That is what `make install` does. The raw SwiftPM
  binary reports `Unavailable`, because `SMAppService` needs a real installed bundle.
- **Every `make install` re-signs the app with a fresh ad-hoc signature**, so macOS can see
  it as a different app and drop the approval. Re-check the Status tab after an update.
- **A login item is not a crash restarter.** If the app ever dies mid-session it stays
  dead until your next login.

### The paranoid way: a LaunchAgent as well

```sh
make agent
```

Installs `~/Library/LaunchAgents/com.abhirampurohit.ScrollSwitch.plist` and loads it. It
starts the app at login and relaunches it within a second if it ever crashes.

`KeepAlive` is set to restart only on an abnormal exit, so **Quit ScrollSwitch** from the
menu stays quit instead of respawning forever.

Turn **off** Launch at login in Preferences when you use this, so only one thing is trying
to start the app. If both do start it, the second instance notices the first and exits, so
you will not get two menu bar icons -- but there is no reason to rely on that.

`make unagent` removes it. `make uninstall` removes the agent and the app together.

## When something looks off

- The icon is the fastest signal. A warning triangle means macOS removed the private API.
- The menu says *why* it is idle rather than just sitting there: `Manual override (until
  next dock change)`, `Automation paused`, `Already correct`.
- **Re-check Now** in the menu forces a fresh evaluation.
- `pgrep -x ScrollSwitch` confirms it is alive.
- The in-app log holds the last 200 events. It also mirrors to the unified log, so history
  survives a crash or a restart:

```sh
log show --predicate 'subsystem == "com.abhirampurohit.ScrollSwitch"' --last 1d
```
