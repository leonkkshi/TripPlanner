import MapKit
import SwiftUI

struct PlaceCandidate: Identifiable, Hashable {
	var id = UUID()
	var name: String
	var address: String?
	var latitude: Double
	var longitude: Double
}

struct LocationSearchView: View {
	@Binding var selected: PlaceCandidate?

	@State private var query: String = ""
	@State private var results: [PlaceCandidate] = []
	@State private var isSearching: Bool = false
	@State private var errorMessage: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 8) {
				TextField("Tìm địa điểm", text: $query)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.onSubmit { search() }

				Button("Tìm") { search() }
					.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}

			if isSearching {
				ProgressView()
			}

			if let errorMessage {
				Text(errorMessage)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			ForEach(results) { place in
				Button {
					selected = place
				} label: {
					VStack(alignment: .leading, spacing: 2) {
						Text(place.name)
						if let address = place.address {
							Text(address)
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(.vertical, 4)
	}

	private func search() {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			results = []
			return
		}
		isSearching = true
		errorMessage = nil

		Task {
			do {
				let places = try await searchPlaces(query: trimmed)
				results = places
			} catch {
				errorMessage = error.localizedDescription
				results = []
			}
			isSearching = false
		}
	}

	private func searchPlaces(query: String) async throws -> [PlaceCandidate] {
		var request = MKLocalSearch.Request()
		request.naturalLanguageQuery = query
		let response = try await MKLocalSearch(request: request).start()
		return response.mapItems.map { item in
			PlaceCandidate(
				name: item.name ?? "Địa điểm",
				address: item.placemark.title,
				latitude: item.placemark.coordinate.latitude,
				longitude: item.placemark.coordinate.longitude
			)
		}
	}
}
