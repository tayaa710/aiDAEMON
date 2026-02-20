import Foundation

// MARK: - Risk Level

/// Classifies how risky a tool action is to execute.
/// Maps to the risk classification matrix in 02-THREAT-MODEL.md.
public enum RiskLevel: String, Codable {
    /// Read-only or completely benign — no confirmation needed at autonomy level 1+.
    case safe
    /// Modifies state but reversible — needs confirmation at level 0, scoped auto at level 2+.
    case caution
    /// Destructive or irreversible — ALWAYS needs confirmation regardless of autonomy level.
    case dangerous
}

// MARK: - Permission Type

/// macOS permissions a tool may require.
public enum PermissionType: String, Codable {
    case accessibility
    case automation
    case microphone
    case screenRecording
}

// MARK: - Parameter Type

/// Supported types for tool parameters.
public enum ParameterType: Codable, Equatable {
    case string
    case int
    case bool
    case double
    /// An enumeration of allowed string values.
    case enumeration([String])

    // MARK: - Codable conformance for enum with associated values

    private enum CodingKeys: String, CodingKey {
        case type, values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try container.decode(String.self, forKey: .type)
        switch typeName {
        case "string": self = .string
        case "int": self = .int
        case "bool": self = .bool
        case "double": self = .double
        case "enum":
            let values = try container.decode([String].self, forKey: .values)
            self = .enumeration(values)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                    debugDescription: "Unknown parameter type: \(typeName)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string: try container.encode("string", forKey: .type)
        case .int: try container.encode("int", forKey: .type)
        case .bool: try container.encode("bool", forKey: .type)
        case .double: try container.encode("double", forKey: .type)
        case .enumeration(let values):
            try container.encode("enum", forKey: .type)
            try container.encode(values, forKey: .values)
        }
    }
}

// MARK: - Tool Parameter

/// Defines a single parameter for a tool.
public struct ToolParameter {
    public let name: String
    public let type: ParameterType
    public let description: String
    public let required: Bool

    public init(name: String, type: ParameterType, description: String, required: Bool = true) {
        self.name = name
        self.type = type
        self.description = description
        self.required = required
    }
}

// MARK: - Tool Definition

/// Schema describing a tool the assistant can use.
/// The orchestrator reads these to build planning prompts and validate tool calls.
public struct ToolDefinition {
    public let id: String
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]
    public let riskLevel: RiskLevel
    public let requiredPermissions: [PermissionType]

    public init(id: String, name: String, description: String,
                parameters: [ToolParameter], riskLevel: RiskLevel,
                requiredPermissions: [PermissionType] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.parameters = parameters
        self.riskLevel = riskLevel
        self.requiredPermissions = requiredPermissions
    }
}

// MARK: - Tool Call

/// A parsed tool invocation from model output — tool ID + arguments.
public struct ToolCall {
    public let toolId: String
    public let arguments: [String: Any]

    public init(toolId: String, arguments: [String: Any] = [:]) {
        self.toolId = toolId
        self.arguments = arguments
    }
}

// MARK: - Validation Result

/// Outcome of validating a ToolCall against its ToolDefinition schema.
public enum ToolValidationResult {
    case valid
    case invalid(reason: String)
}

// MARK: - Tool Definitions for Existing Executors

extension ToolDefinition {

    /// APP_OPEN tool schema
    static let appOpen = ToolDefinition(
        id: "app_open",
        name: "Open Application",
        description: "Opens an application by name or a URL in the default browser.",
        parameters: [
            ToolParameter(name: "target", type: .string,
                          description: "The app name (e.g. 'Safari') or URL (e.g. 'https://google.com') to open.")
        ],
        riskLevel: .safe
    )

    /// FILE_SEARCH tool schema
    static let fileSearch = ToolDefinition(
        id: "file_search",
        name: "Search Files",
        description: "Searches for files on the Mac using Spotlight. Returns matching file paths ranked by relevance.",
        parameters: [
            ToolParameter(name: "query", type: .string,
                          description: "The search term (e.g. 'tax return', 'resume pdf')."),
            ToolParameter(name: "kind", type: .enumeration(["pdf", "image", "video", "audio", "text", "folder", "app"]),
                          description: "Optional file type filter.", required: false),
            ToolParameter(name: "date", type: .string,
                          description: "Optional date filter (e.g. '2024', 'last week').", required: false)
        ],
        riskLevel: .safe
    )

    /// WINDOW_MANAGE tool schema
    static let windowManage = ToolDefinition(
        id: "window_manage",
        name: "Manage Window",
        description: "Moves or resizes a window to a specified position on screen.",
        parameters: [
            ToolParameter(name: "target", type: .string,
                          description: "The app whose window to manage, or 'frontmost' for the active window.", required: false),
            ToolParameter(name: "position", type: .enumeration([
                "left_half", "right_half", "top_half", "bottom_half",
                "full_screen", "center", "top_left", "top_right", "bottom_left", "bottom_right"
            ]),
                          description: "The screen position to move the window to.")
        ],
        riskLevel: .safe,
        requiredPermissions: [.accessibility]
    )

    /// SYSTEM_INFO tool schema
    static let systemInfo = ToolDefinition(
        id: "system_info",
        name: "System Information",
        description: "Retrieves system information such as battery level, disk space, IP address, etc.",
        parameters: [
            ToolParameter(name: "target", type: .enumeration([
                "ip_address", "disk_space", "cpu_usage", "battery", "battery_time",
                "memory", "hostname", "os_version", "uptime"
            ]),
                          description: "The type of system information to retrieve.")
        ],
        riskLevel: .safe
    )

    /// SCREEN_CAPTURE tool schema
    static let screenCapture = ToolDefinition(
        id: "screen_capture",
        name: "Screen Capture",
        description: "Captures the screen (full display, app window, or region) and analyzes it with vision.",
        parameters: [
            ToolParameter(
                name: "mode",
                type: .enumeration(["full", "window", "region"]),
                description: "Capture mode: full display, a specific app window, or a rectangular region.",
                required: false
            ),
            ToolParameter(
                name: "app",
                type: .string,
                description: "App name when mode is 'window' (for example: 'Safari').",
                required: false
            ),
            ToolParameter(
                name: "x",
                type: .int,
                description: "Region origin X coordinate in screen points (mode='region').",
                required: false
            ),
            ToolParameter(
                name: "y",
                type: .int,
                description: "Region origin Y coordinate in screen points (mode='region').",
                required: false
            ),
            ToolParameter(
                name: "width",
                type: .int,
                description: "Region width in screen points (mode='region').",
                required: false
            ),
            ToolParameter(
                name: "height",
                type: .int,
                description: "Region height in screen points (mode='region').",
                required: false
            ),
            ToolParameter(
                name: "prompt",
                type: .string,
                description: "Optional vision instruction (for example: 'Describe this screen').",
                required: false
            )
        ],
        riskLevel: .caution,
        requiredPermissions: [.screenRecording]
    )

    /// MOUSE_CLICK tool schema
    static let mouseClick = ToolDefinition(
        id: "mouse_click",
        name: "Mouse Click",
        description: "Moves the mouse cursor to a screen coordinate and performs a click action.",
        parameters: [
            ToolParameter(
                name: "x",
                type: .int,
                description: "Target X coordinate in global screen space.",
                required: true
            ),
            ToolParameter(
                name: "y",
                type: .int,
                description: "Target Y coordinate in global screen space.",
                required: true
            ),
            ToolParameter(
                name: "clickType",
                type: .enumeration(["single", "double", "right"]),
                description: "Type of click to perform. Defaults to `single`.",
                required: false
            )
        ],
        riskLevel: .caution,
        requiredPermissions: [.accessibility]
    )

    /// KEYBOARD_TYPE tool schema
    static let keyboardType = ToolDefinition(
        id: "keyboard_type",
        name: "Keyboard Type",
        description: "Types text into the currently focused field using keyboard events.",
        parameters: [
            ToolParameter(
                name: "text",
                type: .string,
                description: "Text to type (maximum 2000 characters; control characters are stripped).",
                required: true
            )
        ],
        riskLevel: .caution,
        requiredPermissions: [.accessibility]
    )

    /// KEYBOARD_SHORTCUT tool schema
    static let keyboardShortcut = ToolDefinition(
        id: "keyboard_shortcut",
        name: "Keyboard Shortcut",
        description: "Presses a keyboard shortcut such as cmd+c, cmd+v, cmd+a, return, escape, or tab.",
        parameters: [
            ToolParameter(
                name: "shortcut",
                type: .string,
                description: "Shortcut string to press (for example: 'cmd+c', 'return', 'escape', 'tab').",
                required: true
            )
        ],
        riskLevel: .caution,
        requiredPermissions: [.accessibility]
    )

    /// COMPUTER_ACTION tool schema — high-level computer control that chains
    /// screenshot → vision → mouse/keyboard → verify into a single call.
    static let computerAction = ToolDefinition(
        id: "computer_action",
        name: "Computer Action",
        description: "Performs a GUI interaction: captures the screen, uses vision to find the target element, clicks/types at its coordinates, then captures again to verify success. Returns the ACTUAL result including whether it succeeded or failed — read the result carefully. Use for clicking buttons, links, menus, or typing into fields. If it reports failure, try a different approach.",
        parameters: [
            ToolParameter(
                name: "action",
                type: .string,
                description: "Plain-English description of the action to perform (e.g., 'click the Compose button in Gmail', 'type hello world in the search field', 'right-click the file icon').",
                required: true
            )
        ],
        riskLevel: .caution,
        requiredPermissions: [.screenRecording, .accessibility]
    )
}

// MARK: - Debug Tests

#if DEBUG
extension ToolDefinition {
    public static func runTests() {
        print("\nRunning ToolDefinition tests...")
        var passed = 0
        var failed = 0

        // Test 1: All built-in tool definitions have valid IDs
        do {
            let tools: [ToolDefinition] = [
                .appOpen,
                .fileSearch,
                .windowManage,
                .systemInfo,
                .screenCapture,
                .mouseClick,
                .keyboardType,
                .keyboardShortcut,
                .computerAction
            ]
            let ids = Set(tools.map { $0.id })
            if ids.count == 9 && ids.contains("app_open") && ids.contains("file_search")
                && ids.contains("window_manage") && ids.contains("system_info")
                && ids.contains("screen_capture") && ids.contains("mouse_click")
                && ids.contains("keyboard_type") && ids.contains("keyboard_shortcut")
                && ids.contains("computer_action") {
                print("  ✅ Test 1: All built-in tools have unique valid IDs (including computer_action)")
                passed += 1
            } else {
                print("  ❌ Test 1: Built-in tool IDs are wrong: \(ids)")
                failed += 1
            }
        }

        // Test 2: app_open has 1 required parameter
        do {
            let params = ToolDefinition.appOpen.parameters
            if params.count == 1 && params[0].name == "target" && params[0].required {
                print("  ✅ Test 2: app_open has 1 required 'target' parameter")
                passed += 1
            } else {
                print("  ❌ Test 2: app_open parameters are wrong")
                failed += 1
            }
        }

        // Test 3: file_search has optional parameters
        do {
            let optionals = ToolDefinition.fileSearch.parameters.filter { !$0.required }
            if optionals.count == 2 {
                print("  ✅ Test 3: file_search has 2 optional parameters")
                passed += 1
            } else {
                print("  ❌ Test 3: Expected 2 optional params, got \(optionals.count)")
                failed += 1
            }
        }

        // Test 4: window_manage requires accessibility permission
        do {
            if ToolDefinition.windowManage.requiredPermissions.contains(.accessibility) {
                print("  ✅ Test 4: window_manage requires accessibility permission")
                passed += 1
            } else {
                print("  ❌ Test 4: window_manage should require accessibility")
                failed += 1
            }
        }

        // Test 5: RiskLevel is correct for each tool
        do {
            let allSafe = [ToolDefinition.appOpen, .fileSearch, .windowManage, .systemInfo]
                .allSatisfy { $0.riskLevel == .safe }
            let cautionTools = [ToolDefinition.screenCapture, .mouseClick, .keyboardType, .keyboardShortcut, .computerAction]
                .allSatisfy { $0.riskLevel == .caution }
            if allSafe && cautionTools {
                print("  ✅ Test 5: Risk levels are correct (screen/mouse/keyboard/computerAction tools are .caution)")
                passed += 1
            } else {
                print("  ❌ Test 5: Tool risk levels are incorrect")
                failed += 1
            }
        }

        // Test 6: ParameterType.enumeration holds values
        do {
            let positionParam = ToolDefinition.windowManage.parameters.first { $0.name == "position" }
            if case .enumeration(let values) = positionParam?.type, values.contains("left_half") {
                print("  ✅ Test 6: position parameter has enumeration with 'left_half'")
                passed += 1
            } else {
                print("  ❌ Test 6: position parameter should be enum with 'left_half'")
                failed += 1
            }
        }

        // Test 7: screen_capture requires screen recording permission
        do {
            if ToolDefinition.screenCapture.requiredPermissions.contains(.screenRecording) {
                print("  ✅ Test 7: screen_capture requires .screenRecording permission")
                passed += 1
            } else {
                print("  ❌ Test 7: screen_capture should require .screenRecording")
                failed += 1
            }
        }

        // Test 8: mouse_click requires accessibility and supports clickType enum
        do {
            let hasPermission = ToolDefinition.mouseClick.requiredPermissions.contains(.accessibility)
            let clickTypeParam = ToolDefinition.mouseClick.parameters.first { $0.name == "clickType" }
            if case .enumeration(let values) = clickTypeParam?.type,
               hasPermission,
               values == ["single", "double", "right"] {
                print("  ✅ Test 8: mouse_click requires .accessibility and has clickType enum")
                passed += 1
            } else {
                print("  ❌ Test 8: mouse_click schema is incorrect")
                failed += 1
            }
        }

        // Test 9: keyboard_type and keyboard_shortcut require accessibility with correct params
        do {
            let typeParam = ToolDefinition.keyboardType.parameters.first { $0.name == "text" }
            let shortcutParam = ToolDefinition.keyboardShortcut.parameters.first { $0.name == "shortcut" }
            let typePermission = ToolDefinition.keyboardType.requiredPermissions.contains(.accessibility)
            let shortcutPermission = ToolDefinition.keyboardShortcut.requiredPermissions.contains(.accessibility)

            let typeOk: Bool
            if let typeParam {
                typeOk = typeParam.required && typeParam.type == .string
            } else {
                typeOk = false
            }

            let shortcutOk: Bool
            if let shortcutParam {
                shortcutOk = shortcutParam.required && shortcutParam.type == .string
            } else {
                shortcutOk = false
            }

            if typeOk && shortcutOk && typePermission && shortcutPermission {
                print("  ✅ Test 9: keyboard tool schemas require accessibility and string inputs")
                passed += 1
            } else {
                print("  ❌ Test 9: keyboard tool schema or permission requirements are incorrect")
                failed += 1
            }
        }

        // Test 10: computer_action requires both screenRecording and accessibility
        do {
            let perms = ToolDefinition.computerAction.requiredPermissions
            let actionParam = ToolDefinition.computerAction.parameters.first { $0.name == "action" }
            let hasScreenRecording = perms.contains(.screenRecording)
            let hasAccessibility = perms.contains(.accessibility)

            let actionOk: Bool
            if let actionParam {
                actionOk = actionParam.required && actionParam.type == .string
            } else {
                actionOk = false
            }

            if hasScreenRecording && hasAccessibility && actionOk {
                print("  ✅ Test 10: computer_action requires screenRecording + accessibility with action param")
                passed += 1
            } else {
                print("  ❌ Test 10: computer_action schema or permissions are incorrect")
                failed += 1
            }
        }

        print("\nToolDefinition results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
