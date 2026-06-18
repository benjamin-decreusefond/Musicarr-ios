import SwiftUI

/// Client-side equalizer settings.
///
/// NOTE ON AUDIO WIRING: the app streams via `AVPlayer`, which does not expose a
/// tap point for an `AVAudioUnitEQ`. Applying a real EQ would require routing
/// playback through an `AVAudioEngine` graph (decode → `AVAudioPlayerNode` →
/// `AVAudioUnitEQ` → output) and feeding it buffers, which is a substantial change
/// to `PlayerManager` and risks breaking range-streaming / seeking. To stay safe
/// (per the task's "skip if risky" guidance) this screen *persists* the user's
/// band gains and preset to `UserDefaults` so the preference is captured and ready
/// to consume once an audio-engine playback path is added. It does not currently
/// alter live AVPlayer output.
struct EqualizerSettings {
    static let bands: [String] = ["60", "230", "910", "3.6k", "14k"]
    static let presetKey = "musicarr.eq.preset"
    static let gainsKey = "musicarr.eq.gains"

    static let presets: [String: [Float]] = [
        "Flat":        [0, 0, 0, 0, 0],
        "Bass boost":  [6, 4, 1, 0, 0],
        "Treble boost":[0, 0, 1, 4, 6],
        "Vocal":       [-2, 0, 4, 3, -1],
        "Rock":        [4, 2, -1, 2, 4]
    ]
    static let presetOrder = ["Flat", "Bass boost", "Treble boost", "Vocal", "Rock"]

    static func loadGains() -> [Float] {
        if let arr = UserDefaults.standard.array(forKey: gainsKey) as? [Double], arr.count == bands.count {
            return arr.map { Float($0) }
        }
        return [0, 0, 0, 0, 0]
    }
    static func save(gains: [Float], preset: String) {
        UserDefaults.standard.set(gains.map { Double($0) }, forKey: gainsKey)
        UserDefaults.standard.set(preset, forKey: presetKey)
    }
    static func loadPreset() -> String {
        UserDefaults.standard.string(forKey: presetKey) ?? "Flat"
    }
}

struct EqualizerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gains: [Float] = EqualizerSettings.loadGains()
    @State private var preset: String = EqualizerSettings.loadPreset()

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tune your sound. Presets and band gains are saved on this device.")
                            .font(Theme.body(13)).foregroundStyle(Theme.textDim)

                        Picker("Preset", selection: $preset) {
                            ForEach(EqualizerSettings.presetOrder, id: \.self) { Text($0).tag($0) }
                        }
                        .musicarrSegmented()
                        .onChange(of: preset) { newValue in
                            if let g = EqualizerSettings.presets[newValue] { gains = g; persist() }
                        }

                        bands

                        GhostButton(title: "Reset to flat", systemImage: "arrow.counterclockwise") {
                            preset = "Flat"
                            gains = EqualizerSettings.presets["Flat"] ?? [0, 0, 0, 0, 0]
                            persist()
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
                }
            }
            .navigationTitle("Equalizer")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .musicarrScreen()
    }

    @ViewBuilder private var bands: some View {
        #if os(tvOS)
        // tvOS has no Slider; show the saved gains read-only (presets remain usable).
        VStack(spacing: 10) {
            ForEach(Array(EqualizerSettings.bands.enumerated()), id: \.offset) { i, label in
                HStack {
                    Text(label).font(Theme.body(13)).foregroundStyle(Theme.textDim).frame(width: 50, alignment: .leading)
                    ProgressView(value: Double((gains[i] + 12) / 24)).tint(Theme.accent)
                    Text("\(Int(gains[i])) dB").font(Theme.body(12)).foregroundStyle(Theme.text).frame(width: 54, alignment: .trailing)
                }
            }
        }
        #else
        VStack(spacing: 14) {
            ForEach(Array(EqualizerSettings.bands.enumerated()), id: \.offset) { i, label in
                HStack(spacing: 12) {
                    Text(label).font(Theme.body(13)).foregroundStyle(Theme.textDim).frame(width: 46, alignment: .leading)
                    Slider(value: Binding(
                        get: { gains[i] },
                        set: { gains[i] = $0; preset = "Custom"; persist() }
                    ), in: -12...12, step: 1)
                    .tint(Theme.accent)
                    Text("\(Int(gains[i])) dB").font(Theme.body(12)).foregroundStyle(Theme.text).frame(width: 54, alignment: .trailing)
                }
            }
        }
        #endif
    }

    private func persist() { EqualizerSettings.save(gains: gains, preset: preset) }
}
