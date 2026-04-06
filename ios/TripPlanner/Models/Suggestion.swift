import Foundation

enum SuggestionKind: String, Codable, Hashable {
	case link
	case place
}

struct Suggestion: Identifiable, Codable, Hashable {
	struct LinkData: Codable, Hashable {
		var originalURL: URL
		var trackedURL: URL?
		var title: String?
		var note: String?
	}

	struct PlaceData: Codable, Hashable {
		var name: String
		var latitude: Double
		var longitude: Double
		var address: String?
		var note: String?
	}

	var id: UUID
	var tripId: UUID
	var kind: SuggestionKind
	var link: LinkData?
	var place: PlaceData?
	var createdByMemberId: UUID
	var createdAt: Date

	static func link(
		tripId: UUID,
		createdByMemberId: UUID,
		url: URL,
		trackedURL: URL?,
		title: String?,
		note: String?
	) -> Suggestion {
		Suggestion(
			id: UUID(),
			tripId: tripId,
			kind: .link,
			link: LinkData(originalURL: url, trackedURL: trackedURL, title: title, note: note),
			place: nil,
			createdByMemberId: createdByMemberId,
			createdAt: Date()
		)
	}

	static func place(
		tripId: UUID,
		createdByMemberId: UUID,
		name: String,
		latitude: Double,
		longitude: Double,
		address: String?,
		note: String?
	) -> Suggestion {
		Suggestion(
			id: UUID(),
			tripId: tripId,
			kind: .place,
			link: nil,
			place: PlaceData(name: name, latitude: latitude, longitude: longitude, address: address, note: note),
			createdByMemberId: createdByMemberId,
			createdAt: Date()
		)
	}
}
