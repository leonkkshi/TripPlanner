import SwiftUI

struct AddTripView: View {
	@EnvironmentObject private var tripStore: TripStore
	@Environment(\.dismiss) private var dismiss

	@State private var title: String = ""
	@State private var includeDates: Bool = false
	@State private var startDate: Date = Date()
	@State private var endDate: Date = Date()

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Tên trip", text: $title)
					Toggle("Có ngày đi/về", isOn: $includeDates)
					if includeDates {
						DatePicker("Đi", selection: $startDate, displayedComponents: [.date])
						DatePicker("Về", selection: $endDate, displayedComponents: [.date])
					}
				}
			}
			.navigationTitle("Tạo trip")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Hủy") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Tạo") {
						let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
						tripStore.createTrip(
							title: trimmed,
							startDate: includeDates ? startDate : nil,
							endDate: includeDates ? endDate : nil
						)
						dismiss()
					}
					.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
		}
	}
}
