# Local Partner Mode

Long-press the BeenPin header logo, enter **2468**, choose the reward's demo
partner, then tap **SCAN REWARD**. Normal logo taps and consumer navigation are
unchanged. Exit returns to the consumer screen. Each new entry requires the PIN.

`lib/services/partner_mode_config.dart` owns the development-only PIN and reads
partner options from `PilotPartnerService`. The pilot catalog uses one offer ID
per partner. The selector is only a local testing identity, not authorization.
The PIN is **not production authentication**.

## Architecture and persistence

`PartnerModeScreen` depends on `RewardRedemptionService`, whose typed
`validateRewardQr` and `redeemReward` results drive verification and success UI.
`LocalRewardRedemptionService` uses the existing `RewardSelectionStore` and
`RewardRedemptionStore`; it does not create a second reward history. The service
can be replaced through the screen's constructor when a backend is available.
The UI never writes preferences directly.

The existing QR format is unchanged:

`BEEN-yyyyMMdd-partnerId-proofId`

The parser uses catalog partner IDs to disambiguate hyphenated identifiers and
strictly validates the date. Unknown partner IDs and unsupported formats fail
closed. Existing proof IDs and persisted QR strings are never regenerated.
For local rewards the entire QR must match the persisted token. Stored partner,
offer, source spot, capture time, expiry and status take precedence over QR data.
For non-local codes, only catalog partner ID, proof ID and the unsigned date can
be displayed. The date implies 23:59:59 local time, as in the existing generator;
it is not authoritative. Non-local codes never create records or enable Confirm.

Confirmation re-fetches and validates the reward. A shared service queue prevents
parallel confirmations from both reporting success. The existing repository
serializes writes, checks active/expired state again, persists the proof ledger
and redeemedAt, then updates the saved reward and its change notifier. Ledger
reconciliation recovers a partial write on the next read. My Rewards already
listens to that notifier, reloads the same records and separates Active/Past.
Redeemed reward detail disables Reveal QR. The customer-facing
“Partner demo: mark redeemed” action has been removed.

The scanner reuses the existing `mobile_scanner` 5.2.3 dependency, with its owned
camera controller handling runtime permission, app pause/resume and disposal.
Detection locks immediately and removes the camera viewport before verification.
Camera errors offer Retry and Open Settings, including permanently denied access.
After changing permission in Settings, tap Retry if the camera does not resume.
No dependency, Android permission, Gradle or Kotlin changes are needed; CAMERA
was already declared. There is no manual payload entry screen.

## One Android phone + laptop acceptance checks

These require physical device testing; automated tests cannot verify optical
scanning, Android permission dialogs or an actual process restart.

1. Create/select an active reward. Open Reveal QR, save a screenshot and display
   it on the laptop, with the complete white QR margin visible.
2. On that same installation, return to the app header. Long-press BeenPin.
   Enter an incorrect PIN and verify the inline error, then enter 2468.
3. Select the partner shown on the reward. Tap SCAN REWARD, grant camera access
   and point the phone at the laptop. Adjust distance/glare if necessary.
4. Check Reward valid, offer, partner, Proof ID, capture time, expiry and spot.
   Cancel once and verify no redemption occurred. Scan again and Confirm.
5. Check Reward redeemed and its timestamp. Exit. My Rewards must remove it
   from Active, show it as Redeemed in Past and disable Reveal QR in detail.
6. Kill and relaunch the app. Verify the same Past entry and timestamp remain.
7. Scan the original screenshot again: Already redeemed; history unchanged.
8. Scan an unrelated QR: Invalid QR; Scan again returns to the real camera.
9. Retain an active QR screenshot until after its displayed expiry. Scan:
   Reward expired with no Confirm. Also leave verification open across expiry
   and confirm: it must reject redemption.
10. Choose a different demo partner and scan: Different partner, no Confirm.
11. Scan a valid screenshot from a separate installation with a distinct proof:
    Demo validation, backend-unavailable wording, no redemption or saved record.
12. Deny camera access on a fresh permission request; verify Retry. Deny
    permanently, use Open Settings to grant access, return and retry. Background
    and resume the scanner; cancel scanning; scan another after success.

## Production boundary

Local validation is MVP/demo validation. Client-generated QR data is forgeable.
Neither a PIN nor exact local string matching proves customer ownership or token
authenticity. No embedded secret/HMAC is used. There is no server verification,
partner authentication or synchronization across installations.

A backend implementation must validate reward existence, customer ownership,
partner relationship, expiry, redemption status and token authenticity. It must
perform single-use redemption atomically and allow the customer repository to
synchronize status. Replace the local service implementation and add customer
sync; preserve the scanner/verification UI flow. Device clock and local storage
are not production trust boundaries.
