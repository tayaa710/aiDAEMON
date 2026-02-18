import Foundation

// MARK: - MessageRole

/// The role of a message in the conversation.
public enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - MessageMetadata

/// Metadata attached to each message — tracks which model handled it, tool calls, and outcome.
public struct MessageMetadata: Codable, Equatable {
    /// Which model provider handled this message (e.g., "Local LLaMA 8B", "OpenAI Cloud").
    /// Nil for user messages.
    public var modelUsed: String?

    /// Whether the cloud model was used (false = local, nil = not applicable).
    public var wasCloud: Bool?

    /// The tool/command that was executed, if any (e.g., "APP_OPEN", "FILE_SEARCH").
    public var toolCall: String?

    /// Whether the action succeeded. Nil if no action was taken.
    public var success: Bool?

    public init(
        modelUsed: String? = nil,
        wasCloud: Bool? = nil,
        toolCall: String? = nil,
        success: Bool? = nil
    ) {
        self.modelUsed = modelUsed
        self.wasCloud = wasCloud
        self.toolCall = toolCall
        self.success = success
    }
}

// MARK: - Message

/// A single message in a conversation.
public struct Message: Identifiable, Codable, Equatable {
    public let id: UUID
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    public var metadata: MessageMetadata

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        metadata: MessageMetadata = MessageMetadata()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Conversation

/// An observable conversation: an ordered list of messages.
/// Used by the UI to display chat history and by PromptBuilder to include context.
public final class Conversation: ObservableObject {
    @Published public private(set) var messages: [Message] = []

    /// Maximum number of recent messages to include as context in prompts.
    /// Default 10. Configurable via UserDefaults "conversation.contextCount".
    public var contextMessageCount: Int {
        let stored = UserDefaults.standard.integer(forKey: "conversation.contextCount")
        return stored > 0 ? stored : 10
    }

    public init() {}

    /// Add a message to the conversation.
    public func addMessage(_ message: Message) {
        messages.append(message)
    }

    /// Convenience: add a user message.
    public func addUserMessage(_ content: String) {
        let msg = Message(role: .user, content: content)
        addMessage(msg)
    }

    /// Convenience: add an assistant message with metadata.
    public func addAssistantMessage(
        _ content: String,
        modelUsed: String? = nil,
        wasCloud: Bool? = nil,
        toolCall: String? = nil,
        success: Bool? = nil
    ) {
        let metadata = MessageMetadata(
            modelUsed: modelUsed,
            wasCloud: wasCloud,
            toolCall: toolCall,
            success: success
        )
        let msg = Message(role: .assistant, content: content, metadata: metadata)
        addMessage(msg)
    }

    /// Clear all messages (new conversation).
    public func clearHistory() {
        messages.removeAll()
    }

    /// The most recent N messages for prompt context.
    public func recentMessages() -> [Message] {
        let count = contextMessageCount
        if messages.count <= count {
            return messages
        }
        return Array(messages.suffix(count))
    }
}

// MARK: - ConversationStore

/// Manages persistence of the active conversation to disk.
/// Saves to: ~/Library/Application Support/com.aidaemon/conversation.json
///
/// - Auto-saves when `save()` is called (triggered by window hide).
/// - Auto-loads when `load()` is called (triggered by window show).
/// - Data stays local. Never sent anywhere.
public final class ConversationStore {

    public static let shared = ConversationStore()

    /// The active conversation. Shared across the app.
    public let conversation = Conversation()

    private let fileName = "conversation.json"

    private init() {}

    // MARK: - File path

    /// Returns the path to the conversation JSON file in the app support directory.
    /// Creates the directory if it doesn't exist.
    private var filePath: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            NSLog("ConversationStore: Could not locate Application Support directory")
            return nil
        }

        let appDir = appSupport.appendingPathComponent("com.aidaemon", isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: appDir.path) {
            do {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                NSLog("ConversationStore: Failed to create app support directory: %@", error.localizedDescription)
                return nil
            }
        }

        return appDir.appendingPathComponent(fileName)
    }

    // MARK: - Save

    /// Save the current conversation to disk. Call when the window hides.
    public func save() {
        guard let path = filePath else { return }

        let messages = conversation.messages
        guard !messages.isEmpty else {
            // If conversation is empty, remove the file
            try? FileManager.default.removeItem(at: path)
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(messages)
            try data.write(to: path, options: .atomic)
            NSLog("ConversationStore: Saved %d messages", messages.count)
        } catch {
            NSLog("ConversationStore: Save failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Load

    /// Load the conversation from disk. Call when the window shows.
    /// If no saved data exists, the conversation stays empty.
    public func load() {
        guard let path = filePath else { return }

        guard FileManager.default.fileExists(atPath: path.path) else {
            NSLog("ConversationStore: No saved conversation found")
            return
        }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([Message].self, from: data)

            // Replace current conversation contents
            conversation.clearHistory()
            for msg in messages {
                conversation.addMessage(msg)
            }
            NSLog("ConversationStore: Loaded %d messages", messages.count)
        } catch {
            NSLog("ConversationStore: Load failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Clear

    /// Clear conversation and remove saved file.
    public func clearAll() {
        conversation.clearHistory()
        if let path = filePath {
            try? FileManager.default.removeItem(at: path)
        }
        NSLog("ConversationStore: Cleared all conversation data")
    }
}
