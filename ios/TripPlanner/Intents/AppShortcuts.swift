import AppIntents

struct TripPlannerShortcuts: AppShortcutsProvider {
	static var appShortcuts: [AppShortcut] {
		[
			AppShortcut(
				intent: ShareToTripIntent(),
				phrases: [
					"Share to Trip in \(.applicationName)",
					"Thả link vào trip bằng \(.applicationName)",
				],
				shortTitle: "Share to Trip",
				systemImageName: "paperplane"
			),
		]
	}
}
