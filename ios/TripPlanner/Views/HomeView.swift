import SwiftUI

struct HomeView: View {
	@EnvironmentObject private var tripStore: TripStore
	@State private var isPresentingAddTrip = false

	var body: some View {
		List {
			if tripStore.trips.isEmpty {
				Text("Chưa có trip nào")
					.foregroundStyle(.secondary)
			} else {
				ForEach(tripStore.trips) { trip in
					NavigationLink(value: trip.id) {
						VStack(alignment: .leading, spacing: 2) {
							Text(trip.title)
							if trip.finalizedAt != nil {
								Text("Đã chốt")
									.font(.footnote)
									.foregroundStyle(.secondary)
							}
						}
					}
				}
			}
		}
		.navigationTitle("Trips")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					isPresentingAddTrip = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.sheet(isPresented: $isPresentingAddTrip) {
			AddTripView()
		}
		.navigationDestination(for: UUID.self) { tripId in
			TripView(tripId: tripId)
		}
		.alert(
			"Lỗi",
			isPresented: Binding(
				get: { tripStore.activeErrorMessage != nil },
				set: { if !$0 { tripStore.activeErrorMessage = nil } }
			)
		) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(tripStore.activeErrorMessage ?? "")
		}
	}
}
