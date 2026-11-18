# Security Spec — Vibe Coding Guardrails
← [[CLAUDE]]

> A checklist of critical security fixes AI-generated code commonly misses.
> Run through this before every production deployment.
> File: `System/Security-Spec.md`

---

## 1. Don't Leave CORS Wide Open

**Problem:** AI often sets CORS to `*` (allow all domains), meaning any site can call your API and potentially steal user data through the browser.

**Fix:** Restrict CORS to your production domain only.

```
"Configure CORS to only allow requests from my production domain: myapp.com"
```

**Why it matters:** Open CORS = anyone can steal your users' data through their browser.

---

## 2. Validate Your Redirects

**Problem:** If your login page has `?redirect=/dashboard`, an attacker can swap it to `?redirect=evil.com/phishing` and hijack users post-login.

**Fix:** Validate all redirect URLs against an explicit allowlist before redirecting.

```
"Ensure all redirect URLs are validated against an allowlist before redirecting the user"
```

**Why it matters:** Open redirects are the #1 vector for phishing users after login.

---

## 3. Lock Down Your Storage

**Problem:** When AI scaffolds file uploads, it often makes the entire storage bucket public by default — exposing every user file.

**Fix:** Set Row-Level Security (RLS) policies so users can only access their own files.

```
"Create storage policies so users can only access files they uploaded"
```

**Why it matters:** One public bucket = all user files indexed and exposed to Google Search.

---

## 4. Remove Debug Statements

**Problem:** AI adds `console.log(userData)` to assist debugging. That data ships to production and is visible to anyone with DevTools open.

**Fix:** Strip all `console.log` statements and replace with server-side error logging.

```
"Remove all console.log statements and replace with proper error logging"
```

**Why it matters:** Sensitive data in the console = any user with DevTools can read it.

---

## 5. Always Verify Webhooks

**Problem:** If you accept Stripe or other payment webhooks without signature verification, anyone can POST fake events to that endpoint.

**Fix:** Validate the webhook signature using the provider's official SDK before processing.

```
"Verify the webhook signature using Stripe's SDK before processing any payment data"
```

**Why it matters:** Unverified webhooks = attackers can send fake "payment succeeded" events.

---

## 6. Check Permissions Server-Side

**Problem:** Hiding a "Delete All" button in the UI does nothing — anyone can call your API directly via `curl` or a browser tab.

**Fix:** Always enforce role checks on the server, not just the frontend.

```
"Check if user.role === 'admin' on the server before executing any privileged operation"
```

**Why it matters:** UI security is no security. Your APIs are always reachable regardless of what the UI shows.

---

## 7. Update Your Dependencies

**Problem:** AI may scaffold projects with packages from 2022 or earlier. Outdated packages have publicly documented exploits.

**Fix:** Run `npm audit fix` and review breaking changes before upgrading.

```bash
npm audit fix
pip audit
```

**Why it matters:** 80% of breaches exploit known vulnerabilities in outdated dependencies.

---

## 8. Rate Limit Reset Requests

**Problem:** An unprotected "forgot password" endpoint can be spammed to flood inboxes or brute-force reset tokens.

**Fix:** Cap password reset requests per email address per time window.

```
"Add rate limiting to the password reset route: max 3 requests per email per hour"
```

**Why it matters:** Unlimited resets = email bombing and token brute-forcing attacks.

---

## 9. Never Show Raw Errors

**Problem:** AI often returns full stack traces to the client, exposing your file structure, tech stack, and internal paths.

**Fix:** Catch all errors, return generic messages to the user, and log full details server-side only.

```
"Catch all errors and return generic messages to users. Log detailed errors server-side only"
```

**Why it matters:** Stack traces hand attackers a map of your infrastructure.

---

## 10. Set Session Expiration

**Problem:** AI auth scaffolding often keeps users logged in indefinitely. A single stolen cookie becomes permanent access.

**Fix:** Set a reasonable JWT expiration and implement refresh token rotation.

```
"Set JWT expiration to 7 days and implement refresh token rotation"
```

**Why it matters:** Permanent sessions = one stolen cookie = unlimited, unrevocable access.

---

## Quick Reference Checklist

| #   | Check                                       | Status |
| --- | ------------------------------------------- | ------ |
| 1   | CORS restricted to production domain        | ☐      |
| 2   | Redirect URLs validated against allowlist   | ☐      |
| 3   | Storage RLS policies enforced               | ☐      |
| 4   | All `console.log` statements removed        | ☐      |
| 5   | Webhook signatures verified                 | ☐      |
| 6   | Server-side permission checks in place      | ☐      |
| 7   | Dependencies audited and updated            | ☐      |
| 8   | Password reset route rate limited           | ☐      |
| 9   | Raw error messages never sent to client     | ☐      |
| 10  | JWT expiration + refresh token rotation set | ☐      |
