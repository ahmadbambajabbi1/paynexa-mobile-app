# Core Parity Checklist: `escrow_web` → `escrow_app`

This checklist tracks **core** (MVP) feature parity between:
- Web: `frontends/escrow_web`
- Mobile: `frontends/escrow_app`

Design note: Mobile should **keep existing colors** (see `lib/theme/app_colors.dart`) and only adapt **layout/spacing** for small screens.

## Authentication / onboarding
- **Login**
  - Web: `frontends/escrow_web/app/login/page.tsx`
  - App: `frontends/escrow_app/lib/screens/login_screen.dart`
- **Register**
  - Web: `frontends/escrow_web/app/register/page.tsx`, `frontends/escrow_web/app/register/verify/page.tsx`
  - App: (verify flow not clearly mapped from quick scan; confirm in `lib/screens/` if implemented)
- **Complete profile**
  - Web: `frontends/escrow_web/app/(authenticated)/complete-profile/page.tsx`
  - App: `frontends/escrow_app/lib/screens/complete_profile_screen.dart`

## Marketplace (explore / services / create)
- **Explore marketplace**
  - Web: `frontends/escrow_web/app/marketplace/page.tsx`, `frontends/escrow_web/app/marketplace/services/page.tsx`
  - App: `frontends/escrow_app/lib/screens/marketplace_explore_screen.dart`, `frontends/escrow_app/lib/screens/marketplace_services_screen.dart`
- **Service detail**
  - Web: `frontends/escrow_web/app/marketplace/services/[id]/page.tsx`
  - App: `frontends/escrow_app/lib/screens/service_detail_screen.dart`
- **Create service listing**
  - Web: `frontends/escrow_web/app/(authenticated)/marketplace/create/page.tsx`
  - App: `frontends/escrow_app/lib/screens/marketplace_create_service_screen.dart`
- **My services**
  - Web: `frontends/escrow_web/app/(authenticated)/marketplace/my-services/page.tsx`
  - App: (confirm coverage; likely within `marketplace_store_screen.dart` / marketplace shell)

## Bookings (marketplace)
- **Bookings list**
  - Web: `frontends/escrow_web/app/(authenticated)/marketplace/bookings/page.tsx` (redirects to store tab)
  - Web (actual UI): `frontends/escrow_web/app/(authenticated)/store/page.tsx` with bookings tab
  - App: `frontends/escrow_app/lib/screens/marketplace_bookings_screen.dart`
- **Booking detail**
  - Web: `frontends/escrow_web/app/(authenticated)/marketplace/bookings/[id]/page.tsx`
  - App: `frontends/escrow_app/lib/screens/marketplace_booking_detail_screen.dart`
- **Booking payment (critical parity)**
  - Web: `frontends/escrow_web/src/components/marketplace/ServiceBookingPaymentModal.tsx`
  - App: **TODO** (implement a Wallet/Card payment sheet; currently `MARK_FUNDED` is blocked by snackbar)

## Transactions (escrow)
- **Transactions list**
  - Web: `frontends/escrow_web/app/(authenticated)/transactions/page.tsx`
  - App: `frontends/escrow_app/lib/screens/transactions_screen.dart`
- **Transaction detail**
  - Web: `frontends/escrow_web/app/(authenticated)/transactions/[id]/page.tsx`
  - App: `frontends/escrow_app/lib/screens/transaction_detail_screen.dart`

## Wallet / Billings
- **Wallet overview + payment methods + transfers**
  - Web: `frontends/escrow_web/app/(authenticated)/billings/page.tsx`
  - App: `frontends/escrow_app/lib/screens/billings_screen.dart`
- **Add card**
  - Web: `frontends/escrow_web/app/(authenticated)/billings/add-card/page.tsx`
  - App: included inside `BillingsScreen` via Stripe payment sheet setup flow

## Profile / KYC / Notifications
- **Profile**
  - Web: `frontends/escrow_web/app/(authenticated)/profile/page.tsx`
  - App: `frontends/escrow_app/lib/screens/profile_screen.dart`
- **KYC apply**
  - Web: `frontends/escrow_web/app/(authenticated)/kyc/apply/page.tsx`, `.../kyc/personal/page.tsx`
  - App: `frontends/escrow_app/lib/screens/kyc_apply_screen.dart`, `frontends/escrow_app/lib/screens/personal_kyc_apply_screen.dart`
- **Notifications**
  - Web: `frontends/escrow_web/app/(authenticated)/notifications/page.tsx`
  - App: `frontends/escrow_app/lib/screens/notifications_screen.dart`

