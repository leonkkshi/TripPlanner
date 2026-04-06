import Foundation

final class LocalIdentityStore {
	private let defaults: UserDefaults
	private let memberIdKey = "tp_memberId"
	private let displayNameKey = "tp_displayName"

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func currentMember() -> LocalMember {
		let memberId: UUID
		if let existing = defaults.string(forKey: memberIdKey), let uuid = UUID(uuidString: existing) {
			memberId = uuid
		} else {
			let uuid = UUID()
			defaults.set(uuid.uuidString, forKey: memberIdKey)
			memberId = uuid
		}

		let displayName: String
		if let existing = defaults.string(forKey: displayNameKey), !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			displayName = existing
		} else {
			let generated = Self.generateDefaultDisplayName()
			defaults.set(generated, forKey: displayNameKey)
			displayName = generated
		}

		return LocalMember(memberId: memberId, displayName: displayName)
	}

	func updateDisplayName(_ name: String) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		defaults.set(trimmed, forKey: displayNameKey)
	}

	private static func generateDefaultDisplayName() -> String {
		let suffix = Int.random(in: 1000...9999)
		return "Guest \(suffix)"
	}
}
