import SwiftUI

@main
struct TripPlannerApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var tripStore = TripStore(repository: TripRepository())
	@StateObject private var purchaseManager = PurchaseManager()

	var body: some Scene {
		WindowGroup {
			NavigationStack {
				HomeView()
			}
			.environmentObject(tripStore)
			.environmentObject(purchaseManager)
		}
	}
}
