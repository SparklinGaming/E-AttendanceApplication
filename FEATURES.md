# 🚀 E-Attend Feature Suggestions

> Comprehensive feature roadmap for the E-Attendance mobile application.
> Organized by priority and development effort.

---

## 📋 Current Feature Inventory

### ✅ Implemented
| Feature | Role | Status |
|---------|------|--------|
| Email/Password Auth | All | ✅ Done |
| Check-In / Check-Out | Employee | ✅ Done |
| 📍 GPS Geofencing Verification | Employee | ✅ Done |
| Late Detection | Employee | ✅ Done |
| Schedule View (Shift) | Employee | ✅ Done |
| Leave Requests (Annual, Emergency, MC) | Employee | ✅ Done |
| Overtime Requests | Employee | ✅ Done |
| In-App Notifications | All | ✅ Done |
| Profile with Photo | Employee | ✅ Done |
| Weekly Work Hours Chart | Employee | ✅ Done |
| Monthly Stats (Present/Late/Absence) | Employee | ✅ Done |
| Admin Analytics Dashboard | Admin | ✅ Done |
| Employee Management (CRUD) | Admin | ✅ Done |
| Leave Approval/Rejection | Admin | ✅ Done |
| Overtime Approval/Rejection | Admin | ✅ Done |
| Shift Definitions (Pagi/Siang/Malam) | Admin | ✅ Done |
| Daily Shift Assignment | Admin | ✅ Done |
| Office Location Configuration (GPS) | Admin | ✅ Done |
| Work Timing Settings | Admin | ✅ Done |
| Working Days & Holidays Config | Admin | ✅ Done |
| CSV Export (Daily, Monthly, Leave, Full Report) | Admin | ✅ Done |
| Attendance Logs Viewer | Admin | ✅ Done |

---

## 🥇 Phase 1: Quick Wins (Low Effort, High Impact)

### 1.1 🔔 Notification Badge Count
**Problem**: Users don't know they have unread notifications without navigating to the page.
**Solution**: Show a red badge with unread count on the bell icon in the home page header.
**Effort**: ⭐ Low (widget + Firestore query)
**File**: `lib/features/home/home.dart`

### 1.2 📜 Employee Request History Page
**Problem**: Employees can submit requests but have no way to see their past requests or check approval status.
**Solution**: New page under schedule/request flow showing pending/approved/rejected requests for the logged-in user.
**Effort**: ⭐ Low (reuse existing widgets + filtering)
**File**: `lib/features/requests/request_history.dart`

### 1.3 🎨 Empty State Illustrations
**Problem**: Empty screens show bare text ("No notifications yet.", "No employees found.") with no visual guidance.
**Solution**: Add helpful illustration + CTA button for empty states (e.g., "No requests yet — tap + to create one").
**Effort**: ⭐ Low (reusable widget)
**File**: `lib/utils/empty_state_widget.dart`

### 1.4 ⏳ Shimmer Loading Effect
**Problem**: All loading states use a plain `CircularProgressIndicator` which feels basic.
**Solution**: Replace with shimmer/skeleton loading matching card layouts.
**Effort**: ⭐⭐ Medium (custom widget)
**File**: `lib/utils/shimmer_widget.dart`

### 1.5 📊 Leave Balance Indicator
**Problem**: Employees don't know how many leave days they have remaining before submitting a request.
**Solution**: Show remaining leave balance (e.g., "Annual Leave: 10/12 days remaining") on profile and request form.
**Effort**: ⭐ Low (Firestore field + display widget)
**Files**: Repository + `request_form.dart` + `profile.dart`

---

## 🥈 Phase 2: Core Enhancements (Medium Effort)

### 2.1 📍 GPS Location Verification ✅
**Problem**: Employees can check in from anywhere with no location validation.
**Solution**: Capture GPS coordinates on check-in; admin can set allowed geo-fence radius per office location.
**Effort**: ⭐⭐⭐ Medium-High
**Status**: ✅ Implemented
**Packages**: `geolocator` ^13.0.2
**Edge cases**: Denied permission, GPS off, weak signal — all handled with user-friendly error dialogs

### 2.2 📸 Selfie Verification on Check-In
**Problem**: No visual confirmation that the person checking in is actually the employee.
**Solution**: Require a selfie photo during check-in using the camera.
**Effort**: ⭐⭐⭐ Medium
**Requires**: Existing `image_picker` package, Firebase Storage
**Privacy**: Store photos temporarily, auto-delete after TTL

### 2.3 🌗 Dark Mode Support
**Problem**: App always displays in light theme with no dark mode option.
**Solution**: Add theme toggle in profile page; persist preference; follow Material 3 dark theme tokens.
**Effort**: ⭐⭐ Medium
**Files**: `main.dart` + `providers/` + settings persistence
**Benefits**: Accessibility, battery savings (AMOLED), user comfort

### 2.4 📅 Monthly Calendar Attendance View
**Problem**: Attendance history is shown as a flat list; users can't visually see their monthly pattern.
**Solution**: Calendar heatmap showing present/late/absent/leave days per month.
**Effort**: ⭐⭐⭐ Medium
**Widget**: `TableCalendar` package or custom `GridView`
**Integration**: Replace/add to profile stats section

### 2.5 🔍 Admin Search & Filter
**Problem**: Employee list and attendance logs can't be searched or filtered.
**Solution**: Add search bar to employee list (by name/email) + filter chips for attendance status.
**Effort**: ⭐⭐ Medium
**Files**: `employee_list.dart`, `attendance_records.dart`

---

## 🥉 Phase 3: Advanced Features (Higher Effort)

### 3.1 🔐 Biometric Authentication (Fingerprint/Face ID)
**Problem**: Users must type email/password every time they log in.
**Solution**: Add biometric login option using device fingerprint/face scanner.
**Effort**: ⭐⭐⭐ Medium
**Requires**: `local_auth` package
**UX**: Silently check availability → prompt on login

### 3.2 📱 QR Code Check-In
**Problem**: Manual check-in with notes is time-consuming.
**Solution**: Admin generates a dynamic QR code at office; employees scan to check in instantly.
**Effort**: ⭐⭐⭐⭐ High
**Requires**: `qr_flutter` + `mobile_scanner` packages
**Security**: QR code rotates every 30 seconds (TOTP-based)

### 3.3 🔄 Shift Swap / Trade Requests
**Problem**: Employees can't swap shifts with coworkers; only admin can reassign.
**Solution**: Allow employees to request shift swaps with peers → admin approval flow.
**Effort**: ⭐⭐⭐⭐ High
**Requires**: New collection + notification flow + approval UI

### 3.4 ⏰ Smart Check-In Reminders
**Problem**: Employees forget to check in or out, especially with shift changes.
**Solution**: Push notifications at shift start time and before shift end.
**Effort**: ⭐⭐⭐⭐ High
**Requires**: Firebase Cloud Messaging (FCM) + Cloud Functions

### 3.5 🏢 Multi-Branch / Location Support
**Problem**: All employees are treated as one group; no branch differentiation.
**Solution**: Add branch/division field to employees; admin can filter by branch; per-branch analytics.
**Effort**: ⭐⭐⭐⭐⭐ Very High
**Requires**: Data model changes + UI + Firestore restructuring

### 3.6 📅 Shift Recurrence (Weekly Pattern)
**Problem**: Admin must assign shifts daily; no recurring schedule.
**Solution**: Allow setting weekly shift patterns (e.g., "Week 1: Morning, Week 2: Afternoon").
**Effort**: ⭐⭐⭐⭐⭐ Very High
**Requires**: New scheduler logic + CRON/Cloud Function

### 3.7 📄 PDF Report Generation
**Problem**: CSV exports are good for data but not for formal reporting.
**Solution**: Generate formatted PDF reports with company logo, employee signatures, and formal layout.
**Effort**: ⭐⭐⭐ Medium-High
**Requires**: `pdf` package (Dart)

### 3.8 💰 Payroll Hours Summary
**Problem**: No integration between attendance and payroll calculations.
**Solution**: Export monthly total work hours (including overtime) in payroll-ready format.
**Effort**: ⭐⭐⭐ Medium
**Integration**: CSV/PDF export with overtime rates

---

## 🔧 Technical Debt & Refactoring

| Item | Description | Priority |
|------|-------------|----------|
| **Navigation Refactor** | Replace `pushAndRemoveUntil` with GoRouter for proper deep linking | Medium |
| **Error Handling** | Wrap Firebase calls in centralized error handler with retry logic | High |
| **Offline Support** | Cache Firestore data locally for offline check-in capability | Medium |
| **Firestore Indexes** | Ensure composite indexes are defined for all queries | High |
| **Security Rules** | Review and harden Firestore security rules | High |
| **State Management** | Consider migrating from Provider to Riverpod for better testability | Low |
| **Multi-language** | Add i18n support (Indonesian + English) | Low |

---

## 📊 Priority Matrix

```
                    HIGH IMPACT
                        │
     Dark Mode  •───────┼───────•  GPS Location
    Leave Balance│      │      │ Verification
      Badge Count│      │      │
                │      │      │
      Empty     │  LOW  │ HIGH │  Shift Swap
      States    │ EFFORT│EFFORT│
                │       │      │
    Request     │       │      │  QR Code
     History  •─────────┼───────• Check-In
                        │
                    LOWER IMPACT
```

---

## 🚦 Recommendation for Next Sprint

1. **Notification Badge** (1 day)
2. **Request History Page** (1 day)
3. **Leave Balance Display** (0.5 day)
4. **Empty State Widgets** (0.5 day)
5. **Dark Mode Toggle** (1 day)

Total: ~4 days for 5 significant UX improvements.

---

*Last updated: ${new Date().toISOString().split('T')[0]}*
