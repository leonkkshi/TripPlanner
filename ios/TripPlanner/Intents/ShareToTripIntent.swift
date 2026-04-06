import AppIntents
import Foundation

struct ShareToTripIntent: AppIntent {
	static var title: LocalizedStringResource = "Share to Trip"
	static var description = IntentDescription("Thả link vào một trip để cả nhóm cùng vote.")
	static var openAppWhenRun: Bool {
		// Nếu có App Group thì intent có thể ghi vào storage chung mà không cần bật app.
		AppConfig.appGroupIdentifier == nil
	}

	@Parameter(title: "Trip")
	var trip: TripAppEntity

	@Parameter(title: "Link")
	var url: URL

	@Parameter(title: "Ghi chú", default: nil)
	var note: String?

	static var parameterSummary: some ParameterSummary {
		Summary("Thả \(\.$url) vào \(\.$trip)")
	}

	func perform() async throws -> some IntentResult {
		guard let tripId = UUID(uuidString: trip.id) else {
			return .result(dialog: "Không tìm thấy trip hợp lệ.")
		}

		let repository = TripRepository()
		await repository.load()
		try await repository.addLinkSuggestion(tripId: tripId, url: url, note: note)
		return .result(dialog: "Đã thêm link vào trip \(trip.title).")
	}
}
