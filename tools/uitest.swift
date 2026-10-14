import Cocoa
// usage: ui <cmd> args...
//   bounds | move x y | click x y [cmd|shift|alt] | rclick x y | dclick x y | drag x1 y1 x2 y2 [cmd|shift|alt]
//   rdrag x1 y1 x2 y2 | scroll x y dx dy [cmd] | key <name> [cmd|shift|alt] | type <text>
// Coordinates are relative to the window's top-left. It only acts while the app under test (UI_PID) is frontmost.
// Two apps share the name "Brotherhood Canvas" (this one and the Electron build), so the target is picked by pid.
guard let targetPid = Int32(ProcessInfo.processInfo.environment["UI_PID"] ?? "") else { print("set UI_PID to the pid of the app under test"); exit(3) }
let appName = "Brotherhood Canvas"
func win() -> CGRect? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == targetPid {
        if let b = w[kCGWindowBounds as String] as? [String: CGFloat], (b["Height"] ?? 0) > 300 {
            return CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
        }
    }
    return nil
}
guard let b = win() else { print("no window"); exit(1) }
let a = CommandLine.arguments
// Never send synthetic input to another app: the target must be frontmost.
if NSWorkspace.shared.frontmostApplication?.processIdentifier != targetPid && a[1] != "bounds" {
    print("ABORT: front app is", NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"); exit(2)
}
func flags(_ s: String?) -> CGEventFlags { s == "cmd" ? .maskCommand : s == "shift" ? .maskShift : s == "alt" ? .maskAlternate : [] }
func mouse(_ t: CGEventType, _ x: CGFloat, _ y: CGFloat, _ f: CGEventFlags = [], clicks: Int64 = 1, button: CGMouseButton = .left) {
    let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGPoint(x: b.minX + x, y: b.minY + y), mouseButton: button)
    e?.flags = f; e?.setIntegerValueField(.mouseEventClickState, value: clicks); e?.post(tap: .cghidEventTap)
}
func num(_ i: Int) -> CGFloat { CGFloat(Double(a[i])!) }
let codes: [String: CGKeyCode] = ["a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "bracketr": 30, "o": 31, "u": 32, "bracketl": 33, "i": 34, "p": 35,
    "return": 36, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "tab": 48, "space": 49, "delete": 51, "esc": 53, "left": 123, "right": 124, "down": 125, "up": 126, " ": 49]
func key(_ code: CGKeyCode, _ f: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    let d = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true); d?.flags = f; d?.post(tap: .cghidEventTap)
    usleep(40_000)
    let u = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false); u?.flags = f; u?.post(tap: .cghidEventTap)
    usleep(30_000)
}
func dragPath(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ f: CGEventFlags, _ down: CGEventType, _ drag: CGEventType, _ up: CGEventType, _ btn: CGMouseButton) {
    mouse(.mouseMoved, x1, y1); usleep(150_000); mouse(down, x1, y1, f, button: btn); usleep(100_000)
    let n = 24
    for i in 1...n { let t = CGFloat(i) / CGFloat(n); mouse(drag, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, f, button: btn); usleep(20_000) }
    usleep(120_000); mouse(up, x2, y2, f, button: btn)
}
switch a[1] {
case "bounds": print(b)
case "move": mouse(.mouseMoved, num(2), num(3))
case "click":
    let f = flags(a.count > 4 ? a[4] : nil)
    mouse(.mouseMoved, num(2), num(3)); usleep(150_000); mouse(.leftMouseDown, num(2), num(3), f); usleep(60_000); mouse(.leftMouseUp, num(2), num(3), f)
case "rclick":
    mouse(.mouseMoved, num(2), num(3)); usleep(150_000); mouse(.rightMouseDown, num(2), num(3), [], button: .right); usleep(60_000); mouse(.rightMouseUp, num(2), num(3), [], button: .right)
case "dclick":
    mouse(.mouseMoved, num(2), num(3)); usleep(150_000)
    mouse(.leftMouseDown, num(2), num(3)); usleep(40_000); mouse(.leftMouseUp, num(2), num(3))
    usleep(80_000)
    mouse(.leftMouseDown, num(2), num(3), [], clicks: 2); usleep(40_000); mouse(.leftMouseUp, num(2), num(3), [], clicks: 2)
case "drag":
    dragPath(num(2), num(3), num(4), num(5), flags(a.count > 6 ? a[6] : nil), .leftMouseDown, .leftMouseDragged, .leftMouseUp, .left)
case "rdrag":
    dragPath(num(2), num(3), num(4), num(5), [], .rightMouseDown, .rightMouseDragged, .rightMouseUp, .right)
case "scroll":
    mouse(.mouseMoved, num(2), num(3)); usleep(120_000)
    let f = flags(a.count > 6 ? a[6] : nil)
    for _ in 0..<8 {
        let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(Double(a[5])! / 8), wheel2: Int32(Double(a[4])! / 8), wheel3: 0)
        e?.flags = f; e?.post(tap: .cghidEventTap); usleep(25_000)
    }
case "key":
    key(codes[a[2]]!, flags(a.count > 3 ? a[3] : nil))
case "type":
    for ch in a[2].lowercased() { if let c = codes[String(ch)] { key(c, []) } }
default: print("?")
}
