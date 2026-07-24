import Cocoa

// KeyLock - a tiny menu bar utility that blocks all keyboard input so you can
// clean your keyboard. The mouse/trackpad is never blocked, so you can always
// click the menu bar icon to unlock.

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lockMenuItem: NSMenuItem!
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isLocked = false {
        didSet { updateUI() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        lockMenuItem = NSMenuItem(title: "Lock Keyboard", action: #selector(toggleLock), keyEquivalent: "")
        lockMenuItem.target = self
        menu.addItem(lockMenuItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit KeyLock", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        updateUI()
    }

    @objc private func toggleLock() {
        if isLocked {
            unlock()
        } else {
            lock()
        }
    }

    @objc private func quit() {
        unlock()
        NSApp.terminate(nil)
    }

    private func lock() {
        guard ensureAccessibilityPermission() else { return }

        // Swallow key presses, key releases, modifier changes, and system-defined
        // events (media keys, brightness, etc.). Mouse events are untouched.
        let systemDefined = CGEventType(rawValue: 14)! // NX_SYSDEFINED
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << systemDefined.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()

            // macOS disables taps it thinks are unresponsive; re-enable so the
            // lock doesn't silently drop mid-cleaning.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = delegate.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return nil
            }

            return delegate.isLocked ? nil : Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            showAlert(
                title: "Couldn't lock the keyboard",
                text: "KeyLock needs Accessibility permission. Grant it in System Settings > Privacy & Security > Accessibility, then try again."
            )
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isLocked = true
    }

    private func unlock() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isLocked = false
    }

    private func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            return true
        }
        showAlert(
            title: "Accessibility permission needed",
            text: "To block keystrokes, KeyLock needs Accessibility access. macOS just prompted you - enable KeyLock in System Settings > Privacy & Security > Accessibility, then click Lock Keyboard again."
        )
        return false
    }

    private func updateUI() {
        let symbol = isLocked ? "lock.fill" : "keyboard"
        let description = isLocked ? "Keyboard locked" : "Keyboard unlocked"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        statusItem.button?.toolTip = isLocked ? "KeyLock - keyboard is LOCKED" : "KeyLock - keyboard is unlocked"
        lockMenuItem.title = isLocked ? "Unlock Keyboard" : "Lock Keyboard"
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.delegate = delegate
app.run()
