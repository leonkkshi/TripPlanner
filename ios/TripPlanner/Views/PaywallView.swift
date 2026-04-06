import SwiftUI

struct PaywallView: View {
	@EnvironmentObject private var purchaseManager: PurchaseManager
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 16) {
				Text("Mở khóa tính năng")
					.font(.title2)
					.bold()

				Text("• Xuất PDF kế hoạch\n• Offline pack")
					.foregroundStyle(.secondary)

				if purchaseManager.isUnlocked {
					Text("Đã mở khóa")
						.foregroundStyle(.secondary)
				} else {
					if let product = purchaseManager.product {
						Text("Giá: \(product.displayPrice)")
							.foregroundStyle(.secondary)
					}

					Button("Mua 1 lần") {
						Task { await purchaseManager.purchase() }
					}
					.buttonStyle(.borderedProminent)

					Button("Restore purchase") {
						Task { await purchaseManager.restore() }
					}
				}

				if let error = purchaseManager.errorMessage {
					Text(error)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}

				Spacer()
			}
			.padding()
			.navigationTitle("Mở khóa")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Đóng") { dismiss() }
				}
			}
			.task {
				await purchaseManager.refresh()
			}
		}
	}
}
