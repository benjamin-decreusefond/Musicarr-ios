import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerManager

    enum Tab: String, CaseIterable { case offline = "On this device", server = "Server queue" }
    @State private var tab: Tab = .offline
    @State private var jobs: [DownloadJob] = []
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.musicarrSegmented()

                if tab == .offline { offlineSection } else { serverSection }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 140)
        }
        .navigationTitle("Downloads")
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: Offline (downloaded for later)

    private var offlineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !downloads.inFlight.isEmpty {
                ForEach(downloads.inFlight.sorted(by: { $0.key < $1.key }), id: \.key) { id, progress in
                    HStack {
                        Text("Downloading…").font(Theme.body(13)).foregroundStyle(Theme.textDim)
                        Spacer()
                        ProgressView(value: progress).frame(width: 120).tint(Theme.accent)
                        Button { downloads.cancel(id) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.textFaint)
                    }
                    .padding(.horizontal, 12)
                }
            }
            if downloads.offlineTracks.isEmpty && downloads.inFlight.isEmpty {
                StateText(text: "No offline songs yet.\nTap the ⋯ menu on any song and choose “Download for offline”.")
            } else {
                HStack {
                    Text("\(downloads.offlineTracks.count) songs · \(sizeString)")
                        .font(Theme.body(13)).foregroundStyle(Theme.textDim)
                    Spacer()
                    if !downloads.offlineTracks.isEmpty {
                        Button("Remove all", role: .destructive) { downloads.removeAll() }
                            .font(Theme.body(13))
                    }
                }
                .padding(.horizontal, 12)

                let tracks = downloads.offlineTracks
                VStack(spacing: 0) {
                    ForEach(tracks) { t in
                        TrackRow(track: t, context: tracks)
                            .removeSwipe { downloads.remove(t.id) }
                    }
                }
            }
        }
    }

    private var sizeString: String {
        ByteCountFormatter.string(fromByteCount: downloads.totalBytes, countStyle: .file)
    }

    // MARK: Server queue (Soulseek fetch jobs)

    private var serverSection: some View {
        VStack(spacing: 8) {
            if jobs.isEmpty {
                StateText(text: "No active server downloads.")
            } else {
                ForEach(jobs) { job in DownloadJobRow(job: job) { Task { await dismiss(job) } } }
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                if let list = try? await app.downloads() { jobs = list }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func dismiss(_ job: DownloadJob) async {
        try? await app.dismissDownload(job.id)
        jobs.removeAll { $0.id == job.id }
    }
}

struct DownloadJobRow: View {
    let job: DownloadJob
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Cover(url: job.cover, size: 46, rounded: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.label).font(Theme.body(14.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                if let d = job.detail {
                    Text(d).font(Theme.body(12.5)).foregroundStyle(Theme.textDim).lineLimit(1)
                }
                if isActive {
                    ProgressView(value: job.progress ?? 0).tint(Theme.accent)
                }
            }
            Spacer()
            Text(statusLabel)
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(statusColor)
            Button { onDismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).foregroundStyle(Theme.textFaint)
        }
        .padding(12)
        .background(Theme.bgElev)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var isActive: Bool { ["downloading", "searching", "importing"].contains(job.status) }
    private var statusLabel: String { job.status.replacingOccurrences(of: "_", with: " ") }
    private var statusColor: Color {
        switch job.status {
        case "done": return Theme.accent
        case "error", "not_found": return Theme.danger
        default: return Color(hex: 0x6FB3FF)
        }
    }
}
