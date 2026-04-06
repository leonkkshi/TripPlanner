import CloudKit
import UIKit

extension Notification.Name {
	static let cloudKitShareAccepted = Notification.Name("TripPlanner.cloudKitShareAccepted")
	static let cloudKitZoneChanged = Notification.Name("TripPlanner.cloudKitZoneChanged")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		application.registerForRemoteNotifications()
		return true
	}

	func application(
		_ application: UIApplication,
		userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
	) {
		NotificationCenter.default.post(name: .cloudKitShareAccepted, object: cloudKitShareMetadata)
	}

	func application(
		_ application: UIApplication,
		didReceiveRemoteNotification userInfo: [AnyHashable: Any],
		fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
	) {
		guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
			completionHandler(.noData)
			return
		}

		if let zoneNotification = notification as? CKRecordZoneNotification,
		   let zoneName = zoneNotification.recordZoneID?.zoneName,
		   zoneName.hasPrefix("trip_")
		{
			let uuidString = String(zoneName.dropFirst("trip_".count))
			if let tripId = UUID(uuidString: uuidString) {
				NotificationCenter.default.post(name: .cloudKitZoneChanged, object: tripId)
				completionHandler(.newData)
				return
			}
		}

		completionHandler(.noData)
	}
}
