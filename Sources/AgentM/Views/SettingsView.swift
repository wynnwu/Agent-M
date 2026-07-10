import SwiftUI

struct SettingsView: View {
    @Bindable var prefs: HotKeyPreferences

    private let headerFont = Font.system(size: 16, weight: .semibold)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Global shortcut
            Text("Global Shortcut").font(headerFont)

            Toggle("Enable global shortcut", isOn: $prefs.enabled)

            HStack {
                Text("Shortcut").foregroundStyle(.secondary)
                Spacer()
                ShortcutRecorder(display: prefs.display) { kc, m, d in
                    prefs.keyCode = kc; prefs.modifiers = m; prefs.display = d
                }
                .frame(width: 170, height: 26)
            }
            .opacity(prefs.enabled ? 1 : 0.4)
            .disabled(!prefs.enabled)

            Text("Press your shortcut from anywhere to toggle the Agent M popover. Press it again, click away, or press Esc to dismiss. Off by default.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 2)

            // MARK: Jump shortcuts
            Text("Jump Shortcuts").font(headerFont)

            Toggle("Enable jump shortcuts", isOn: $prefs.jumpEnabled)

            Text("With the panel open, press 1–9 to jump to the 1st–9th agent’s terminal — Working first, then Waiting for you.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 2)

            // MARK: Refresh shortcut
            Text("Refresh Shortcut").font(headerFont)

            Toggle("Enable refresh shortcut", isOn: $prefs.refreshEnabled)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Shortcut").foregroundStyle(.secondary)
                    Spacer()
                    ShortcutRecorder(display: prefs.refreshDisplay) { kc, m, d in
                        prefs.refreshKeyCode = kc; prefs.refreshModifiers = m; prefs.refreshDisplay = d
                    }
                    .frame(width: 170, height: 26)
                }

                Text("With the panel open, press \(prefs.refreshDisplay) to refresh the session list.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(prefs.refreshEnabled ? 1 : 0.4)
            .disabled(!prefs.refreshEnabled)
        }
        .font(.system(size: 14))
        .padding(20)
        .frame(width: 380)
        .environment(\.colorScheme, .dark)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}
