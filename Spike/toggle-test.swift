// Phase 0 spike: prove the private live toggle works on this macOS version.
//
//   swiftc Spike/toggle-test.swift -o Spike/bin/toggle-test && Spike/bin/toggle-test
//
// Flips Natural scrolling once. Run it again to flip it back.
import Foundation

let path = "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport"
guard let handle = dlopen(path, RTLD_LAZY) else {
    print("Could not load framework"); exit(1)
}

typealias SetFn = @convention(c) (Bool) -> Void
typealias GetFn = @convention(c) () -> Bool

guard let setSym = dlsym(handle, "setSwipeScrollDirection"),
      let getSym = dlsym(handle, "swipeScrollDirection") else {
    print("Functions not found on this macOS version"); exit(1)
}

let setDirection = unsafeBitCast(setSym, to: SetFn.self)
let getDirection = unsafeBitCast(getSym, to: GetFn.self)

let current = getDirection()
print("Natural scrolling is currently:", current ? "ON" : "OFF")
setDirection(!current)
print("Flipped to:", getDirection() ? "ON" : "OFF")
