// scrollswitch-cli: the Phase 1 engine without UI, plus diagnostics.
//
//   scrollswitch-cli watch          watch displays and flip Natural scrolling (any external display rule)
//   scrollswitch-cli status         print displays, lid, USB, Natural scrolling and the app's decision
//   scrollswitch-cli set on|off     set Natural scrolling once
//   scrollswitch-cli devices        list USB devices with vendor and product IDs
import AppKit
import ScrollSwitchCore

let appDomain = "com.abhirampurohit.scrollswitch"

func onOff(_ on: Bool) -> String { on ? "ON" : "OFF" }

func usage() -> Never {
    print("""
    usage: scrollswitch-cli <command>

      watch        watch displays and flip Natural scrolling (rule: any external display)
      status       show displays, lid, USB devices, Natural scrolling and the app's decision
      set on|off   set Natural scrolling once
      devices      list USB devices with vendor and product IDs
    """)
    exit(2)
}

func status() {
    let (toggler, warning) = ScrollTogglerFactory.makeBest()
    let snap = DisplayMonitor.takeSnapshot()
    let usb = USBMonitor.scan()
    let lidOpen = LidState.isOpen(snapshot: snap)
    let appSettings = UserDefaults(suiteName: appDomain).map { SettingsStore(defaults: $0).load() } ?? SwitchSettings()

    print("Natural scrolling: \(onOff(toggler.isNatural))  (method: \(toggler.methodName))")
    if let warning { print("Warning: \(warning)") }
    switch LidState.isClosed() {
    case .some(true): print("Lid: closed")
    case .some(false): print("Lid: open")
    case .none: print("Lid: unknown (no clamshell state), built-in display \(snap.builtinOnline ? "online" : "offline")")
    }
    print("Displays (\(snap.displays.count), \(snap.externals.count) external):")
    for d in snap.displays {
        print("  \(d.isBuiltin ? "built-in" : "external") \(d.name)  vendor=\(d.vendor) model=\(d.model) serial=\(d.serial)")
    }
    let state = DockStateEvaluator.evaluate(snapshot: snap, usbPresent: usb, lidOpen: lidOpen, settings: appSettings)
    print("App rule: \(appSettings.rule.label)  desk displays=\(appSettings.desk.displays.count) desk USB=\(appSettings.desk.usbDevices.count)")
    print("App decision: \(state.label) → Natural scrolling \(onOff(appSettings.natural(for: state)))")
    if appSettings.pause.isActive(now: Date()) { print("App is paused: \(appSettings.pause)") }
}

func devices() {
    for d in USBMonitor.scan().sorted(by: { $0.name < $1.name }) {
        let name = d.name.padding(toLength: max(d.name.count, 36), withPad: " ", startingAt: 0)
        print("\(name)  vendor=\(d.vendorID)  product=\(d.productID)  (\(d.hexDescription))")
    }
}

func set(_ arg: String?) {
    guard let arg, arg == "on" || arg == "off" else { usage() }
    let (toggler, warning) = ScrollTogglerFactory.makeBest()
    if let warning { print("Warning: \(warning)") }
    let target = arg == "on"
    let ok = toggler.setNatural(target)
    print(ok ? "Natural scrolling \(onOff(target))" : "Failed: Natural scrolling is still \(onOff(toggler.isNatural))")
    exit(ok ? 0 : 1)
}

@MainActor
func watch() -> Never {
    if !NSRunningApplication.runningApplications(withBundleIdentifier: appDomain).isEmpty {
        print("Note: ScrollSwitch.app is running too. Quit it first or the two will both react to changes.")
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    // Its own settings domain, so watching never touches the app's saved choices.
    let defaults = UserDefaults(suiteName: "\(appDomain).cli")!
    defaults.removeObject(forKey: "settings.v1")
    let log = EventLog()
    log.echo = { event in
        print("\(formatter.string(from: event.date)) \(event.kind.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)) \(event.message)")
        fflush(stdout)
    }
    let controller = Controller.live(store: SettingsStore(defaults: defaults), log: log)
    controller.start()
    print("Watching. Plug or unplug displays; Ctrl-C to stop.")
    _ = NSApplication.shared // screen-parameter notifications need an app object
    RunLoop.main.run()
    exit(0)
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "watch": MainActor.assumeIsolated { watch() }
case "status", nil: status()
case "set": set(args.dropFirst().first)
case "devices": devices()
default: usage()
}
