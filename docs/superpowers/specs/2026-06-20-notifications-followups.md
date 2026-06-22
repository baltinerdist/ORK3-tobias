# Notifications — deferred follow-ups (from polish review 2026-06-20)

These are real findings from the multi-lens polish pass that were **out of scope**
for the notifications change set (they touch app-wide / pre-existing code or are
design questions). Captured here so they aren't lost.

## 1. CSRF / SameSite on the session cookie (app-wide) — HIGH
- **Where:** `system/lib/system/class.Session.php` (session cookie setup).
- **Issue:** No CSRF token mechanism anywhere in the app, and the session cookie
  is set with the legacy `session_set_cookie_params($lifetime, $path, $domain)`
  signature — no `SameSite` attribute. State-mutating POSTs (including
  `NotificationAjax/send`, which fans out announcements) are CSRF-able. `send` is
  on `$_skipTokenCheck`, so even the stale-session guard is bypassed.
- **Fix (minimal, app-wide win):** switch to the array form of
  `session_set_cookie_params([... 'samesite' => 'Lax', 'secure' => true,
  'httponly' => true])`. Verify HTTPS assumptions before forcing `secure`.
- **Why deferred:** pre-existing, affects the whole app, not the notifications
  change set. Should be its own PR.

## 2. Ex-officer announcement authority — MEDIUM (design)
- **Where:** `controller.NotificationAjax.php` `send` → `HasAuthority(uid,
  AUTH_KINGDOM|AUTH_PARK, scopeId, AUTH_EDIT)`.
- **Issue:** If `HasAuthority` does not revoke a deposed/expired officer's
  authority immediately, a former officer could keep sending announcements to a
  former org's members until their session expires (blast-radius / harassment).
- **Action:** confirm whether `HasAuthority` validates active-officer currency.
  If not, add an explicit active-officer check on `send`, or restrict announcement
  sends to `AUTH_ADMIN`.

## 3. Cache the unread badge count — LOW (optional optimization)
- **Where:** `default.theme` inline `UnreadCount` on every authenticated page load.
- **Issue:** one `SELECT COUNT(*)` per page render. With the new
  `recipient_unread` index this is cheap, but a 60s GhettoCache key
  (`notif_unread_{uid}`) would drop it to ~1 hit/min/user.
- **Why deferred:** the design is deliberately page-load-only/simple; revisit only
  if the count query shows up in profiling.
