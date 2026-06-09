import Foundation

/// Persists the key map as pretty-printed JSON in Application Support.
public struct KeyMapStore {
    public let fileURL: URL

    public init(appName: String = "XplorerRemap") {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = support
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("mapping.json")
    }

    /// Loads the saved map; falls back to Clone Hero defaults on
    /// missing/corrupt file.
    public func load() -> KeyMap {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode(KeyMap.self, from: data)
        else { return .cloneHeroDefault }
        // Backfill any controls added since the file was written.
        var merged = map
        for (control, binding) in KeyMap.cloneHeroDefault.bindings
        where merged.bindings[control] == nil {
            merged.bindings[control] = binding
        }
        return merged
    }

    public func save(_ map: KeyMap) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(map) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    public func reset() -> KeyMap {
        save(.cloneHeroDefault)
        return .cloneHeroDefault
    }
}
