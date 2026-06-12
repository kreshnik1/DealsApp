import Foundation
import SwiftData

enum AppModelConfiguration {
    static let models: [any PersistentModel.Type] = [
        InventoryItem.self,
        ShoppingListItem.self,
    ]

    static let sharedContainer: ModelContainer = makeSharedContainer()

    private static let schema = Schema(models)
    private static let prototypeStoreVersion = 1
    private static let prototypeStoreVersionKey = "prototype.swiftdata.store.version"
    private static let prototypeStoreFilename = "DealsAppPrototype.store"

    private static func makeSharedContainer() -> ModelContainer {
        let fileManager = FileManager.default
        let storeURL = prototypeStoreURL

        do {
            try prepareStoreDirectory(using: fileManager)
            try resetStoreIfNeeded(using: fileManager, storeURL: storeURL)

            let configuration = ModelConfiguration(url: storeURL)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            do {
                try destroyStore(at: storeURL, using: fileManager)
                let configuration = ModelConfiguration(url: storeURL)
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
            }
        }
    }

    private static var prototypeStoreURL: URL {
        prototypeStoreDirectory.appendingPathComponent(prototypeStoreFilename)
    }

    private static var prototypeStoreDirectory: URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL.documentsDirectory

        return baseDirectory.appendingPathComponent("DealsAppPrototype", isDirectory: true)
    }

    private static func prepareStoreDirectory(using fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: prototypeStoreDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func resetStoreIfNeeded(
        using fileManager: FileManager,
        storeURL: URL
    ) throws {
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: prototypeStoreVersionKey)

        guard storedVersion < prototypeStoreVersion else {
            return
        }

        try destroyStore(at: storeURL, using: fileManager)
        defaults.set(prototypeStoreVersion, forKey: prototypeStoreVersionKey)
    }

    private static func destroyStore(at storeURL: URL, using fileManager: FileManager) throws {
        for candidateURL in storeArtifactURLs(for: storeURL) {
            guard fileManager.fileExists(atPath: candidateURL.path) else {
                continue
            }

            try fileManager.removeItem(at: candidateURL)
        }
    }

    private static func storeArtifactURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal"),
        ]
    }
}
