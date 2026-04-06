# Collaborative Trip Planner (iOS)

Repo này chứa **requirements** + **SwiftUI source** cho app iOS “Collaborative Trip Planner”:
- Không cần tài khoản trong app
- Realtime collaboration qua CloudKit + CloudKit Sharing
- Thả link / thả pin vị trí + vote
- “Share to Trip” bằng App Intents
- One-time purchase mở khóa: PDF export + offline pack

## Tài liệu
- Requirements: `docs/requirements.md`
- Product instructions (Copilot): `.github/instructions/collaborative-trip-planner.instructions.md`

## Cách chạy (Xcode)
> Bạn cần macOS + Xcode để build iOS app.

1) Tạo project mới trong Xcode
- iOS → App
- Interface: **SwiftUI**
- Minimum iOS: **16.0** (hoặc cao hơn)

2) Add source code
- Kéo folder `ios/TripPlanner/` vào project (Add files to …, chọn “Copy items if needed”).

### Tuỳ chọn: Generate project bằng XcodeGen (nhanh hơn)
Nếu bạn không muốn tạo project thủ công:
1) Cài XcodeGen (macOS): `brew install xcodegen`
2) Tạo project:
	- `cd ios`
	- `xcodegen generate`
3) Mở `ios/TripPlanner.xcodeproj`

Bạn có thể sửa bundle id/team tại `ios/project.yml`.

## Chạy thử (CI trên GitHub Actions)
Repo đã có workflow build iOS bằng macOS runner:
- `.github/workflows/ios-build.yml`

Cách dùng:
1) Push repo lên GitHub
2) Vào tab **Actions** → chạy workflow “iOS Build (XcodeGen)” (hoặc nó tự chạy khi push/PR)

Workflow sẽ: `xcodegen generate` → `xcodebuild` (Simulator) với `CODE_SIGNING_ALLOWED=NO`.

## Chạy thử (CLI trên macOS)
Sau khi có `TripPlanner.xcodeproj` (bằng XcodeGen):
- `cd ios`
- `xcodebuild -project TripPlanner.xcodeproj -scheme TripPlanner -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build`

3) Bật Capability: iCloud (CloudKit)
- Target → Signing & Capabilities → **+ Capability** → iCloud
- Tick **CloudKit**
- Chọn container (default container là được).

4) CloudKit schema (record types)
App dùng các record types/fields theo `ios/TripPlanner/Storage/CloudKitService.swift`:
- `TPTrip`: `tripId`, `title`, `startDate`, `endDate`, `createdAt`, `finalizedAt`
- `TPSuggestion`: `tripId`, `suggestionId`, `kind`, `createdAt`, `createdBy`, `originalURL`, `trackedURL`, `linkTitle`, `note`, `placeName`, `latitude`, `longitude`, `address`
- `TPVote`: `tripId`, `suggestionId`, `memberId`, `isUpvoted`, `updatedAt`

5) Share trip (mời người khác)
- Trong màn Trip, nút `person.2` sẽ mở **UICloudSharingController**.
- Người nhận mở link share → iOS sẽ gọi vào app qua `application(_:userDidAcceptCloudKitShareWith:)`.

6) One-time purchase (PDF + offline)
- Sửa product id tại `ios/TripPlanner/Purchases/PurchaseManager.swift` (`unlockProductId`).
- Để test local: tạo StoreKit Configuration file trong Xcode và gắn vào scheme.

7) “Share to Trip” (App Intents)
- App Intent nằm ở `ios/TripPlanner/Intents/ShareToTripIntent.swift`.
- Mở Shortcuts để tìm action “Share to Trip”; có thể pin vào Share Sheet (tuỳ iOS).

## Tuỳ chọn: App Group để Intent & app dùng chung storage
Mặc định app lưu local data ở Documents. Nếu bạn muốn đảm bảo App Intents/extension và app đọc/ghi cùng một nơi:
- Bật Capability **App Groups**
- Đặt group identifier vào `ios/TripPlanner/Storage/LocalJSONStore.swift` (`AppConfig.appGroupIdentifier`).

## Ghi chú
- Nếu thiết bị không đăng nhập iCloud, app vẫn lưu local, nhưng tính năng realtime/share trip sẽ không hoạt động.

## Realtime (push-based + fallback)
Mặc định app sẽ:
- Tạo **CKRecordZoneSubscription** cho mỗi trip (zone `trip_<UUID>`) để nhận silent push khi có thay đổi.
- Khi đang mở màn Trip, app vẫn có polling nhẹ (fallback) để dev/test dễ hơn.

Để nhận silent push CloudKit đúng cách:
1) Target → Signing & Capabilities → **+ Capability** → Background Modes
	- Tick **Remote notifications**
2) Target → Signing & Capabilities
	- Đảm bảo iCloud/CloudKit đã bật (mục 3)

Lưu ý: push có thể phụ thuộc vào môi trường thiết bị thật + cấu hình entitlement; polling fallback giúp app vẫn sync được trong nhiều tình huống.
