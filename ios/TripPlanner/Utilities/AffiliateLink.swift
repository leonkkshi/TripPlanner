import Foundation

enum AffiliateLink {
	static func trackedURL(for originalURL: URL) -> URL? {
		guard let host = originalURL.host?.lowercased() else { return nil }

		if host.contains("booking.com"), let affiliateId = AffiliateConfig.bookingDotComAffiliateId {
			return appendingQueryItem(originalURL, name: "aid", value: affiliateId)
		}

		return nil
	}

	private static func appendingQueryItem(_ url: URL, name: String, value: String) -> URL? {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
		var queryItems = components.queryItems ?? []
		queryItems.removeAll { $0.name == name }
		queryItems.append(URLQueryItem(name: name, value: value))
		components.queryItems = queryItems
		return components.url
	}
}

enum AffiliateConfig {
	/// Đặt affiliate IDs của bạn ở đây (mặc định nil để không tự ý tracking).
	static let bookingDotComAffiliateId: String? = nil
}
