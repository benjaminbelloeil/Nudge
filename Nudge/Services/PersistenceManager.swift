import Foundation
import Combine

@MainActor
final class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()

    private let fileName = "nudge_history.json"
    @Published private(set) var entries: [NudgeEntry] = []

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appending(path: fileName)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        loadEntries()
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
            try data.write(to: fileURL, options: .atomic)
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
