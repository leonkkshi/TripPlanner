import Foundation
import UIKit

enum PDFExporter {
	static func exportTrip(
		trip: Trip,
		suggestions: [Suggestion],
		voteCountBySuggestionId: [UUID: Int]
	) throws -> URL {
		let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @ 72dpi
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

		let fileName = sanitizedFileName("Trip_\(trip.title)") + ".pdf"
		let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

		let data = renderer.pdfData { context in
			context.beginPage()
			let margin: CGFloat = 36
			var cursorY: CGFloat = margin

			let titleFont = UIFont.preferredFont(forTextStyle: .title2)
			let bodyFont = UIFont.preferredFont(forTextStyle: .body)

			cursorY = drawText(
				"Kế hoạch: \(trip.title)",
				font: titleFont,
				in: CGRect(x: margin, y: cursorY, width: pageRect.width - 2 * margin, height: 80)
			) + 8

			let sorted = suggestions.sorted {
				let aVotes = voteCountBySuggestionId[$0.id] ?? 0
				let bVotes = voteCountBySuggestionId[$1.id] ?? 0
				if aVotes != bVotes { return aVotes > bVotes }
				return $0.createdAt < $1.createdAt
			}

			for suggestion in sorted {
				let votes = voteCountBySuggestionId[suggestion.id] ?? 0
				let line = summaryLine(for: suggestion, votes: votes)
				let nextY = drawText(
					line,
					font: bodyFont,
					in: CGRect(x: margin, y: cursorY, width: pageRect.width - 2 * margin, height: 200)
				) + 6

				if nextY > pageRect.height - margin {
					context.beginPage()
					cursorY = margin
				} else {
					cursorY = nextY
				}
			}
		}

		try data.write(to: outputURL, options: [.atomic])
		return outputURL
	}

	private static func summaryLine(for suggestion: Suggestion, votes: Int) -> String {
		switch suggestion.kind {
		case .link:
			let title = suggestion.link?.title ?? suggestion.link?.originalURL.host ?? suggestion.link?.originalURL.absoluteString ?? "Link"
			return "▲ \(votes)  🔗 \(title)"
		case .place:
			let name = suggestion.place?.name ?? "Địa điểm"
			return "▲ \(votes)  📍 \(name)"
		}
	}

	private static func drawText(_ text: String, font: UIFont, in rect: CGRect) -> CGFloat {
		let paragraph = NSMutableParagraphStyle()
		paragraph.lineBreakMode = .byWordWrapping
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.paragraphStyle: paragraph,
		]
		let attributed = NSAttributedString(string: text, attributes: attributes)
		let bounding = attributed.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
		attributed.draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(bounding.height)))
		return rect.minY + ceil(bounding.height)
	}

	private static func sanitizedFileName(_ input: String) -> String {
		let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
		return input.components(separatedBy: invalid).joined(separator: "_").trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
