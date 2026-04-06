import CloudKit
import Foundation
import SwiftUI

@MainActor
final class TripStore: ObservableObject {
	@Published private(set) var trips: [Trip] = []
	@Published private(set) var suggestions: [Suggestion] = []
	@Published private(set) var votes: [Vote] = []
	@Published var activeErrorMessage: String?

	let repository: TripRepository
	private var shareObserver: NSObjectProtocol?
	private var zoneObserver: NSObjectProtocol?

	init(repository: TripRepository) {
		self.repository = repository
		Task { await load() }
		observeCloudKitShareAcceptance()
		observeCloudKitZoneChanges()
	}

	deinit {
		if let shareObserver {
			NotificationCenter.default.removeObserver(shareObserver)
		}
		if let zoneObserver {
			NotificationCenter.default.removeObserver(zoneObserver)
		}
	}

	var currentMember: LocalMember { repository.currentMember }

	func load() async {
		await repository.load()
		syncFromRepository()
		Task { await repository.ensureRealtimeSubscriptions() }
	}

	func createTrip(title: String, startDate: Date?, endDate: Date?) {
		Task {
			do {
				_ = try await repository.createTrip(title: title, startDate: startDate, endDate: endDate)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func addLinkSuggestion(tripId: UUID, url: URL, note: String?) {
		Task {
			do {
				try await repository.addLinkSuggestion(tripId: tripId, url: url, note: note)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func addPlaceSuggestion(tripId: UUID, place: Suggestion.PlaceData) {
		Task {
			do {
				try await repository.addPlaceSuggestion(tripId: tripId, place: place)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func toggleVote(tripId: UUID, suggestionId: UUID) {
		Task {
			do {
				try await repository.toggleVote(tripId: tripId, suggestionId: suggestionId)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func finalizeTrip(tripId: UUID) {
		Task {
			do {
				try await repository.finalizeTrip(tripId: tripId)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func refreshTripFromCloud(tripId: UUID) async {
		do {
			try await repository.refreshFromCloud(tripId: tripId)
			syncFromRepository()
		} catch {
			// Refresh nền không nên spam alert; bỏ qua lỗi để UI vẫn mượt.
		}
	}

	func enableOfflinePack(tripId: UUID) {
		Task {
			do {
				try await repository.enableOfflinePack(tripId: tripId)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	func suggestions(for tripId: UUID) -> [Suggestion] {
		suggestions.filter { $0.tripId == tripId }
	}

	func voteCount(for suggestionId: UUID) -> Int {
		votes.filter { $0.suggestionId == suggestionId && $0.isUpvoted }.count
	}

	func isUpvoted(suggestionId: UUID) -> Bool {
		votes.contains { $0.suggestionId == suggestionId && $0.memberId == currentMember.memberId && $0.isUpvoted }
	}

	func voteCountBySuggestionId(tripId: UUID) -> [UUID: Int] {
		let ids = Set(suggestions(for: tripId).map { $0.id })
		var result: [UUID: Int] = [:]
		for vote in votes where vote.isUpvoted && ids.contains(vote.suggestionId) {
			result[vote.suggestionId, default: 0] += 1
		}
		return result
	}

	private func syncFromRepository() {
		trips = repository.snapshot.trips.sorted { $0.createdAt > $1.createdAt }
		suggestions = repository.snapshot.suggestions
		votes = repository.snapshot.votes
	}

	private func observeCloudKitShareAcceptance() {
		shareObserver = NotificationCenter.default.addObserver(
			forName: .cloudKitShareAccepted,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let metadata = notification.object as? CKShare.Metadata else { return }
			self?.handleAcceptedShare(metadata)
		}
	}

	private func handleAcceptedShare(_ metadata: CKShare.Metadata) {
		Task {
			do {
				try await repository.handleAcceptedShare(metadata)
				syncFromRepository()
			} catch {
				activeErrorMessage = error.localizedDescription
			}
		}
	}

	private func observeCloudKitZoneChanges() {
		zoneObserver = NotificationCenter.default.addObserver(
			forName: .cloudKitZoneChanged,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let tripId = notification.object as? UUID else { return }
			Task { await self?.refreshTripFromCloud(tripId: tripId) }
		}
	}
}
