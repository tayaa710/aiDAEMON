# 05 - Known AX Gaps

Accessibility (AX) support levels across common macOS applications. This guides the AX-first vs vision-fallback decision.

Last Updated: 2026-02-21

---

## Good AX Support

These apps expose a full, structured AX tree. `get_ui_state` + `ax_action` works reliably.

| App | Notes |
|-----|-------|
| **TextEdit** | Full AX tree. Buttons, text areas, menus all accessible. |
| **Finder** | File lists, sidebar, toolbar all in AX tree. |
| **Safari** | Chrome (toolbar, tabs, address bar) has full AX. Web page content is partially accessible via AX WebArea elements. |
| **System Settings** | All panes, toggles, and navigation elements in AX tree. |
| **Notes** | Text areas, sidebar, toolbar accessible. |
| **Mail** | Message list, compose fields, toolbar accessible. |
| **Calendar** | Events, navigation, sidebar accessible. |
| **Terminal** | Terminal content, tabs, toolbar accessible. |
| **Xcode** | Editor, navigator, toolbar, debug area accessible. Complex but well-structured. |
| **Preview** | Toolbar, page navigation accessible. Document content varies. |
| **Reminders** | Lists, items, toolbar accessible. |

**Strategy**: Use AX tools exclusively. No vision fallback needed.

---

## Partial AX Support

Some UI elements are in the AX tree, others are not.

| App | What Works | What Doesn't | Strategy |
|-----|-----------|--------------|----------|
| **Chrome** | Tabs, address bar, toolbar, bookmarks bar | Web page content (DOM is NOT in AX tree) | Use AX for Chrome UI. For web content, use CDP (M047) or vision fallback. |
| **Firefox** | Tabs, address bar, toolbar | Web page content (similar to Chrome) | Same as Chrome. |
| **Electron apps** (Slack, Discord, VS Code) | Window frame, some toolbar elements | App-specific content varies widely | Try AX first. If elements missing, fall back to vision. VS Code has good AX; Slack/Discord are mixed. |
| **Microsoft Office** (Word, Excel, PowerPoint) | Ribbon, menus, document structure | Complex formatting, embedded objects | AX for navigation and text. Vision for visual verification. |

**Strategy**: Start with AX. If the needed element isn't found, fall back to `screen_capture` + `computer_action`.

---

## Poor AX Support

Minimal or no usable AX tree. Vision fallback is the primary path.

| App | Why | Strategy |
|-----|-----|----------|
| **Games** | Custom rendering engines, no standard UI controls | Vision + mouse/keyboard only. |
| **Figma** | Canvas-based rendering, UI elements drawn as pixels | Vision + mouse/keyboard. Some toolbar elements may be in AX tree. |
| **Blender** | Custom OpenGL UI framework | Vision + mouse/keyboard only. |
| **Unity Editor** | Custom UI toolkit | Vision + mouse/keyboard only. |
| **Some Java apps** | Java AWT/Swing have inconsistent AX bridges on macOS | Try AX first, expect failures. Fall back to vision. |
| **Wine/CrossOver apps** | Windows apps running in compatibility layer | Vision + mouse/keyboard only. |

**Strategy**: Use `screen_capture` + `computer_action` as the primary interaction method. `get_ui_state` may still provide window-level information (app name, window title, size).

---

## Fallback Decision Flow

```
1. Call get_ui_state
2. Can you see the target element in the AX tree?
   YES → Use ax_action (press, set_value, focus)
   NO  → Is this a browser?
         YES → Use CDP when available (M047), else vision fallback
         NO  → Use screen_capture + computer_action (vision fallback)
3. After action, call get_ui_state again to verify
   If AX tree doesn't reflect the change → Use screen_capture to visually verify
```

---

## Notes

- AX support can change between app versions. A macOS update or app update may improve or break AX support.
- The system prompt in `Orchestrator.buildSystemPrompt()` already encodes this priority: AX first, vision fallback.
- `computer_action` in `ComputerControl.swift` implements this fallback internally: it tries the AX path first, then falls back to screenshot+vision+mouse.
