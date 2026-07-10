import Foundation
import Observation
import Carbon.HIToolbox

/// Global-shortcut settings, persisted to UserDefaults. Default: disabled.
@MainActor
@Observable
final class HotKeyPreferences {
    var enabled: Bool { didSet { save() } }
    var keyCode: UInt32 { didSet { save() } }
    var modifiers: UInt32 { didSet { save() } }
    var display: String { didSet { save() } }

    // Number-key jump shortcuts: press 1…9 while the panel is focused to jump to the Nth agent.
    var jumpEnabled: Bool { didSet { save() } }

    // Refresh shortcut (⌘R by default), also panel-open only. A full key combo (key + modifiers).
    var refreshEnabled: Bool { didSet { save() } }
    var refreshKeyCode: UInt32 { didSet { save() } }
    var refreshModifiers: UInt32 { didSet { save() } }
    var refreshDisplay: String { didSet { save() } }

    private enum K {
        static let enabled = "hotkey.enabled"
        static let keyCode = "hotkey.keyCode"
        static let modifiers = "hotkey.modifiers"
        static let display = "hotkey.display"
        static let jumpEnabled = "jump.enabled"
        static let refreshEnabled = "refresh.enabled"
        static let refreshKeyCode = "refresh.keyCode"
        static let refreshModifiers = "refresh.modifiers"
        static let refreshDisplay = "refresh.display"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: K.enabled) // default false
        keyCode = UInt32(defaults.object(forKey: K.keyCode) as? Int ?? Int(kVK_ANSI_M))
        modifiers = UInt32(defaults.object(forKey: K.modifiers) as? Int ?? Int(optionKey))
        display = defaults.string(forKey: K.display) ?? "⌥M"
        jumpEnabled = defaults.object(forKey: K.jumpEnabled) as? Bool ?? true
        refreshEnabled = defaults.object(forKey: K.refreshEnabled) as? Bool ?? true
        refreshKeyCode = UInt32(defaults.object(forKey: K.refreshKeyCode) as? Int ?? Int(kVK_ANSI_R))
        refreshModifiers = UInt32(defaults.object(forKey: K.refreshModifiers) as? Int ?? Int(cmdKey))
        refreshDisplay = defaults.string(forKey: K.refreshDisplay) ?? "⌘R"
    }

    private let defaults: UserDefaults

    private func save() {
        defaults.set(enabled, forKey: K.enabled)
        defaults.set(Int(keyCode), forKey: K.keyCode)
        defaults.set(Int(modifiers), forKey: K.modifiers)
        defaults.set(display, forKey: K.display)
        defaults.set(jumpEnabled, forKey: K.jumpEnabled)
        defaults.set(refreshEnabled, forKey: K.refreshEnabled)
        defaults.set(Int(refreshKeyCode), forKey: K.refreshKeyCode)
        defaults.set(Int(refreshModifiers), forKey: K.refreshModifiers)
        defaults.set(refreshDisplay, forKey: K.refreshDisplay)
    }
}
