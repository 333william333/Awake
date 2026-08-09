import SwiftUI

struct AboutView: View {

    @ObservedObject var engine: AwakeEngine

    var body: some View {
        VStack(spacing: 0) {
            MacBookGlyph(isOn: engine.isActive)
                .padding(.top, 34)

            Text("Awake")
                .font(.system(size: 30, weight: .bold))
                .padding(.top, 22)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            details
                .padding(.top, 24)

            Button(action: engine.toggle) {
                Text(engine.isActive ? "Turn Off" : "Keep Awake")
                    .frame(width: 96)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(engine.isActive ? Color.primary : Color.accentColor)
            .padding(.top, 26)

            notice
                .padding(.top, 12)

            footer
                .padding(.top, 18)
        }
        .frame(width: 340)
        .padding(.bottom, 18)
        .background(Theme.canvasGradient)
        .sheet(isPresented: $engine.showingOptions) { OptionsView(engine: engine) }
    }

    private var subtitle: String {
        guard engine.isActive else { return "Sleep guard is off" }
        return engine.lidIsGuarded ? "Claude keeps working, lid or no lid"
                                   : "Claude keeps working while the lid is open"
    }

    // MARK: Rows

    private var details: some View {
        Grid(alignment: .leading, horizontalSpacing: 9, verticalSpacing: 5) {
            GridRow {
                label("Status")
                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.isActive ? Theme.liveDot : Color.secondary.opacity(0.45))
                        .frame(width: 6, height: 6)
                    value(engine.isActive ? "Keeping awake" : "Standing by")
                }
            }
            GridRow {
                label("Lid closed")
                value(engine.lidIsGuarded ? "Stays awake" : "Sleeps")
            }
            GridRow {
                label("Display")
                value(engine.isActive && engine.holdDisplayAwake ? "Stays on" : "Sleeps normally")
            }
            GridRow {
                label("Claude")
                value(engine.claudeIsRunning ? "Running" : "Not running")
            }
            GridRow {
                label("Session")
                value(engine.isActive ? engine.elapsed.clockText : "—")
                    .monospacedDigit()
            }
            GridRow {
                label("Power")
                value(engine.powerSummary)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
    }

    // MARK: Notice

    @ViewBuilder
    private var notice: some View {
        if let message = engine.notice {
            Text(message)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 250)
                .transition(.opacity)
        } else if engine.lidIsGuarded && !engine.isActive {
            Button("Sleep is still disabled — restore it") {
                engine.restoreLidGuard()
            }
            .buttonStyle(.link)
            .font(.system(size: 10.5))
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 7) {
            Button("Options…") { engine.showingOptions = true }
                .buttonStyle(.link)
                .font(.system(size: 11))

            Text("Awake \(Bundle.main.shortVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Text("Developed by WilliamLabs")
                .font(.system(size: 9, weight: .regular))
                .kerning(0.2)
                .foregroundStyle(.primary)
                .opacity(0.2)
        }
    }
}

// MARK: - Options

struct OptionsView: View {

    @ObservedObject var engine: AwakeEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Options")
                .font(.system(size: 15, weight: .semibold))
                .padding(.bottom, 14)

            toggle("Stay awake with the lid closed",
                   note: "Asks for your password. Restored the moment you turn Awake off.",
                   isOn: $engine.guardLidClose)

            toggle("Keep the display on",
                   note: "Leave off to save power — the Mac stays awake either way.",
                   isOn: $engine.holdDisplayAwake)

            toggle("Follow Claude Desktop",
                   note: "Switch on by itself whenever Claude is running.",
                   isOn: $engine.followClaude)

            HStack {
                Spacer()
                Button("Done") { engine.showingOptions = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 18)
        }
        .padding(22)
        .frame(width: 320)
        .background(Theme.canvasGradient)
    }

    private func toggle(_ title: String, note: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: isOn)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)
            Text(note)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 14)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
