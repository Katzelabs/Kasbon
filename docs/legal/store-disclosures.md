# Store data declarations

Answers to fill into the Play Console **Data safety** form and the App Store
Connect **App Privacy** questionnaire. Both must match
`app/web/legal/privacy.html`; a mismatch between the form and the policy is one
of the more common rejection reasons, and Google re-checks it on every release.

Derived from the schema in `supabase/migrations/` and the permissions actually
declared in `app/android/app/src/main/AndroidManifest.xml` and
`app/ios/Runner/Info.plist`. Where a category is deliberately *not* declared,
the reason is written down — that reasoning is the part that gets lost.

## The facts both forms are built on

- The app collects: account email, optional name and phone, the shop's own
  business records, customer names typed by the shop owner, and photos
  (products, payment proofs).
- **One third-party SDK collects anything, and only on a crash.** Sentry
  (`dbd6c28`) sends a crash report to servers in the EU: error type, stack trace,
  app version, device and OS, and the account UUID. Everything else is stripped
  by field name before sending, and `attachScreenshot`/`attachViewHierarchy` are
  off — a POS screenshot *is* the cart. There is still no Firebase, no
  Crashlytics, no ad network and no attribution SDK, and the "analytics" in
  `features/reports/` is the shop's own sales reporting, computed by Postgres
  RPCs from the shop's own rows.
- Nothing is shared with a third party for that party's own purposes. Supabase
  is a processor acting on our instruction.
- Nothing is used for tracking or advertising, in either store's sense.
- Everything travels over HTTPS/TLS.
- Deletion can be requested, and the promise is in section 10 of the policy.

---

## Google Play — Data safety

### Overview questions

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — all traffic to Supabase is HTTPS/TLS |
| Do you provide a way for users to request that their data be deleted? | **Yes** — see the deletion URL note below |
| Is your data collection independently verified against a security standard? | No |

Nothing below is "processed ephemerally", and nothing is "shared" in Play's
sense (transferred to a third party for their own use). Every row is
**Collected: Yes / Shared: No**.

### Data types

| Category → type | Collected | Required? | Purposes |
|---|---|---|---|
| Personal info → **Email address** | Yes | Required | Account management, App functionality |
| Personal info → **Name** | Yes | Optional | Account management, App functionality |
| Personal info → **Phone number** | Yes | Optional | Account management, App functionality |
| Personal info → **User IDs** | Yes | Required | Account management, App functionality |
| Personal info → **Address** | Yes | Optional | App functionality |
| Personal info → **Other info** | Yes | Optional | App functionality |
| Financial info → **Other financial info** | Yes | Required | App functionality |
| Photos and videos → **Photos** | Yes | Optional | App functionality |

Notes per row, in the order above:

- **Email address** — Supabase Auth identity. Required to have an account at all.
- **Name / Phone number** — `user_profiles.full_name` and `.phone`, both from
  optional signup fields; the name also prints on receipts as the cashier.
- **User IDs** — the Supabase `auth.users.id` UUID that every row is scoped to.
- **Address** — `shop_settings.address`. A business address rather than a home
  one, but it is a free-text address tied to an account, so it is declared.
- **Other info** — `transactions.customer_name`, plus free-text fields the shop
  owner types (product descriptions, transaction notes, receipt header/footer).
  This is the row that covers **third-party data entered by the user**; Play has
  no better type for it.
- **Other financial info** — the shop's own sales records: totals, prices,
  costs, payment method, debt status. Play's *Purchase history* is deliberately
  **not** used: that type means purchases the app's user made, and these are
  sales the user's customers made to them. No card or bank credentials are ever
  handled, so *User payment info* is No.
- **Photos** — product images and payment proofs. Optional: the app is fully
  usable without ever granting camera or gallery access.

### Categories deliberately left as "No"

| Category | Why |
|---|---|
| Location (approximate, precise) | No location permission is declared or requested |
| Health and fitness | Not applicable |
| Messages | Not applicable |
| Audio files, Music files, Voice or sound recordings | No microphone permission |
| Files and docs | Backup export writes to the user's own device; nothing is uploaded |
| Calendar, Contacts | No permission declared |
| App activity (interactions, search history, installed apps, in-app search) | No analytics SDK; nothing records in-app behaviour off-device |
| Web browsing history | Not applicable |
| Device or other IDs | No advertising ID, no device ID is read or transmitted |

**App info and performance → Crash logs and Diagnostics are YES.** This row moved
out of the table above when Sentry shipped (`dbd6c28`, 9 Aug 2026) and is the one
answer on the form that changed after the first draft. Declare *Crash logs* and
*Diagnostics* as collected, **not** shared, and purpose **App functionality** only
— not analytics, which on Play's form implies product measurement the app does
not do. Mark both as *not* optional: the report is automatic and there is no
in-app toggle. *Other app performance data* stays No.

The declaration must agree with policy section 2.7, which describes what leaves
the device: error type, stack trace, app version, device and OS, and the account
UUID — after `PiiScrubber` removes named fields, and with screenshots and view
hierarchies never attached.

**Server logs and IP addresses.** Supabase records infrastructure logs holding
IP addresses and request metadata, used for security and troubleshooting. Play's
data-type list has no matching type — IP address is not one of its declarable
types, and the logs are our processor's operational records rather than data the
app collects about the user. The policy discloses them (section 2.6) even though
the form has nowhere to put them. If Play's taxonomy adds an IP address type,
declare it under security and compliance.

### Data deletion URL — a separate requirement

Play requires apps with account creation to offer both an **in-app** deletion
path and a **publicly reachable web URL** where deletion can be requested
without installing the app. Both exist:

| Route | Where |
|---|---|
| In-app | *Pengaturan → Akun → Hapus Akun* |
| Web | `https://kasbonapp.katzeapps.com/legal/hapus-akun.html` (`app/web/legal/hapus-akun.html`) |

Enter the web URL in Play Console → App content → **Data deletion**. It ships
from the same folder as the policy and by the same mechanism, so the hosting
caveat in `README.md` applies to it too.

---

## App Store Connect — App Privacy

Declared per data type as: **collected**, whether **linked to the user's
identity**, and whether **used for tracking**.

Everything KASBON collects is linked to an account, so *linked to you* is Yes
throughout. **Nothing is used for tracking** — the app does not share data with
data brokers and does not join it with third-party data for advertising or
measurement.

| Category → type | Collected | Linked | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info → **Email Address** | Yes | Yes | No | App Functionality |
| Contact Info → **Name** | Yes | Yes | No | App Functionality |
| Contact Info → **Phone Number** | Yes | Yes | No | App Functionality |
| Contact Info → **Physical Address** | Yes | Yes | No | App Functionality |
| Financial Info → **Other Financial Info** | Yes | Yes | No | App Functionality |
| User Content → **Photos or Videos** | Yes | Yes | No | App Functionality |
| User Content → **Other User Content** | Yes | Yes | No | App Functionality |
| Identifiers → **User ID** | Yes | Yes | No | App Functionality |
| Diagnostics → **Crash Data** | Yes | Yes | No | App Functionality |
| Diagnostics → **Performance Data** | Yes | Yes | No | App Functionality |

*Other User Content* covers customer names, product and category names,
transaction notes, and receipt text. *Other Financial Info* covers the sales,
profit and debt records — Apple's *Payment Info* and *Purchase History* are both
No, for the same reason as on the Play form.

*Crash Data* and *Performance Data* are linked to the user because the report
carries the account UUID for grouping — Apple's question is whether the data
*can* be tied to an identity, and it can. *Other Diagnostic Data* stays No.

Answer **"Data Not Collected"** for: Health & Fitness, Location, Sensitive Info,
Contacts, Browsing History, Search History, Identifiers → Device ID, and Usage
Data. (Diagnostics used to be on this list; Sentry moved it.)

### Two more things App Store Connect will ask for

- **Privacy Policy URL** — set it on the App Information page:
  `https://kasbonapp.katzeapps.com/legal/privacy.html`. The English page can go in as the
  localised URL for the en-US listing.
- **Account deletion (Guideline 5.1.1(v))** — an app that supports account
  creation must offer account deletion *from inside the app*. Tracked with the
  account-deletion task; this is a rejection, not a warning.

### Privacy manifest — verify before the first upload

`app/ios/Runner/` has no `PrivacyInfo.xcprivacy`. Apple requires an app-level
privacy manifest declaring required-reason API usage, and the app's dependencies
do touch those APIs — `shared_preferences` (UserDefaults),
`path_provider`/`file_picker` (file timestamps), `flutter_secure_storage`
(Keychain). Recent plugin versions ship their own manifests, which may satisfy
the requirement without one in the Runner target.

Check rather than assume: build the archive and read Xcode's generated privacy
report (Product → Archive → Generate Privacy Report). If it flags an
undeclared required-reason API, add `PrivacyInfo.xcprivacy` to the Runner target
with the matching reason codes. App Store Connect rejects the upload
automatically if this is wrong, so it surfaces at the worst moment.
