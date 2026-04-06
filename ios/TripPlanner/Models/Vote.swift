import Foundation

struct Vote: Identifiable, Codable, Hashable {
	var suggestionId: UUID
	var memberId: UUID
	var isUpvoted: Bool
	var updatedAt: Date

	var id: String { "\(suggestionId.uuidString)|\(memberId.uuidString)" }
}
