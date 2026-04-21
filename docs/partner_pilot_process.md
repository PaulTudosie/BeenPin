# BeenPin Partner Pilot Process

This document is the partner-facing operating process for the MVP pilot. It is intentionally written so it can be presented before partners are signed, without implying that any venue has already committed.

## Pilot Promise

BeenPin sends explorers to real places in the city. A user can unlock a same-day reward only after the app verifies that they were physically close to a mapped pin and took a photo there.

The partner reward is not a standalone free gift. It is an extra treat connected to a normal purchase, for example:

- Coffee shop: free espresso shot, cookie, syrup, or size upgrade with any drink.
- Restaurant: small dessert, side, soft drink, or chef extra with a meal.
- Museum or attraction: postcard, small discount, audio guide, or gift-shop extra with ticket or purchase.

## User Flow

1. User discovers a pin on the BeenPin map.
2. User walks to the real location.
3. App checks GPS proximity before opening the camera.
4. User takes a photo at the pin.
5. App stores timestamp, GPS distance from the pin, and a proof ID.
6. App unlocks a same-day QR reward.
7. User visits the partner and orders normally.
8. User shows the QR code to staff before payment or when requested.
9. Staff applies the agreed extra treat.

## GPS And Timestamp Proof

For the MVP, a capture is valid only if:

- Location permission is granted.
- Device location can be read.
- User is within the configured capture radius of the pin.
- A photo is taken through the BeenPin capture flow.
- The capture receives a generated proof ID.

The app currently stores:

- Spot ID and spot name.
- Photo path on device.
- Capture timestamp.
- User latitude and longitude at verification.
- Distance from the mapped pin.
- Proof ID used inside the reward QR.

## QR Redemption Rule

For the first pilot, redemption can be manual and staff-friendly:

- Reward is valid same day only.
- Reward is one use per proof ID.
- Reward is an extra with a purchase, not a free standalone claim.
- Staff checks the QR code and proof ID visually.
- Staff can keep a simple daily redemption list during the pilot.

Future production versions should add a partner dashboard or staff scanner that marks proof IDs as redeemed server-side.

## Partner Offer Setup

Before adding a partner to the pilot dataset, collect:

- Partner name.
- Category.
- Address.
- Google Maps URL or website URL.
- Reward title.
- Reward description.
- Purchase condition.
- Validity window.
- Daily limit if needed.
- Staff instruction.
- Contact person.

Example offer format:

```text
Partner: Example Coffee
Reward: Free cookie with any coffee
Condition: User must buy one drink
Validity: Same day after BeenPin capture
Limit: 20 redemptions per day
Staff: Ask user to show QR, then write proof ID on daily sheet
```

## Clean Pilot Dataset

Use a small, believable first dataset:

- 10 to 15 public map pins in one city area.
- 3 to 5 signed partners near those pins.
- 1 reward per partner.
- 1 to 2 hidden spots for controlled street activations.

Avoid listing real partner names in the public demo until they agree. Until then, use clearly marked sample partners in the app and explain that partner mapping is ready to be configured after onboarding.

## Partner Pitch Notes

The partner value proposition:

- Sends nearby foot traffic from people already exploring the area.
- Rewards are purchase-attached, so the partner is not giving away value without a transaction.
- Same-day urgency encourages immediate visits.
- QR proof and GPS capture reduce fake claims.
- Pilot can start manually before needing a full staff dashboard.

The pilot ask:

- Agree on one small extra treat.
- Train staff on the simple QR/proof flow.
- Run for 2 to 4 weeks.
- Track redemptions and rough conversion feedback.
- Decide whether to continue, improve, or expand.
