import AppKit
import Carbon.HIToolbox

/// A system-wide shortcut (⌃⌥K) that opens the ring for the files selected in Finder.
/// Carbon hot keys need no Accessibility permission; reading Finder's selection asks once
/// for permission to control Finder.
final class Hotkey {
    static let shared = Hotkey()
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    static let display = "⌃⌥K"

    func setEnabled(_ on: Bool) {
        on ? register() : unregister()
    }

    private func register() {
        guard ref == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { Hotkey.openForFinderSelection() }
            return noErr
        }, 1, &spec, nil, &handler)
        let id = EventHotKeyID(signature: OSType(0x4B514B54), id: 1) // "KQKT"
        RegisterEventHotKey(UInt32(kVK_ANSI_K), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
    }

    private func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
    }

    static func openForFinderSelection() {
        let script = """
        tell application "Finder"
            set out to ""
            repeat with f in (get selection as alias list)
                set out to out & POSIX path of f & linefeed
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        let paths = (result?.stringValue ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard !paths.isEmpty else {
            ToastCenter.shared.showInfo(L("Select some files in Finder first"), detail: L("Then press %@ to open the ring.", display))
            return
        }
        RingController.shared.show(files: paths.map { URL(fileURLWithPath: $0) }, at: NSEvent.mouseLocation, mode: .click)
    }
}
