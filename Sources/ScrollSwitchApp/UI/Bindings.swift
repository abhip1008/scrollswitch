import ScrollSwitchCore
import SwiftUI

// SwiftUI also exports a type called Settings (the Scene), so the model type is spelled
// out in full here.
private typealias ScrollSwitchSettings = ScrollSwitchCore.Settings

extension ScrollSwitchCoordinator {
    /// Two-way binding into one Settings field, routed through update(_:) so every edit
    /// is persisted and re-evaluated instead of silently drifting.
    func binding<Value>(
        _ keyPath: WritableKeyPath<ScrollSwitchSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                self.update { settings in settings[keyPath: keyPath] = newValue }
            }
        )
    }

    /// Pausing has a side effect (reconcile on resume), so it gets its own binding.
    var automationBinding: Binding<Bool> {
        Binding(
            get: { self.settings.automationEnabled },
            set: { newValue in self.setAutomationEnabled(newValue) }
        )
    }
}
