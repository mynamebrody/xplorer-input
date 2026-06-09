/// Display labels for macOS virtual key codes (ANSI layout).
///
/// We store raw CGKeyCodes — correct for game use, since games bind physical
/// key positions. A layout-aware upgrade would use UCKeyTranslate; the static
/// table is deliberately the simplest sane option.
public enum KeyCodeLabels {
    public static func label(for keyCode: UInt16) -> String {
        table[keyCode] ?? "Key \(keyCode)"
    }

    static let table: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
        55: "Command", 56: "Shift", 58: "Option", 59: "Control",
        60: "Right Shift", 61: "Right Option", 62: "Right Control",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        115: "Home", 116: "Page Up", 117: "Fwd Delete", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
