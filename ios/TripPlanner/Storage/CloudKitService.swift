import CloudKit
import Foundation

final class CloudKitService {
	private enum RecordType {
		static let trip = "TPTrip"
		static let suggestion = "TPSuggestion"
		static let vote = "TPVote"
	}

	private enum FieldKey {
		static let tripId = "tripId"
		static let title = "title"
		static let startDate = "startDate"
		static let endDate = "endDate"
		static let createdAt = "createdAt"
		static let finalizedAt = "finalizedAt"

		static let suggestionId = "suggestionId"
		static let kind = "kind"
		static let createdBy = "createdBy"
		static let originalURL = "originalURL"
		static let trackedURL = "trackedURL"
		static let linkTitle = "linkTitle"
		static let note = "note"
		static let placeName = "placeName"
		static let latitude = "latitude"
		static let longitude = "longitude"
		static let address = "address"

		static let memberId = "memberId"
		static let isUpvoted = "isUpvoted"
		static let updatedAt = "updatedAt"
	}

	func accountStatus(containerIdentifier: String? = nil) async throws -> CKAccountStatus {
		let container = containerFor(identifier: containerIdentifier)
		return try await container.accountStatus()
	}

	func createTripIfNeeded(_ trip: Trip) async throws -> CloudTripRef {
		let container = CKContainer.default()
		let privateDB = container.privateCloudDatabase

		let zoneID = tripZoneID(tripId: trip.id, ownerName: CKCurrentUserDefaultName)
		try await ensureZoneExists(zoneID: zoneID, database: privateDB)

		let recordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)
		let record = CKRecord(recordType: RecordType.trip, recordID: recordID)
		applyTrip(trip, to: record)
		_ = try await privateDB.save(record)

		return CloudTripRef(
			containerIdentifier: nil,
			databaseScope: .privateDB,
			recordName: recordID.recordName,
			zoneName: zoneID.zoneName,
			ownerName: zoneID.ownerName
		)
	}

	func saveTrip(_ trip: Trip) async throws {
		guard let ref = trip.cloud else { return }
		let (container, database) = containerAndDatabase(for: ref)
		let recordID = CKRecord.ID(recordName: ref.recordName, zoneID: CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName))
		let record = CKRecord(recordType: RecordType.trip, recordID: recordID)
		applyTrip(trip, to: record)
		_ = try await database.save(record)
		_ = container // keep for symmetry; container chosen by ref
	}

	func saveSuggestion(_ suggestion: Suggestion, trip: Trip) async throws {
		guard let ref = trip.cloud else { return }
		let (_, database) = containerAndDatabase(for: ref)
		let zoneID = CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
		let tripRecordID = CKRecord.ID(recordName: ref.recordName, zoneID: zoneID)
		let recordID = CKRecord.ID(recordName: suggestion.id.uuidString, zoneID: zoneID)
		let record = CKRecord(recordType: RecordType.suggestion, recordID: recordID)
		record.parent = CKRecord.Reference(recordID: tripRecordID, action: .none)
		applySuggestion(suggestion, tripId: trip.id, to: record)
		_ = try await database.save(record)
	}

	func saveVote(_ vote: Vote, trip: Trip) async throws {
		guard let ref = trip.cloud else { return }
		let (_, database) = containerAndDatabase(for: ref)
		let zoneID = CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
		let tripRecordID = CKRecord.ID(recordName: ref.recordName, zoneID: zoneID)
		let recordName = "vote_\(vote.suggestionId.uuidString)_\(vote.memberId.uuidString)"
		let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
		let record = CKRecord(recordType: RecordType.vote, recordID: recordID)
		record.parent = CKRecord.Reference(recordID: tripRecordID, action: .none)
		applyVote(vote, tripId: trip.id, to: record)
		_ = try await database.save(record)
	}

	func fetchTripGraph(ref: CloudTripRef) async throws -> (Trip, [Suggestion], [Vote]) {
		let (_, database) = containerAndDatabase(for: ref)
		let zoneID = CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
		let tripRecordID = CKRecord.ID(recordName: ref.recordName, zoneID: zoneID)
		let tripRecord = try await database.record(for: tripRecordID)

		guard let tripUUID = UUID(uuidString: ref.recordName) else {
			throw NSError(domain: "TripPlanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Trip recordName is not a UUID"])
		}

		let trip = parseTrip(record: tripRecord, tripId: tripUUID, ref: ref)
		let suggestions = try await fetchSuggestions(tripId: tripUUID, zoneID: zoneID, database: database)
		let votes = try await fetchVotes(tripId: tripUUID, zoneID: zoneID, database: database)
		return (trip, suggestions, votes)
	}

	func acceptShare(metadata: CKShare.Metadata) async throws -> CloudTripRef {
		let container = CKContainer(identifier: metadata.containerIdentifier)
		try await acceptShareMetadata(container: container, metadata: metadata)

		let rootID = metadata.rootRecordID
		return CloudTripRef(
			containerIdentifier: metadata.containerIdentifier,
			databaseScope: .sharedDB,
			recordName: rootID.recordName,
			zoneName: rootID.zoneID.zoneName,
			ownerName: rootID.zoneID.ownerName
		)
	}

	func prepareShare(trip: Trip) async throws -> (CKShare, CKContainer) {
		guard let ref = trip.cloud else {
			throw NSError(domain: "TripPlanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Trip chưa được tạo trên CloudKit"])
		}
		guard ref.databaseScope == .privateDB else {
			throw NSError(domain: "TripPlanner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Chỉ owner (privateDB) mới tạo share được"])
		}

		let container = containerFor(identifier: ref.containerIdentifier)
		let database = container.privateCloudDatabase
		let zoneID = CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
		let tripRecordID = CKRecord.ID(recordName: ref.recordName, zoneID: zoneID)
		let tripRecord = try await database.record(for: tripRecordID)

		let share = CKShare(rootRecord: tripRecord)
		share.publicPermission = .readWrite
		share[CKShare.SystemFieldKey.title] = trip.title as CKRecordValue

		_ = try await database.modifyRecords(saving: [tripRecord, share], deleting: [])
		return (share, container)
	}

	func ensureZoneSubscription(tripId: UUID, ref: CloudTripRef) async throws {
		let (_, database) = containerAndDatabase(for: ref)
		let zoneID = CKRecordZone.ID(zoneName: ref.zoneName, ownerName: ref.ownerName)
		let subscriptionID = "zone_\(tripId.uuidString)"

		let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
		let info = CKSubscription.NotificationInfo()
		info.shouldSendContentAvailable = true
		subscription.notificationInfo = info

		do {
			_ = try await database.save(subscription)
		} catch {
			if let ckError = error as? CKError {
				if ckError.code == .subscriptionAlreadyExists || ckError.code == .serverRejectedRequest {
					return
				}
			}
			throw error
		}
	}

	// MARK: - Internals

	private func containerFor(identifier: String?) -> CKContainer {
		if let identifier, !identifier.isEmpty {
			return CKContainer(identifier: identifier)
		}
		return CKContainer.default()
	}

	private func containerAndDatabase(for ref: CloudTripRef) -> (CKContainer, CKDatabase) {
		let container = containerFor(identifier: ref.containerIdentifier)
		switch ref.databaseScope {
		case .privateDB:
			return (container, container.privateCloudDatabase)
		case .sharedDB:
			return (container, container.sharedCloudDatabase)
		}
	}

	private func tripZoneID(tripId: UUID, ownerName: String) -> CKRecordZone.ID {
		CKRecordZone.ID(zoneName: "trip_\(tripId.uuidString)", ownerName: ownerName)
	}

	private func ensureZoneExists(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
		do {
			_ = try await database.save(CKRecordZone(zoneID: zoneID))
		} catch {
			if let ckError = error as? CKError, ckError.code == .zoneAlreadyExists {
				return
			}
			throw error
		}
	}

	private func acceptShareMetadata(container: CKContainer, metadata: CKShare.Metadata) async throws {
		try await withCheckedThrowingContinuation { continuation in
			let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
			operation.qualityOfService = .userInitiated
			operation.perShareResultBlock = { _, result in
				switch result {
				case .success:
					break
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
			operation.acceptSharesResultBlock = { result in
				switch result {
				case .success:
					continuation.resume(returning: ())
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
			container.add(operation)
		}
	}

	private func applyTrip(_ trip: Trip, to record: CKRecord) {
		record[FieldKey.tripId] = trip.id.uuidString as CKRecordValue
		record[FieldKey.title] = trip.title as CKRecordValue
		record[FieldKey.createdAt] = trip.createdAt as CKRecordValue
		if let start = trip.startDate { record[FieldKey.startDate] = start as CKRecordValue }
		if let end = trip.endDate { record[FieldKey.endDate] = end as CKRecordValue }
		if let finalized = trip.finalizedAt { record[FieldKey.finalizedAt] = finalized as CKRecordValue }
	}

	private func applySuggestion(_ suggestion: Suggestion, tripId: UUID, to record: CKRecord) {
		record[FieldKey.tripId] = tripId.uuidString as CKRecordValue
		record[FieldKey.suggestionId] = suggestion.id.uuidString as CKRecordValue
		record[FieldKey.kind] = suggestion.kind.rawValue as CKRecordValue
		record[FieldKey.createdAt] = suggestion.createdAt as CKRecordValue
		record[FieldKey.createdBy] = suggestion.createdByMemberId.uuidString as CKRecordValue

		switch suggestion.kind {
		case .link:
			if let url = suggestion.link?.originalURL.absoluteString { record[FieldKey.originalURL] = url as CKRecordValue }
			if let tracked = suggestion.link?.trackedURL?.absoluteString { record[FieldKey.trackedURL] = tracked as CKRecordValue }
			if let title = suggestion.link?.title { record[FieldKey.linkTitle] = title as CKRecordValue }
			if let note = suggestion.link?.note { record[FieldKey.note] = note as CKRecordValue }
		case .place:
			if let name = suggestion.place?.name { record[FieldKey.placeName] = name as CKRecordValue }
			if let lat = suggestion.place?.latitude { record[FieldKey.latitude] = lat as CKRecordValue }
			if let lon = suggestion.place?.longitude { record[FieldKey.longitude] = lon as CKRecordValue }
			if let addr = suggestion.place?.address { record[FieldKey.address] = addr as CKRecordValue }
			if let note = suggestion.place?.note { record[FieldKey.note] = note as CKRecordValue }
		}
	}

	private func applyVote(_ vote: Vote, tripId: UUID, to record: CKRecord) {
		record[FieldKey.tripId] = tripId.uuidString as CKRecordValue
		record[FieldKey.suggestionId] = vote.suggestionId.uuidString as CKRecordValue
		record[FieldKey.memberId] = vote.memberId.uuidString as CKRecordValue
		record[FieldKey.isUpvoted] = (vote.isUpvoted ? 1 : 0) as CKRecordValue
		record[FieldKey.updatedAt] = vote.updatedAt as CKRecordValue
	}

	private func fetchSuggestions(tripId: UUID, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [Suggestion] {
		let predicate = NSPredicate(format: "%K == %@", FieldKey.tripId, tripId.uuidString)
		let query = CKQuery(recordType: RecordType.suggestion, predicate: predicate)
		let records = try await queryAll(query: query, zoneID: zoneID, database: database)
		return records.compactMap { parseSuggestion(record: $0, tripId: tripId) }
	}

	private func fetchVotes(tripId: UUID, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [Vote] {
		let predicate = NSPredicate(format: "%K == %@", FieldKey.tripId, tripId.uuidString)
		let query = CKQuery(recordType: RecordType.vote, predicate: predicate)
		let records = try await queryAll(query: query, zoneID: zoneID, database: database)
		return records.compactMap { parseVote(record: $0) }
	}

	private func queryAll(query: CKQuery, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
		var all: [CKRecord] = []
		var cursor: CKQueryOperation.Cursor?

		let (firstResults, firstCursor) = try await database.records(matching: query, inZoneWith: zoneID)
		all.append(contentsOf: firstResults.values.compactMap { try? $0.get() })
		cursor = firstCursor

		while let nextCursor = cursor {
			let (results, newCursor) = try await database.records(continuingMatchFrom: nextCursor)
			all.append(contentsOf: results.values.compactMap { try? $0.get() })
			cursor = newCursor
		}

		return all
	}

	private func parseTrip(record: CKRecord, tripId: UUID, ref: CloudTripRef) -> Trip {
		let title = record[FieldKey.title] as? String ?? "Trip"
		let startDate = record[FieldKey.startDate] as? Date
		let endDate = record[FieldKey.endDate] as? Date
		let createdAt = record[FieldKey.createdAt] as? Date ?? Date()
		let finalizedAt = record[FieldKey.finalizedAt] as? Date
		return Trip(id: tripId, title: title, startDate: startDate, endDate: endDate, createdAt: createdAt, finalizedAt: finalizedAt, cloud: ref)
	}

	private func parseSuggestion(record: CKRecord, tripId: UUID) -> Suggestion? {
		guard let idString = record[FieldKey.suggestionId] as? String, let id = UUID(uuidString: idString) else { return nil }
		let kindRaw = record[FieldKey.kind] as? String ?? SuggestionKind.link.rawValue
		let kind = SuggestionKind(rawValue: kindRaw) ?? .link
		let createdAt = record[FieldKey.createdAt] as? Date ?? Date()
		let createdByString = record[FieldKey.createdBy] as? String
		let createdBy = UUID(uuidString: createdByString ?? "") ?? UUID()

		switch kind {
		case .link:
			guard let originalString = record[FieldKey.originalURL] as? String, let originalURL = URL(string: originalString) else { return nil }
			let trackedString = record[FieldKey.trackedURL] as? String
			let trackedURL = trackedString.flatMap(URL.init(string:))
			let title = record[FieldKey.linkTitle] as? String
			let note = record[FieldKey.note] as? String
			return Suggestion(
				id: id,
				tripId: tripId,
				kind: .link,
				link: .init(originalURL: originalURL, trackedURL: trackedURL, title: title, note: note),
				place: nil,
				createdByMemberId: createdBy,
				createdAt: createdAt
			)
		case .place:
			let name = record[FieldKey.placeName] as? String ?? "Địa điểm"
			let lat = record[FieldKey.latitude] as? Double ?? 0
			let lon = record[FieldKey.longitude] as? Double ?? 0
			let address = record[FieldKey.address] as? String
			let note = record[FieldKey.note] as? String
			return Suggestion(
				id: id,
				tripId: tripId,
				kind: .place,
				link: nil,
				place: .init(name: name, latitude: lat, longitude: lon, address: address, note: note),
				createdByMemberId: createdBy,
				createdAt: createdAt
			)
		}
	}

	private func parseVote(record: CKRecord) -> Vote? {
		guard
			let suggestionString = record[FieldKey.suggestionId] as? String,
			let suggestionId = UUID(uuidString: suggestionString),
			let memberString = record[FieldKey.memberId] as? String,
			let memberId = UUID(uuidString: memberString)
		else {
			return nil
		}

		let rawUpvote = record[FieldKey.isUpvoted]
		let isUpvoted: Bool
		if let intValue = rawUpvote as? Int {
			isUpvoted = intValue != 0
		} else if let boolValue = rawUpvote as? Bool {
			isUpvoted = boolValue
		} else {
			isUpvoted = false
		}

		let updatedAt = record[FieldKey.updatedAt] as? Date ?? Date()
		return Vote(suggestionId: suggestionId, memberId: memberId, isUpvoted: isUpvoted, updatedAt: updatedAt)
	}
}
