// Phase 0 spike, Backup method A: write the preference with CFPreferences and post the
// distributed notification. Use only if toggle-test.swift fails on a future macOS.
//
//   swiftc Spike/backup-a-test.swift -o Spike/bin/backup-a-test && Spike/bin/backup-a-test on|off
import Foundation

let key = "com.apple.swipescrolldirection" as CFString
let on: Bool
switch CommandLine.arguments.dropFirst().first {
case "on": on = true
case "off": on = false
default: print("usage: backup-a-test on|off"); exit(2)
}

CFPreferencesSetValue(key, on as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
DistributedNotificationCenter.default().postNotificationName(
    NSNotification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil, userInfo: nil, deliverImmediately: true)
print("Wrote \(on ? "ON" : "OFF"). Scroll somewhere: did the direction change without logging out?")
