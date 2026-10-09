import Foundation
import ScrollSwitchCore

// Milestone 0 from the spec: prove that the private setSwipeScrollDirection function
// still changes scrolling live on this macOS version before any app gets built.
//
//   scrollswitch-spike             probe, then flip traditional -> natural and restore
//   scrollswitch-spike --status    report only, change nothing
//   scrollswitch-spike --set traditional
//   scrollswitch-spike --set natural

let args = Array(CommandLine.arguments.dropFirst())
let setter = ScrollSetter()

func reportEnvironment() {
    let version = ProcessInfo.processInfo.operatingSystemVersionString
    print("ScrollSwitch API spike")
    print("  macOS:            \(version)")
    print("  API supported:    \(setter.isSupported ? "yes" : "NO")")
    if let path = setter.resolvedPath { print("  framework:        \(path)") }
    if let symbol = setter.resolvedSymbol { print("  symbol:           \(symbol)") }
    if let reason = setter.unsupportedReason { print("  reason:           \(reason)") }
    print("  current setting:  \(setter.current.displayName)")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

reportEnvironment()

if args.contains("--status") {
    exit(setter.isSupported ? 0 : 1)
}

guard setter.isSupported else {
    print("")
    print("The private API did not resolve. Do not build on top of it.")
    print("Go to spec section 7.2 and pick a fallback:")
    print("  1. hunt for a renamed symbol with dyld_info -exports")
    print("  2. AppleScript the System Settings checkbox")
    print("  3. per-device inversion with a CGEventTap (Appendix A)")
    fail("setSwipeScrollDirection unavailable")
}

if let index = args.firstIndex(of: "--set") {
    guard index + 1 < args.count,
          let direction = ScrollDirection(rawValue: args[index + 1]) else {
        fail("--set needs either natural or traditional")
    }
    setter.apply(direction)
    print("")
    print("applied \(direction.displayName); setting now reads \(setter.current.displayName)")
    exit(0)
}

// Default run: flip away, give you time to scroll, flip back.
let original = setter.current
let probe = original.opposite

print("")
print("Flipping to \(probe.displayName). Scroll something now -- it should feel inverted.")
setter.apply(probe)
print("  setting reads: \(setter.current.displayName)")

Thread.sleep(forTimeInterval: 5)

print("Restoring \(original.displayName).")
setter.apply(original)
print("  setting reads: \(setter.current.displayName)")
print("")
print("If scrolling actually changed direction during those 5 seconds without a logout,")
print("Milestone 0 passes and the rest of the app is safe to build.")
