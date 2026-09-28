# Lumen — Mobile Shopping Platform

Flutter shopping app for product discovery, search, cart, and test checkout. State lives in Riverpod. Cart, orders, session, and the catalog cache live in Hive so the floor still opens offline.

## What it does

- Email sign-in and registration, with a seeded demo account
- Product discovery, category filters, search, sort, and infinite scrolling
- Product pages with hero transitions
- Cart, shipping, tax, and checkout
- Stripe test cards and a PayPal sandbox buyer (no live charges)
- Hive persistence and a sync queue for Firestore / Firebase Storage when Firebase is configured
- Lottie confirmation, responsive grid, and an offline switch

## Run

```bash
flutter pub get
flutter run
```

Demo account: `demo@lumen.market` / `lumen123`

Stripe test card: `4242 4242 4242 4242`, any future `MM/YY`, any 3-digit CVC.
Decline card: `4000 0000 0000 0002`.
PayPal sandbox: `buyer@lumen.test` / `sandbox`.

## Firebase

The app boots without a Firebase project and keeps data in Hive. To turn on Auth, Firestore, and Storage:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Sync from the profile tab pushes queued orders and the catalog.

## Checks

```bash
flutter analyze
flutter test
```
