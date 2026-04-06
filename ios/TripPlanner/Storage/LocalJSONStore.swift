import Foundation

enum AppConfig {
	/// Nếu bạn muốn Share to Trip (App Intents/extension) và app dùng chung storage,
	/// hãy cấu hình App Group trong Xcode và đặt identifier ở đây.
	static let appGroupIdentifier: String? = nil
}

struct LocalStoreSnapshot: Codable {
	var trips: [Trip]
	var suggestions: [Suggestion]
	var votes: [Vote]

	static var empty: LocalStoreSnapshot {
		LocalStoreSnapshot(trips: [], suggestions: [], votes: [])
	}
}

actor LocalJSONStore {
	private let fileURL: URL
	private let encoder: JSONEncoder
	private let decoder: JSONDecoder

	init(fileName: String = "tripplanner_store.json") {
		self.fileURL = Self.documentsDirectory().appendingPathComponent(fileName)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		self.encoder = encoder
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		self.decoder = decoder
	}

	func load() -> LocalStoreSnapshot {
		guard let data = try? Data(contentsOf: fileURL) else {
			return .empty
		}
		return (try? decoder.decode(LocalStoreSnapshot.self, from: data)) ?? .empty
	}

	func save(_ snapshot: LocalStoreSnapshot) throws {
		let data = try encoder.encode(snapshot)
		try data.write(to: fileURL, options: [.atomic])
	}

	private static func documentsDirectory() -> URL {
		if let groupId = AppConfig.appGroupIdentifier,
		   let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
		{
			return groupURL
		}
		return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
}
