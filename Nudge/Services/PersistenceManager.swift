import Foundation
import Combine

@MainActor
final class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()

    private let fileName = "nudge_history.json"
    @Published private(set) var entries: [NudgeEntry] = []

    // MARK: - File URLs

    /// iCloud Documents container URL (nil when iCloud is unavailable or capability not enabled)
    private var iCloudURL: URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs.appendingPathComponent(fileName)
    }

    /// Local fallback (always available)
    private var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    /// Active storage location: prefer iCloud when available
    private var fileURL: URL { iCloudURL ?? localURL }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        migrateToiCloudIfNeeded()
        loadEntries()
    }

    // MARK: - iCloud Migration

    /// One-time copy of local data into the iCloud container when iCloud first becomes available.
    private func migrateToiCloudIfNeeded() {
        guard
            let cloudURL = iCloudURL,
            !FileManager.default.fileExists(atPath: cloudURL.path),
            FileManager.default.fileExists(atPath: localURL.path)
        else { return }
        try? FileManager.default.copyItem(at: localURL, to: cloudURL)
    }

    // MARK: - Load

    func loadEntries() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([NudgeEntry].self, from: data)
            entries.sort { $0.createdAt > $1.createdAt }
        } catch {
            entries = []
        }
    }

    // MARK: - Save

    private func persist() {
        do {
            let data = try encoder.encode(entries)
            // Write to active location (iCloud or local)
            try data.write(to: fileURL, options: .atomic)
            // Keep a local copy in sync so the app works offline / off-iCloud too
            if iCloudURL != nil {
                try? data.write(to: localURL, options: .atomic)
            }
        } catch {
            // Silent failure for MVP
        }
    }

    // MARK: - CRUD

    func addEntry(_ entry: NudgeEntry) {
        entries.insert(entry, at: 0)
        persist()
    }

    func updateEntry(_ entry: NudgeEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func toggleCompletion(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isCompleted.toggle()
        entries[index].completedAt = entries[index].isCompleted ? Date() : nil
        persist()
    }

    // MARK: - Queries

    func entriesForDateRange(from start: Date, to end: Date) -> [NudgeEntry] {
        entries.filter { $0.createdAt >= start && $0.createdAt <= end }
    }

    func entriesForWeek(containing date: Date) -> [NudgeEntry] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        return entriesForDateRange(from: weekInterval.start, to: weekInterval.end)
    }
}
