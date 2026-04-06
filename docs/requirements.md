# Collaborative Trip Planner (iOS) — Requirements

Ngày: 2026-04-06

## 0) Giả định & phạm vi

### 0.1 Giả định (để triển khai ngay)
- Nền tảng: **iOS 16+** (để dùng App Intents/App Shortcuts).
- UI: **SwiftUI**, dùng **system components** + màu mặc định (không custom theme).
- Realtime collaboration: dùng **CloudKit** (không cần tạo tài khoản trong app). Người dùng cần **đăng nhập iCloud** trên thiết bị để sync.
- Monetization: **StoreKit 2**, 1 sản phẩm **non-consumable** (mua 1 lần).

### 0.2 Out of scope (làm đúng yêu cầu, không “bẻ lái”)
- Không làm web/admin.
- Không làm hệ thống tài khoản/đăng ký trong app.
- Không làm recommendation/AI.

## 1) Mục tiêu sản phẩm
- Tạo một “trip space” chia sẻ nhanh cho nhóm, nơi mọi người:
  1) thả link khách sạn/flight/hoạt động,
  2) thả pin vị trí,
  3) bình chọn,
  4) chốt kế hoạch,
  5) xuất PDF và/hoặc gói offline.
- Giảm tối đa friction: tạo/join trip không cần tài khoản.

## 2) Nhân vật sử dụng (personas)
- **Người tạo trip**: tạo trip, mời bạn bè/gia đình, tổng hợp & chốt.
- **Người tham gia**: thả gợi ý nhanh từ Safari/Apps (Share to Trip), vote.

## 3) Luồng người dùng (User journeys)

### 3.1 Tạo trip (không cần tài khoản)
- Người dùng mở app → tạo trip với tên (tùy chọn ngày đi/về).
- App tạo dữ liệu trip cục bộ và bắt đầu sync CloudKit.

### 3.2 Join trip bằng link (invite)
- Người tạo trip bấm “Chia sẻ trip” → share link.
- Người nhận mở link (deep link vào app) → thấy màn hình xác nhận join → join.

### 3.3 Thả link vào trip (Share to Trip)
- Từ Safari/app khác → Share → chạy action “Share to Trip”.
- Người dùng chọn trip → xác nhận → link được thêm vào danh sách gợi ý của trip.

### 3.4 Thả pin vị trí
- Trong trip → thêm gợi ý → chọn “Địa điểm” → tìm kiếm địa điểm → chọn → thêm.

### 3.5 Bình chọn
- Trong trip → mỗi gợi ý có nút vote (toggle) → tổng vote cập nhật cho mọi người.

### 3.6 Chốt kế hoạch
- Trong trip → bấm “Chốt kế hoạch” → app tạo danh sách “Kế hoạch đã chốt” (có thể dựa theo vote).

### 3.7 Export PDF / Offline (mua 1 lần)
- Nếu chưa mua: bấm Export → hiển thị paywall → mua 1 lần → mở khóa.
- Sau khi mở khóa:
  - Export PDF kế hoạch.
  - “Offline pack”: lưu bản kế hoạch & dữ liệu liên quan để xem khi không có mạng.

## 4) Yêu cầu chức năng (Functional requirements)

### 4.1 Trip
- Tạo trip: tên (bắt buộc), ngày đi/về (tùy chọn).
- Danh sách trips trên thiết bị.
- Xóa trip (xóa local + ngừng theo dõi sync).
- Chia sẻ trip bằng link invite.

### 4.2 Suggestion
- Thêm suggestion kiểu **Link**: URL + title (tự lấy preview nếu có) + note (tùy chọn).
- Thêm suggestion kiểu **Place**: name + coordinate (lat/lon) + address (tùy chọn) + note (tùy chọn).
- Hiển thị suggestion theo danh sách.

### 4.3 Vote
- Mỗi member (guest identity) có thể vote/unvote 1 suggestion.
- Hiển thị tổng vote.
- Xung đột vote phải được xử lý (idempotent theo member+suggestion).

### 4.4 Realtime collaboration
- Trip, suggestions, votes được sync qua CloudKit.
- Cập nhật gần real-time (push/pull) giữa các thiết bị tham gia.

### 4.5 Share to Trip (App Intents)
- Có App Intent nhận `URL` (và note tùy chọn), cho phép chọn Trip.
- Có App Shortcut để người dùng dễ thấy action “Share to Trip”.

### 4.6 Affiliate links
- Lưu **original URL**.
- Tạo **tracked URL** theo cấu hình affiliate (chỉ áp dụng domain cho phép).
- UI hiển thị link mở theo tracked URL (nếu có), nhưng luôn cho phép xem/copy original.

### 4.7 PDF export
- PDF chứa: tên trip, ngày, danh sách kế hoạch đã chốt (hoặc top suggestions), link/địa điểm, vote.

### 4.8 Offline pack
- Cho phép tải/lưu dữ liệu cần để mở xem kế hoạch khi offline.
- Trạng thái offline pack (đã sẵn sàng / đang tải / lỗi).

### 4.9 Mua 1 lần
- 1 sản phẩm non-consumable mở khóa PDF export + offline pack.
- Restore purchase.

## 5) Yêu cầu phi chức năng (Non-functional)
- **Privacy**: không thu PII, không tracking vượt mức cần thiết.
- **Security**: invite link/token khó đoán, có thể rotate/revoke.
- **Reliability**: hoạt động khi mạng chập chờn; local cache luôn là fallback.
- **Performance**: danh sách suggestion mượt; sync không block UI.

## 6) Data model (tối thiểu)

### 6.1 Local identity
- `LocalMember`:
  - `memberId: UUID`
  - `displayName: String`

### 6.2 Trip
- `Trip`:
  - `id: UUID`
  - `title: String`
  - `startDate: Date?`
  - `endDate: Date?`
  - `createdAt: Date`
  - `cloud: CloudTripRef?` (tham chiếu CloudKit)

### 6.3 Suggestion
- `Suggestion`:
  - `id: UUID`
  - `tripId: UUID`
  - `kind: link | place`
  - link: `originalUrl`, `trackedUrl`, `title`, `note`
  - place: `placeName`, `latitude`, `longitude`, `address`, `note`
  - `createdByMemberId: UUID`
  - `createdAt: Date`

### 6.4 Vote
- `Vote`:
  - `suggestionId: UUID`
  - `memberId: UUID`
  - `isUpvoted: Bool`
  - `updatedAt: Date`

## 7) Màn hình (tối thiểu)
- **Home**: danh sách trips + tạo trip.
- **Trip**: danh sách suggestions + add + vote + share invite + finalize + export.
- **Add suggestion (sheet)**: chọn loại Link/Place + form tương ứng.
- **Paywall (sheet)**: mua 1 lần + restore.

## 8) Tiêu chí nghiệm thu (Acceptance criteria)
- Tạo trip và thấy trong Home.
- Join trip qua invite link thành công.
- Share to Trip từ Safari: link xuất hiện trong trip đã chọn.
- Thêm place bằng tìm kiếm và thấy pin/địa điểm trong list.
- Vote/unvote hoạt động và tổng vote đúng.
- 2 thiết bị cùng trip: thay đổi sync qua CloudKit.
- Chưa mua: Export/Offline pack bị khóa và hiển thị paywall.
- Đã mua/restore: Export PDF tạo file chia sẻ được; offline pack báo “ready”.
