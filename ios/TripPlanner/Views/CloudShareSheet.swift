import CloudKit
import SwiftUI
import UIKit

struct CloudShareSheet: UIViewControllerRepresentable {
	let tripId: UUID
	@EnvironmentObject private var tripStore: TripStore

	func makeCoordinator() -> Coordinator {
		Coordinator(tripTitle: tripStore.trips.first(where: { $0.id == tripId })?.title)
	}

	func makeUIViewController(context: Context) -> UICloudSharingController {
		let controller = UICloudSharingController { _, completion in
			Task {
				do {
					let (share, container) = try await tripStore.repository.prepareShareSheet(tripId: tripId)
					completion(share, container, nil)
				} catch {
					completion(nil, nil, error)
				}
			}
		}
		controller.delegate = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

	final class Coordinator: NSObject, UICloudSharingControllerDelegate {
		private let tripTitle: String?

		init(tripTitle: String?) {
			self.tripTitle = tripTitle
		}

		func itemTitle(for csc: UICloudSharingController) -> String? {
			tripTitle
		}

		func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}
		func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
		func cloudSharingController(
			_ csc: UICloudSharingController,
			failedToSaveShareWithError error: Error
		) {}
	}
}
