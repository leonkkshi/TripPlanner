import SwiftUI

struct AddSuggestionView: View {
	let tripId: UUID

	@EnvironmentObject private var tripStore: TripStore
	@Environment(\.dismiss) private var dismiss

	@State private var kind: SuggestionKind = .link

	@State private var urlString: String = ""
	@State private var linkNote: String = ""

	@State private var selectedPlace: PlaceCandidate?
	@State private var placeNote: String = ""

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Picker("Loại", selection: $kind) {
						Text("Link").tag(SuggestionKind.link)
						Text("Địa điểm").tag(SuggestionKind.place)
					}
					.pickerStyle(.segmented)
				}

				switch kind {
				case .link:
					Section("Link") {
						TextField("Dán URL", text: $urlString)
							.keyboardType(.URL)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
						TextField("Ghi chú (tuỳ chọn)", text: $linkNote, axis: .vertical)
					}
				case .place:
					Section("Địa điểm") {
						LocationSearchView(selected: $selectedPlace)
						if let selectedPlace {
							Text("Đã chọn: \(selectedPlace.name)")
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
						TextField("Ghi chú (tuỳ chọn)", text: $placeNote, axis: .vertical)
					}
				}
			}
			.navigationTitle("Thêm gợi ý")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Hủy") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Thêm") {
						addSuggestion()
					}
					.disabled(!canSubmit)
				}
			}
		}
	}

	private var canSubmit: Bool {
		switch kind {
		case .link:
			return URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
		case .place:
			return selectedPlace != nil
		}
	}

	private func addSuggestion() {
		switch kind {
		case .link:
			guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
			let note = linkNote.trimmingCharacters(in: .whitespacesAndNewlines)
			tripStore.addLinkSuggestion(tripId: tripId, url: url, note: note.isEmpty ? nil : note)
			dismiss()
		case .place:
			guard let selectedPlace else { return }
			let note = placeNote.trimmingCharacters(in: .whitespacesAndNewlines)
			let placeData = Suggestion.PlaceData(
				name: selectedPlace.name,
				latitude: selectedPlace.latitude,
				longitude: selectedPlace.longitude,
				address: selectedPlace.address,
				note: note.isEmpty ? nil : note
			)
			tripStore.addPlaceSuggestion(tripId: tripId, place: placeData)
			dismiss()
		}
	}
}
