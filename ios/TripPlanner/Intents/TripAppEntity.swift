import AppIntents
import Foundation

struct TripAppEntity: AppEntity, Identifiable {
	static var typeDisplayRepresentation: TypeDisplayRepresentation {
		TypeDisplayRepresentation(name: "Trip")
	}

	static var defaultQuery = TripQuery()

	var id: String
	var title: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(title)")
	}

	init(id: String, title: String) {
		self.id = id
		self.title = title
	}

	init(trip: Trip) {
		self.id = trip.id.uuidString
		self.title = trip.title
	}
}

struct TripQuery: EntityQuery {
	func entities(for identifiers: [TripAppEntity.ID]) async throws -> [TripAppEntity] {
		let store = LocalJSONStore()
		let snapshot = await store.load()
		let wanted = Set(identifiers)
		return snapshot.trips
			.filter { wanted.contains($0.id.uuidString) }
			.map(TripAppEntity.init(trip:))
	}

	func suggestedEntities() async throws -> [TripAppEntity] {
		let store = LocalJSONStore()
		let snapshot = await store.load()
		return snapshot.trips
			.sorted { $0.createdAt > $1.createdAt }
			.prefix(6)
			.map(TripAppEntity.init(trip:))
	}

	func defaultResult() async -> TripAppEntity? {
		let store = LocalJSONStore()
		let snapshot = await store.load()
		return snapshot.trips
			.sorted { $0.createdAt > $1.createdAt }
			.first
			.map(TripAppEntity.init(trip:))
	}
}
