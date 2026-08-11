# Legal & store privacy disclosures

The privacy policy and the two store declarations that have to agree with it.

Both stores refuse an app that collects an email address without a reachable
privacy policy URL, and both compare that policy against the data declaration
in their console. This folder holds the declaration answers; the policy itself
is a static page that ships with the web build.

## Where the policy lives

| File | Serves |
|------|--------|
| `app/web/legal/privacy.html` | Bahasa Indonesia — **the authoritative text** |
| `app/web/legal/privacy-en.html` | English translation, for store reviewers |
| `app/web/legal/terms.html`, `terms-en.html` | Syarat & Ketentuan — **draft, see below** |
| `app/web/legal/hapus-akun.html`, `hapus-akun-en.html` | The account-deletion request page Play requires, shipped by the same mechanism |

`flutter build web` copies everything under `app/web/` into `build/web/`
verbatim, so whatever host serves the web app also serves the policy:

```
https://kasbonapp.katzeapps.com/legal/privacy.html
https://kasbonapp.katzeapps.com/legal/privacy-en.html
```

That address is `SupportContacts.privacyUrl`, which is what the in-app rows
open and what goes in both consoles. `test/unit/legal/privacy_policy_test.dart`
fails if the constant and the shipped file stop agreeing — renaming the file is
otherwise a link that 404s in three places and still compiles.

**One hosting caveat.** The web app uses path URLs, so the host must rewrite
unknown paths to `index.html`. Every static host (Netlify, Vercel, Cloudflare
Pages, Firebase Hosting) serves a file that exists before applying that
rewrite, so `/legal/privacy.html` resolves — but a catch-all rewrite configured
as `/* → /index.html` with `force = true` would swallow it. Check the policy
URL in a private window after the first deploy.

## In-app links

- **Pengaturan → Kebijakan Privasi** — a row on the settings hub itself,
  because reviewers look for the policy from Settings and will not guess that
  "Tentang Aplikasi" hides it.
- **Pengaturan → Tentang Aplikasi → Legal → Kebijakan Privasi**.
- **Pengaturan → Tentang Aplikasi → Legal → Syarat & Ketentuan**.

All three open the hosted page through `ExternalLink.openUrl`, and each URL is
covered by a test in `test/unit/legal/` that fails if the constant stops naming
a file that ships.

## Updating the documents

Both documents state facts about the running system. Reopen the **policy**
whenever one of these changes:

| Change | Section to revisit |
|--------|--------------------|
| A new column, table or bucket holding user-entered data | 2 — what we collect |
| The Supabase project moves region | 5 — where it is stored |
| `payment_proof_retention_days` default or bounds change | 6 — retention |
| The `storage-janitor` schedule changes | 6 — retention |
| Any third-party SDK that phones home is added | 3 — what we do not do |
| The account-deletion flow changes | 10 — deleting your account |

Reopen the **terms** whenever one of these changes:

| Change | Section to revisit |
|--------|--------------------|
| The app gains offline capability | 8 — availability says it needs a connection |
| A paid tier or in-app purchase ships | 10 — fees says the service is free today |
| KASBON starts touching money rather than recording it | 4 — "does not process payments" |
| The backup/export feature changes | 9 — backups |
| The account-deletion flow changes | 11 — termination |

Bump the version and effective date in the header and footer of **both**
language files of whichever document changed, then update the store
declarations in `store-disclosures.md` if the data types changed. A material
change also needs an in-app or email notice before it takes effect — that is
what section 12 of the policy and section 14 of the terms promise.

The English page is a translation. If the two ever disagree, the Indonesian
text governs, and that is stated on the English page.

## Before submitting to either store

Blocking, in rough order:

- [ ] **Confirm the Supabase production region.** The policy says Singapore
      (ap-southeast-1). Nothing in this repo records the region — there is no
      linked project ref — so it was chosen as the answer for an Indonesian
      user base. Verify it in the Supabase dashboard and correct section 5 if
      it is wrong. A policy that names the wrong country is a false statement
      about a cross-border transfer.
- [ ] **Replace the placeholder contacts.** `SupportContacts` ships
      `kasbon@katzeapps.com` and WhatsApp `+62 812-3456-7890`; the latter is
      plainly a placeholder. Both appear in the policy and both are where a
      deletion request will arrive. The mailbox has to exist and be monitored —
      section 9 promises a reply within 30 days.
- [ ] **Name the legal entity.** The policy currently says "the operator of the
      KASBON app". UU PDP 27/2022 requires the controller to be identifiable,
      and both stores want a developer name and address on the listing. Add the
      entity name and business address to section 1 once it is registered.
- [ ] **Account deletion is implemented — deploy its Edge Function.** The
      policy's section 10 names an in-app route, *Pengaturan → Akun → Hapus
      Akun*, and an email fallback, and both now exist: the dialog, the
      `delete-account` function, and `20260804010010_account_deletion.sql`.
      Verified against the local stack end to end (auth row deleted, tables
      cascaded, both storage folders emptied, and a caller presenting anything
      but their own user token rejected). What is left is deployment —
      `supabase functions deploy delete-account`, which needs no Vault secrets
      unlike the janitor. Until it runs, the app's row calls a function that is
      not there, and a reviewer will find that in one tap. Enter
      `SupportContacts.accountDeletionUrl`
      (`https://kasbonapp.katzeapps.com/legal/hapus-akun.html`) under App content → Data
      deletion; it is the same file-ships-with-the-web-build arrangement as the
      policy, and `test/unit/legal/account_deletion_page_test.dart` guards it.
- [ ] **Have the terms reviewed by a lawyer.** `terms.html` is drafted from what
      the app actually does and is accurate about the product, but a terms of
      service allocates legal risk in a way a privacy policy does not. Three
      sections are drafting, not advice, and need a real decision: **12**
      (limitation of liability — how far can you actually disclaim under
      Indonesian consumer and contract law), **13** (indemnity), and **15**
      (governing law — it names "the competent courts in Indonesia" rather than
      a specific jurisdiction). Section 1 also has to name the legal entity, the
      same gap as the policy. Both files carry an HTML comment saying this;
      remove it once reviewed.
      Neither store *requires* terms — Play requires only a privacy policy, and
      Apple applies its standard EULA where you supply none — so this is not a
      submission blocker. It is a blocker for the row being live in the app.
- [ ] **Production SMTP is configured.** The policy names an email delivery
      provider as a processor. `config.toml` governs local dev only; without
      real SMTP on the hosted project, verification codes never arrive and the
      account flow the policy describes does not work.
- [ ] Fill the **Play Data safety** form and the **App Store Connect App
      Privacy** questionnaire from `store-disclosures.md`.
- [ ] Paste the policy URL into both consoles' app information pages.
