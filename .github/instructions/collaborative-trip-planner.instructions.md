---
description: "Use khi thiết kế/triển khai Collaborative Trip Planner (lên kế hoạch du lịch nhóm): không cần tài khoản, realtime collaboration, iOS App Intents/Share to Trip, thả link & pin vị trí, bình chọn, affiliate monetization, PDF/offline export."
applyTo:
  - "ios/**/*.swift"
  - "ios/**/*.plist"
  - "docs/**/*.md"
---
# Collaborative Trip Planner — Hướng dẫn sản phẩm

## Mục tiêu (north-star)
- Tạo một không gian chia sẻ **nhanh, gọn**, giúp gia đình/nhóm bạn lên kế hoạch chuyến đi chung **không cần thiết lập tài khoản**.
- Luôn ưu tiên UX tối giản nhưng đủ chuỗi giá trị: **share → thả gợi ý → vote → chốt kế hoạch → export/offline**.

## Ràng buộc bắt buộc (không được phá)
- **Không bắt đăng nhập/đăng ký**: tạo/join trip không được yêu cầu sign-up/login.
- **Cộng tác mặc định**: thay đổi cần đồng bộ real-time (hoặc near real-time) giữa nhiều thiết bị.
- **Thu thập nhanh**: phải thả được (a) link đặt phòng/chuyến bay/hoạt động và (b) pin vị trí (map pin) thật nhanh.
- **Ra quyết định nhóm**: mọi gợi ý phải có cơ chế bình chọn.

## Mặc định kỹ thuật (iOS-first)
- UI: SwiftUI + system components (tránh custom theme/ màu sắc tuỳ ý).
- Realtime: ưu tiên CloudKit (không tạo tài khoản trong app; yêu cầu iCloud trên thiết bị).
- Monetization: StoreKit 2 (one-time purchase/non-consumable) cho PDF export + offline pack.

## Kỳ vọng về “Share to Trip” & capture
- Xem “Share to Trip” là entry point số 1.
- Khi làm iOS:
  - Ưu tiên tích hợp **Share Sheet** và/hoặc **App Intents** để share từ Safari/ứng dụng khác vào trip.
  - Nhận URL + title/notes (nếu có); khi phù hợp thì fetch preview metadata.
- Khi thiết kế luồng, ưu tiên **1–2 taps** từ share sheet để đưa nội dung vào một trip có sẵn.

## Mô hình domain tối thiểu (giữ lean)
- Nền tảng dữ liệu nên xoay quanh:
  - `Trip` (tên, ngày, timezone, invite link/token, settings)
  - `Member` (danh tính guest/ẩn danh; display name; gắn theo device hoặc theo link)
  - `Suggestion` (type: link/place/activity; nội dung; tác giả; timestamps)
  - `Vote` (member + suggestion + giá trị)
  - `ItineraryItem` (tuỳ chọn; cho phần kế hoạch đã chốt)
- Mọi `Suggestion` phải: có tác giả, có thời gian, và có thể vote.

## Realtime & xử lý xung đột
- Ưu tiên optimistic UI, sau đó reconcile với backend.
- Mặc định có concurrent edits; không thiết kế luồng “vỡ” khi 2 người cùng sửa.
- Nếu chưa rõ backend, đưa 2–3 lựa chọn (vd: CloudKit/Firebase/custom backend) + trade-off ngắn, rồi hỏi user chốt.

## Offline & export
- Hỗ trợ xem offline cho kế hoạch đã chốt (cache local).
- Phần trả phí one-time có thể mở khoá: **PDF export** và gói offline đầy đủ hơn.

## Kiếm tiền (affiliate + commerce)
- Tracking/affiliate phải tôn trọng quyền riêng tư:
  - Không thu thập PII không cần thiết.
  - Giữ nguyên URL người dùng cung cấp trừ khi bắt buộc phải redirect/tracking.
  - Nếu thêm affiliate params, tách rõ “original URL” và “tracked URL”.

## Quyền riêng tư & an toàn
- Invite link/token phải khó đoán và có thể revoke.
- Mặc định data minimization; tránh lưu thông tin nhạy cảm nếu không bắt buộc.

## Giao tiếp
- Mặc định trả lời/viết UI copy/docs bằng tiếng Việt (trừ khi user yêu cầu khác).
- Nếu đề bài thiếu ràng buộc (platform, min iOS version, backend), hãy hỏi 1–3 câu hỏi ngắn, rõ.
