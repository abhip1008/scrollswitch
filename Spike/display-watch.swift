// Phase 0 spike: print the display list every time CoreGraphics reports a change.
//
//   swiftc Spike/display-watch.swift -o Spike/bin/display-watch && Spike/bin/display-watch
//
// Plug and unplug cables one at a time and count how many callbacks one pull fires.
import AppKit
import CoreGraphics

func dump(_ reason: String) {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    let externals = ids.filter { CGDisplayIsBuiltin($0) == 0 }
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("\(stamp) [\(reason)] online=\(ids.count) externals=\(externals.count) builtin=\(ids.count - externals.count)")
    for id in ids {
        print("    id=\(id) vendor=\(CGDisplayVendorNumber(id)) model=\(CGDisplayModelNumber(id)) serial=\(CGDisplaySerialNumber(id)) builtin=\(CGDisplayIsBuiltin(id) != 0)")
    }
}

CGDisplayRegisterReconfigurationCallback({ id, flags, _ in
    if flags.contains(.beginConfigurationFlag) { return }
    var parts: [String] = []
    if flags.contains(.addFlag) { parts.append("add") }
    if flags.contains(.removeFlag) { parts.append("remove") }
    if flags.contains(.enabledFlag) { parts.append("enabled") }
    if flags.contains(.disabledFlag) { parts.append("disabled") }
    if flags.contains(.setModeFlag) { parts.append("mode") }
    dump("display \(id): \(parts.joined(separator: ","))")
}, nil)

dump("start")
RunLoop.main.run()
