import Foundation

enum CloudDatabaseScope: String, Codable, Hashable {
	case privateDB
	case sharedDB
}

struct CloudTripRef: Codable, Hashable {
	var containerIdentifier: String?
	var databaseScope: CloudDatabaseScope
	var recordName: String
	var zoneName: String
	var ownerName: String

	init(
		containerIdentifier: String? = nil,
		databaseScope: CloudDatabaseScope,
		recordName: String,
		zoneName: String,
		ownerName: String
	) {
		self.containerIdentifier = containerIdentifier
		self.databaseScope = databaseScope
		self.recordName = recordName
		self.zoneName = zoneName
		self.ownerName = ownerName
	}
}

struct Trip: Identifiable, Codable, Hashable {
	var id: UUID
	var title: String
	var startDate: Date?
	var endDate: Date?
	var createdAt: Date
	var finalizedAt: Date?
	var offlineEnabledAt: Date?
	var cloud: CloudTripRef?

	init(
		id: UUID = UUID(),
		title: String,
		startDate: Date? = nil,
		endDate: Date? = nil,
		createdAt: Date = Date(),
		finalizedAt: Date? = nil,
		offlineEnabledAt: Date? = nil,
		cloud: CloudTripRef? = nil
	) {
		self.id = id
		self.title = title
		self.startDate = startDate
		self.endDate = endDate
		self.createdAt = createdAt
		self.finalizedAt = finalizedAt
		self.offlineEnabledAt = offlineEnabledAt
		self.cloud = cloud
	}
}
