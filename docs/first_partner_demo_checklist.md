# First Partner Demo Checklist

Use this before meeting the first partner. The app can run without signed partners by using clearly marked sample pilot offers, then each sample offer can be replaced with a signed partner later.

## What Is Now Demo-Ready

- Capture requires GPS permission and proximity before the camera opens.
- Each capture stores timestamp, GPS distance, and a proof ID.
- Rewards are selected from a pilot partner dataset instead of one hardcoded reward.
- QR rewards include the proof ID and same-day date.
- A reward can be marked as redeemed once on the demo device.
- Hidden spots can be unlocked through a demo scan flow before physical QR stickers exist.

## Partner Meeting Flow

1. Open the app and show the map pins.
2. Tap a pin and explain the nearby sample partner offer.
3. Try capturing while far from the pin to show the GPS gate.
4. Capture when close enough, or explain that the demo device must be near the mapped coordinate.
5. Show the unlocked reward, proof ID, GPS distance, and QR.
6. Tap "Partner demo: mark redeemed" to show one-use redemption behavior.
7. Open Hidden and run the demo scan to explain future street activations.

## Replace Before A Real Pilot

- Replace sample partner names with signed partner names.
- Replace sample addresses and URLs with real partner details.
- Confirm each partner's purchase condition, daily limit, and staff instruction.
- Print a simple staff redemption sheet with columns: date, proof ID, reward, staff initials.
- Decide whether staff will manually check QR codes or use a future scanner/dashboard.

## Backend Step After First Partner Interest

The local redemption ledger is enough for a truthful first demo, but a real public pilot needs a backend table for captures, rewards, and redemptions. Minimum server fields:

- `proof_id`
- `spot_id`
- `partner_id`
- `captured_at`
- `expires_at`
- `redeemed_at`
- `redeemed_by_staff_id`
- `status`

## Not Yet Production-Ready

- Redemption is enforced only on one demo device, not across all devices.
- Users and social feed are still mocked/local.
- Hidden QR scanning is simulated until a QR scanner package and printed codes are added.
- There is no partner dashboard yet.
