//
//  LogBuffer.swift
//  study-vocab
//
//  Stack-based buffer for delaying Firestore log writes to allow cancellation via undo.
//

import Foundation
import FirebaseFirestore

@MainActor
class LogBuffer {
    static let shared = LogBuffer()

    private struct PendingLogEntry {
        let id = UUID()
        let data: [String: Any]
        let timestamp: Date
        var flushTask: Task<Void, Never>?
    }

    private var stack: [PendingLogEntry] = []
    private let db = Firestore.firestore()
    private let autoFlushDelay: TimeInterval = 10.0

    private init() {}

    /// Push a new log entry onto the stack and start its 10-second auto-flush timer
    func push(data: [String: Any]) {
        let entry = PendingLogEntry(
            data: data,
            timestamp: Date(),
            flushTask: nil
        )

        // Add to stack
        stack.append(entry)
        let entryID = entry.id
        let index = stack.count - 1
        let delay = self.autoFlushDelay

        // Start auto-flush timer for this entry
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self?.autoFlush(id: entryID)
        }

        // Store the task reference so we can cancel it if needed
        stack[index].flushTask = task
    }

    /// Pop the most recent entry from the stack, canceling its auto-flush timer
    /// Returns true if an entry was popped, false if stack was empty
    func pop() -> Bool {
        guard !stack.isEmpty else {
            return false
        }

        // Get the last entry and cancel its flush task
        let entry = stack.removeLast()
        entry.flushTask?.cancel()

        return true
    }

    /// Flush all pending entries to Firestore immediately and clear the stack
    func flushAll() {
        for entry in stack {
            entry.flushTask?.cancel()
            writeToFirestore(data: entry.data)
        }
        stack.removeAll()
    }

    /// Auto-flush a specific entry after its 10-second delay
    private func autoFlush(id: UUID) {
        // Find the entry by ID (indices may have shifted since scheduling)
        guard let index = stack.firstIndex(where: { $0.id == id }) else {
            // Entry was already removed (popped or manually flushed)
            return
        }

        let entry = stack[index]
        writeToFirestore(data: entry.data)

        // Remove from stack
        stack.remove(at: index)
    }

    /// Write a log entry to Firestore
    private func writeToFirestore(data: [String: Any]) {
        db.collection("user_actions").addDocument(data: data) { error in
            if let error = error {
                print("Error writing buffered log to Firestore: \(error)")
            }
        }
    }
}
