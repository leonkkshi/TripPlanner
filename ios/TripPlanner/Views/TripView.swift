import SwiftUI

struct TripView: View {
	let tripId: UUID

	@EnvironmentObject private var tripStore: TripStore
	@EnvironmentObject private var purchaseManager: PurchaseManager
	@Environment(\.openURL) private var openURL

	@State private var isPresentingAddSuggestion = false
	@State private var isPresentingPaywall = false
	@State private var isPresentingCloudShare = false
	@State private var exportedPDFURL: URL?

	private var trip: Trip? { tripStore.trips.first(where: { $0.id == tripId }) }

	var body: some View {
		Group {
			if let trip {
				List {
					Section("Gợi ý") {
						let items = tripStore.suggestions(for: tripId)
						if items.isEmpty {
							Text("Chưa có gợi ý")
								.foregroundStyle(.secondary)
						} else {
							ForEach(items) { suggestion in
								SuggestionRow(
									tripId: tripId,
									suggestion: suggestion
								)
							}
						}
					}

					Section("Kế hoạch") {
						Button("Chốt kế hoạch") {
							tripStore.finalizeTrip(tripId: tripId)
						}
						.disabled(trip.finalizedAt != nil)

						Button("Xuất PDF") {
							guard purchaseManager.isUnlocked else {
								isPresentingPaywall = true
								return
							}
							let voteCounts = tripStore.voteCountBySuggestionId(tripId: tripId)
							do {
								exportedPDFURL = try PDFExporter.exportTrip(
									trip: trip,
									suggestions: tripStore.suggestions(for: tripId),
									voteCountBySuggestionId: voteCounts
								)
							} catch {
								tripStore.activeErrorMessage = error.localizedDescription
							}
						}

						if let exportedPDFURL {
							ShareLink(item: exportedPDFURL) {
								Label("Chia sẻ PDF", systemImage: "square.and.arrow.up")
							}
						}

						Button(trip.offlineEnabledAt == nil ? "Bật offline pack" : "Offline pack: Ready") {
							guard purchaseManager.isUnlocked else {
								isPresentingPaywall = true
								return
							}
							tripStore.enableOfflinePack(tripId: tripId)
						}
						.disabled(trip.offlineEnabledAt != nil)
					}
				}
			} else {
				Text("Trip không tồn tại")
					.foregroundStyle(.secondary)
			}
		}
		.navigationTitle(trip?.title ?? "Trip")
		.toolbar {
			ToolbarItemGroup(placement: .topBarTrailing) {
				Button {
					isPresentingAddSuggestion = true
				} label: {
					Image(systemName: "plus")
				}

				Button {
					isPresentingCloudShare = true
				} label: {
					Image(systemName: "person.2")
				}
				.disabled(trip?.cloud == nil)
			}
		}
		.sheet(isPresented: $isPresentingAddSuggestion) {
			AddSuggestionView(tripId: tripId)
		}
		.sheet(isPresented: $isPresentingPaywall) {
			PaywallView()
		}
		.sheet(isPresented: $isPresentingCloudShare) {
			CloudShareSheet(tripId: tripId)
		}
		.task {
			while !Task.isCancelled {
				await tripStore.refreshTripFromCloud(tripId: tripId)
				try? await Task.sleep(nanoseconds: 10_000_000_000)
			}
		}
	}
}

private struct SuggestionRow: View {
	let tripId: UUID
	let suggestion: Suggestion

	@EnvironmentObject private var tripStore: TripStore
	@Environment(\.openURL) private var openURL

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			Button {
				tripStore.toggleVote(tripId: tripId, suggestionId: suggestion.id)
			} label: {
				VStack(spacing: 4) {
					Image(systemName: tripStore.isUpvoted(suggestionId: suggestion.id) ? "hand.thumbsup.fill" : "hand.thumbsup")
					Text("\(tripStore.voteCount(for: suggestion.id))")
						.font(.footnote)
				}
			}
			.buttonStyle(.plain)

			VStack(alignment: .leading, spacing: 4) {
				Button {
					openSuggestion()
				} label: {
					Text(primaryTitle)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
				.buttonStyle(.plain)

				if let subtitle {
					Text(subtitle)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var primaryTitle: String {
		switch suggestion.kind {
		case .link:
			return suggestion.link?.title ?? suggestion.link?.originalURL.absoluteString ?? "Link"
		case .place:
			return suggestion.place?.name ?? "Địa điểm"
		}
	}

	private var subtitle: String? {
		switch suggestion.kind {
		case .link:
			return suggestion.link?.originalURL.host
		case .place:
			return suggestion.place?.address
		}
	}

	private func openSuggestion() {
		switch suggestion.kind {
		case .link:
			let url = suggestion.link?.trackedURL ?? suggestion.link?.originalURL
			if let url { openURL(url) }
		case .place:
			guard let place = suggestion.place else { return }
			let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
			let urlString = "http://maps.apple.com/?ll=\(place.latitude),\(place.longitude)&q=\(q)"
			if let url = URL(string: urlString) { openURL(url) }
		}
	}
}
