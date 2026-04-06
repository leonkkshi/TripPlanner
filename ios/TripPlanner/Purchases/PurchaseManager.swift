import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
	static let unlockProductId = "com.yourcompany.tripplanner.unlock"

	@Published private(set) var isUnlocked: Bool = false
	@Published private(set) var product: Product?
	@Published var errorMessage: String?

	init() {
		Task { await refresh() }
	}

	func refresh() async {
		await loadProduct()
		await updateEntitlements()
	}

	func purchase() async {
		errorMessage = nil
		guard let product else {
			errorMessage = "Chưa tải được thông tin sản phẩm."
			return
		}

		do {
			let result = try await product.purchase()
			switch result {
			case .success(let verificationResult):
				switch verificationResult {
				case .verified(let transaction):
					await transaction.finish()
					await updateEntitlements()
				case .unverified:
					errorMessage = "Giao dịch không hợp lệ."
				}
			case .userCancelled:
				break
			case .pending:
				errorMessage = "Giao dịch đang chờ xử lý."
			@unknown default:
				break
			}
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func restore() async {
		errorMessage = nil
		await updateEntitlements()
	}

	private func loadProduct() async {
		do {
			let products = try await Product.products(for: [Self.unlockProductId])
			product = products.first
		} catch {
			product = nil
		}
	}

	private func updateEntitlements() async {
		do {
			var unlocked = false
			for await result in Transaction.currentEntitlements {
				guard case .verified(let transaction) = result else { continue }
				if transaction.productID == Self.unlockProductId {
					unlocked = true
					break
				}
			}
			isUnlocked = unlocked
		} catch {
			isUnlocked = false
		}
	}
}
