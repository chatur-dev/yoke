import ApplicationServices
import AppKit
import Foundation

enum Focus {
    static func frontmostText() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window else { return }
        let element = window as! AXUIElement
        guard let field = findText(element, depth: 0) else { return }
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(field, kAXRaiseAction as CFString)
    }

    private static func findText(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        if depth > 8 { return nil }
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let role = role as? String,
           role == kAXTextFieldRole || role == kAXTextAreaRole || role == kAXComboBoxRole {
            return element
        }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let children = children as? [AXUIElement] else { return nil }
        for child in children {
            if let found = findText(child, depth: depth + 1) { return found }
        }
        return nil
    }
}
