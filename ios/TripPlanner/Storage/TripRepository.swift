import CloudKit
import Foundation

@MainActor
final class TripRepository {
	private let identityStore: LocalIdentityStore
	private let localStore: LocalJSONStore
	private let cloud: CloudKitService

	private(set) var snapshot: LocalStoreSnapshot = .empty

	init(
		identityStore: LocalIdentityStore = LocalIdentityStore(),
		localStore: LocalJSONStore = LocalJSONStore(),
		cloud: CloudKitService = CloudKitService()
	) {
		self.identityStore = identityStore
		self.localStore = localStore
		self.cloud = cloud
	}

	var currentMember: LocalMember {
		identityStore.currentMember()
	}

	func load() async {
		snapshot = await localStore.load()
	}

	func persist() async throws {
		try await localStore.save(snapshot)
	}

	func createTrip(title: String, startDate: Date?, endDate: Date?) async throws -> Trip {
		var trip = Trip(title: title, startDate: startDate, endDate: endDate)
		snapshot.trips.append(trip)
		try await persist()

		do {
			let ref = try await cloud.createTripIfNeeded(trip)
			trip.cloud = ref
			replaceTrip(trip)
			try await persist()
			try? await cloud.ensureZoneSubscription(tripId: trip.id, ref: ref)
		} catch {
			// Giữ local trip nếu CloudKit chưa sẵn sàng.
		}

		return trip
	}

	func addLinkSuggestion(tripId: UUID, url: URL, note: String?) async throws {
		guard let trip = snapshot.trips.first(where: { $0.id == tripId }) else { return }
		let tracked = AffiliateLink.trackedURL(for: url)
		let title = url.host
		let suggestion = Suggestion.link(
			tripId: tripId,
			createdByMemberId: currentMember.memberId,
			url: url,
			trackedURL: tracked,
			title: title,
			note: note
		)

		snapshot.suggestions.append(suggestion)
		try await persist()

		if let cloudTrip = tripWithCloud(for: tripId) {
			try? await cloud.saveSuggestion(suggestion, trip: cloudTrip)
		}
	}

	func addPlaceSuggestion(tripId: UUID, place: Suggestion.PlaceData) async throws {
		guard let trip = snapshot.trips.first(where: { $0.id == tripId }) else { return }
		let suggestion = Suggestion.place(
			tripId: tripId,
			createdByMemberId: currentMember.memberId,
			name: place.name,
			latitude: place.latitude,
			longitude: place.longitude,
			address: place.address,
			note: place.note
		)
		snapshot.suggestions.append(suggestion)
		try await persist()

		if let cloudTrip = tripWithCloud(for: tripId) {
			try? await cloud.saveSuggestion(suggestion, trip: cloudTrip)
		}
	}

	func toggleVote(tripId: UUID, suggestionId: UUID) async throws {
		guard let trip = snapshot.trips.first(where: { $0.id == tripId }) else { return }
		let memberId = currentMember.memberId
		let now = Date()

		if let index = snapshot.votes.firstIndex(where: { $0.suggestionId == suggestionId && $0.memberId == memberId }) {
			snapshot.votes[index].isUpvoted.toggle()
			snapshot.votes[index].updatedAt = now
		} else {
			snapshot.votes.append(Vote(suggestionId: suggestionId, memberId: memberId, isUpvoted: true, updatedAt: now))
		}

		try await persist()

		if let cloudTrip = tripWithCloud(for: tripId) {
			if let vote = snapshot.votes.first(where: { $0.suggestionId == suggestionId && $0.memberId == memberId }) {
				try? await cloud.saveVote(vote, trip: cloudTrip)
			}
		} else {
			_ = trip
		}
	}

	func finalizeTrip(tripId: UUID) async throws {
		guard var trip = snapshot.trips.first(where: { $0.id == tripId }) else { return }
		trip.finalizedAt = Date()
		replaceTrip(trip)
		try await persist()
		if let cloudTrip = tripWithCloud(for: tripId) {
			try? await cloud.saveTrip(cloudTrip)
		}
	}

	func enableOfflinePack(tripId: UUID) async throws {
		guard var trip = snapshot.trips.first(where: { $0.id == tripId }) else { return }
		trip.offlineEnabledAt = Date()
		replaceTrip(trip)
		try await persist()
	}

	func refreshFromCloud(tripId: UUID) async throws {
		guard let trip = tripWithCloud(for: tripId) else { return }
		guard let ref = trip.cloud else { return }
		let (remoteTrip, remoteSuggestions, remoteVotes) = try await cloud.fetchTripGraph(ref: ref)
		replaceTrip(remoteTrip)
		replaceSuggestions(for: tripId, with: remoteSuggestions)
		replaceVotes(for: tripId, with: remoteVotes)
		try await persist()
	}

	func handleAcceptedShare(_ metadata: CKShare.Metadata) async throws {
		let ref = try await cloud.acceptShare(metadata: metadata)
		let (trip, suggestions, votes) = try await cloud.fetchTripGraph(ref: ref)

		mergeTrip(trip)
		mergeSuggestions(for: trip.id, incoming: suggestions)
		mergeVotes(for: trip.id, incoming: votes)
		try await persist()
		try? await cloud.ensureZoneSubscription(tripId: trip.id, ref: ref)
	}

	func ensureRealtimeSubscriptions() async {
		for trip in snapshot.trips {
			guard let ref = trip.cloud else { continue }
			try? await cloud.ensureZoneSubscription(tripId: trip.id, ref: ref)
		}
	}

	func prepareShareSheet(tripId: UUID) async throws -> (CKShare, CKContainer) {
		guard let trip = tripWithCloud(for: tripId) else {
			throw NSError(domain: "TripPlanner", code: 10, userInfo: [NSLocalizedDescriptionKey: "Trip không tồn tại"])
		}
		return try await cloud.prepareShare(trip: trip)
	}

	// MARK: - Snapshot helpers

	private func tripWithCloud(for tripId: UUID) -> Trip? {
		snapshot.trips.first { $0.id == tripId && $0.cloud != nil }
	}

	private func replaceTrip(_ trip: Trip) {
		if let idx = snapshot.trips.firstIndex(where: { $0.id == trip.id }) {
			snapshot.trips[idx] = trip
		}
	}

	private func mergeTrip(_ trip: Trip) {
		if let idx = snapshot.trips.firstIndex(where: { $0.id == trip.id }) {
			snapshot.trips[idx] = trip
		} else {
			snapshot.trips.append(trip)
		}
	}

	private func replaceSuggestions(for tripId: UUID, with suggestions: [Suggestion]) {
		snapshot.suggestions.removeAll { $0.tripId == tripId }
		snapshot.suggestions.append(contentsOf: suggestions)
	}

	private func mergeSuggestions(for tripId: UUID, incoming: [Suggestion]) {
		var existing = snapshot.suggestions.filter { $0.tripId == tripId }
		var dict: [UUID: Suggestion] = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
		for item in incoming {
			dict[item.id] = item
		}
		snapshot.suggestions.removeAll { $0.tripId == tripId }
		snapshot.suggestions.append(contentsOf: dict.values)
	}

	private func replaceVotes(for tripId: UUID, with votes: [Vote]) {
		let suggestionIds = Set(snapshot.suggestions.filter { $0.tripId == tripId }.map { $0.id })
		snapshot.votes.removeAll { suggestionIds.contains($0.suggestionId) }
		snapshot.votes.append(contentsOf: votes)
	}

	private func mergeVotes(for tripId: UUID, incoming: [Vote]) {
		let suggestionIds = Set(incoming.map { $0.suggestionId })
		snapshot.votes.removeAll { suggestionIds.contains($0.suggestionId) }
		snapshot.votes.append(contentsOf: incoming)
	}
}
