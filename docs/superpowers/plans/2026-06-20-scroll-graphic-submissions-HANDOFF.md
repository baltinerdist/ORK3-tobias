# Scroll Graphic Submissions — Session Handoff / Continuation

**Date:** 2026-06-20
**Branch:** `feature/scroll-generator`
**PR:** [#6 — Enhancement: Scroll Generator + Scroll Graphic Submissions module](https://github.com/baltinerdist/ORK3-tobias/pull/6) (base `master`, OPEN, on the fork `baltinerdist/ORK3-tobias`)

This file lets a new (post-compaction) session resume without re-deriving context. Read this, the spec, and the plan; then continue.

- **Spec:** `docs/superpowers/specs/2026-06-19-scroll-graphic-submissions-design.md`
- **Plan:** `docs/superpowers/plans/2026-06-19-scroll-graphic-submissions.md`

---

## Status: DONE (shipped to PR #6)

The standalone **Scroll Graphic Submissions** module is complete, reviewed (two-stage spec+quality per unit), and verified end-to-end. 14 `feat/fix(scroll-graphics)` commits, `4f06ff47` … `d43aa636`.

What shipped:
- **Migrations:** `db-migrations/2026-06-19-scroll-submissions-tiers.sql` (adds `visibility`/`owner_kingdom_id`/`category_id` + indexes to `ork_scroll_artwork`), `db-migrations/2026-06-19-scroll-artwork-categories.sql` (new `ork_scroll_artwork_category` lookup + 9 seeded categories). **Already applied to the local dev DB this session.**
- **Lib** `system/lib/ork3/class.ScrollArtwork.php`: `list_categories`/`save_category`; `upload()` records tier/category; visibility-aware `browse()`/`search()`; tier-aware `get_pending()`/`approve()`/`reject()` + `can_moderate()`; `get_user_uploads()` gained a `$status` filter.
- **AJAX** `orkui/controller/controller.ScrollArtworkAjax.php`: `categories`, tier/category params on `upload`/`browse`/`search`, tier-aware `pending`/`approve`/`reject`, `save_category`, `my_uploads?status=`.
- **Page controller** `orkui/controller/controller.ScrollGraphics.php` (login-gated; routes `index`/`upload`/`mine`/`moderate`) + homepage link in `orkui/template/default/default.tpl`.
- **Templates** `orkui/template/revised-frontend/ScrollGraphics_{index,upload,mine,moderate}.tpl` + shared `style/scroll-graphics.css` (dark-mode complete).
- **Render** `orkui/controller/controller.ScrollAjax.php`: ephemeral `artwork_<slot>_raw` compositing path (`compositeArtwork` refactored → `compositeArtworkResource`; behavior-preserving for the existing ID path).

Verified: scroll test suite passes (`tests/scroll/test_categories.php`, `test_submission_tiers.php`, `test_moderation_authority.php` — token-gated assertions skip in dev); full lifecycle via authenticated curl (upload → pending queue → hidden-while-pending → approve → appears in library).

---

## THE NEXT PHASE — deferred follow-up: in-builder "upload + opt-in share"

This is the remaining piece of the original ask and the intended next work.

### Goal
While a user is building a scroll, let them upload their own image for a zone and — via an **opt-in** "Share this with the Amtgard Graphics Library" path (license text + typed signature + **Amtgard | Kingdom** tier toggle) — submit it to the shared library. Not sharing = the image is used on that scroll only (ephemeral).

### Critical architectural fact (why this wasn't done in PR #6)
The May-30 **forge rebuild** (commit `c8dade4d`) **removed the builder's entire artwork layer** and moved the builder to **client-side export** (html2canvas / `window.print()` via `exportPNG`/`exportPDF`). The live `orkui/template/revised-frontend/Scroll_builder.tpl` has **no `sgState.artwork`, no `sgDownload()`, and no POST to `ScrollAjax/generate`** — only orphan `.sc-artwork-*` CSS survives. The full removed UI is preserved in `Scroll_builder.tpl.pre-reinvent.bak` (markup ~2300–2660; JS `sgArtwork*` ~5954–6475; `sgDownload` family export region).

### Recommended shape: **Option B — adapt to the current client-side builder** (NOT Option C)
Re-introduce an "Upload your own" modal that composites the image into the **current client-side** export, with the opt-in share POSTing to `ScrollArtworkAjax/upload` (tier/license fields already supported by the AJAX layer). Do **not** revive server-side `ScrollAjax/generate` — that fights the deliberate forge-rebuild decision.
- The in-builder share modal design (toggle phrasing, default-unchecked, license reveal) is in the spec §7.1 and was visually approved.
- The **`artwork_<slot>_raw` server-render path (EU6) stays as latent infrastructure** — only needed if a future decision revives server-side export. Don't build on it for Option B.

### Builder edit mechanics (verified)
- `Scroll_builder.tpl` is **rendered directly** (controller.Scroll.php `builder()` sets the template). There is **no build step** assembling it from `scroll-forge/*.part`. The `.part` files are a *conceptual* source kept in sync **by hand**; editing a `.part` alone has zero runtime effect.
- So: make the real change in **`Scroll_builder.tpl`** (what renders) AND mirror it into the matching `scroll-forge/*.part` (`sf-ui.html.part` / `sf-scroll-markup.html.part` for markup, `sf-app.js.part` for JS) to keep them consistent. No regenerate command exists.

### AJAX contract for the share POST (already live, verified)
`POST <UIR>ScrollArtworkAjax/upload` FormData: `image` (base64, data-URL prefix stripped via `reader.result.split(',')[1]`), `image_mime`, `name`, `description`, `tags`, `layout_location`, `license_signer_name`, `visibility` (`global`|`kingdom`), `owner_kingdom_id` (kingdom id when tier=kingdom else 0), `category_id`. Success = `data.Status === 0`. Reuse the Submit page (`ScrollGraphics_upload.tpl`) as the reference implementation — it already does exactly this flow.

---

## Other open follow-ups (non-blocking, noted in PR)
1. **License text** (`SCROLL_ARTWORK_LICENSE` in `class.ScrollArtwork.php` / the template license block) is a drafted starting point — needs human/legal review before launch (spec §9, §13).
2. **`moderatable_kingdom_ids()`** (`controller.ScrollArtworkAjax.php`) covers only the session kingdom; multi-kingdom officers need a fuller enumeration.
3. **Stale docblocks** on `approve()`/`reject()` in `class.ScrollArtwork.php` still say "Requires admin authority" though moderation is now tier-aware. Cosmetic.
4. **`get()`** returns `CategoryLabel: null` even when `category_id` is set (no category join in that pre-existing method) — non-erroring inconsistency.
5. Theoretical concurrent-create slug race in `save_category` (admin-only, rare; the documented `lastInsertId` dup-key pitfall).

---

## Environment / house-rule reminders for the next session
- **NEVER stage `system/lib/ork3/class.Authorization.php`.** It has an uncommitted local login-bypass (`true ||` ~lines 327/330). It is intentionally never staged/committed/pushed. (The Authorization.php change that *is* committed on this branch is the legitimate principality parent-kingdom traversal — unrelated.) Always `git diff --cached --name-only` before committing; stage files explicitly, never `git add -A`/`.`.
- **App container** `ork3-php8-app` bind-mounts the repo at `/var/www/ork.amtgard.com` (edits + migrations are live). **DB** `ork3-php8-db` (db `ork`, user `ork`, pass `secret`). App at `http://localhost:19080/orkui/`.
- **Routing** is convention-based: `index.php?Route=Controller/action/id` (NOT clean URLs).
- **Curl-auth session** for logged-in AJAX: login via `Login/login` (`username`/`password`; any password works in dev), reuse ONE cookie jar, do login + all calls in ONE shell block (single-device sessions). A valid test PNG can be generated in-container: `docker exec ork3-php8-app php -r '...imagepng...echo base64_encode...'` (a hand-typed 1×1 base64 was rejected by GD validation — generate a real one).
- `.tpl` = plain PHP (`extract()`+`include`), not Smarty. Dark mode selector is `html[data-theme="dark"]`. No native `confirm()`/`alert()`/`title=`. PHP edit rule: normalize-first (check `awk '/^\t/{c++}END{print c+0}'`).
- PRs target the fork `baltinerdist/ORK3-tobias`; title convention `Enhancement:` / `Bugfix:`.

## To resume
Read this file + the spec §7 + plan Task 4.2, then run the brainstorming/plan→subagent-driven flow for the in-builder share (Option B). PR #6 is open; new commits on `feature/scroll-generator` flow into it automatically.
