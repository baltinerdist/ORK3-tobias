# Scroll Graphic Submissions — Design Spec

**Date:** 2026-06-19
**Branch:** feature/scroll-generator
**Status:** Approved design — ready for implementation planning

---

## 1. Summary

A pseudo-standalone **Scroll Graphic Submissions** module, linked from the homepage, that lets members:

- **Browse** a shared library of scroll graphics (borders, seals, center images, etc.).
- **Submit** their own graphics — placing them on a wireframe of the 8 scroll zones, tagging them, choosing a sharing tier, and signing a license.
- **Manage** their own submissions (status, edit, withdraw).
- **Moderate** submissions (tier-aware approval queue) for officers/admins.
- **Manage categories** (ORK admins).

It also adds an **in-builder share path**: when a user uploads an image while building a scroll, they get an opt-in path to contribute it to the shared library under a signed license.

This module **revives and extends** the existing-but-orphaned `ScrollArtwork` backend (lib + AJAX controller + `ork_scroll_artwork` table + render integration), whose front-end UI was lost in the May-30 forge rebuild (commit `c8dade4d`). The backend is intact and still wired into the 300-DPI render path; this spec rebuilds the user-facing surface as a dedicated module and layers the two-tier sharing + moderation model on top.

This is **separate from** the system-curated "style families" curated-asset system, which also uses `ork_scroll_artwork` (rows with `system_owned=1`). User submissions are `system_owned=0` and never collide.

---

## 2. Decisions (locked)

| Decision | Choice |
|---|---|
| **Library scope** | Two-tier: **global** (Amtgard-wide) + **kingdom-private**, via a `visibility` dimension |
| **Moderation authority** | Tiered — ORK admins approve global; kingdom officers approve their own kingdom-private |
| **Placement model** | Keep the existing **8 fixed pixel-exact zones**; the wireframe shows them with exact dimensions |
| **In-builder uploads not shared** | **Ephemeral** — composited into that one scroll's render only; never persisted |
| **Discovery** | Zone filter + **admin-managed categories** + free-text tags + name search |
| **Access** | **Login required throughout.** Global graphics visible to all members; kingdom-private only to that kingdom's members |
| **License text** | Drafted here (§9); flagged as **pending human/legal review** before launch |
| **Architecture** | Approach A — dedicated page controller, reuse & extend the existing `ScrollArtwork` backend |
| **Submit flow** | **Single page** (not a wizard) |
| **Tier selector UI** | A question with a left/right toggle: *"Is this design intended for Amtgard-wide use, or is it Kingdom-specific?"* → **Amtgard \| Kingdom** (used on both the Submit page and the in-builder modal) |
| **In-builder "Share" default** | **Unchecked (opt-in)** — signing a legal name should be deliberate |
| **In-builder tier** | The Amtgard \| Kingdom toggle is available in the in-builder modal too |

---

## 3. Architecture (Approach A)

| File | Role | Status |
|---|---|---|
| `orkui/controller/controller.ScrollGraphics.php` | **New** page controller — renders the standalone module pages | new |
| `orkui/controller/controller.ScrollArtworkAjax.php` | AJAX endpoints — **extend** (visibility/kingdom/category params, tier-aware pending, edit, withdraw) | extend |
| `system/lib/ork3/class.ScrollArtwork.php` | Backend lib — **extend** with visibility/kingdom/category fields + tiered moderation methods | extend |
| `ork_scroll_artwork` table | **Add** columns (additive migration) | extend |
| `ork_scroll_artwork_category` table | **New** lookup table (admin-managed categories) | new |
| `orkui/template/revised-frontend/ScrollGraphics_*.tpl` | **New** page templates (library, upload, mine, moderate) | new |
| In-builder share modal | **New** partial in the scroll-forge builder | new |
| `orkui/controller/controller.ScrollAjax.php` | **Extend** render path to accept ephemeral `artwork_<slot>_raw` bytes | extend |

The standalone module is cleanly separated from the builder; both consume the same lib + AJAX layer. The render integration already exists (loads approved artwork by ID, composites at per-zone opacity).

Follows the project's architecture layering: all DB work stays in `system/lib/ork3/`; the AJAX controller is a thin pass-through + transforms; the page controller renders templates. Front-end uses the existing in-repo CSS conventions and `html[data-theme="dark"]` dark-mode selector (no external design-system dependency).

---

## 4. Pages & routes

Homepage gets a **"Scroll Graphic Submissions"** link → `ScrollGraphics/index`. All routes login-gated (local dev: `index.php?Route=ScrollGraphics/<action>`).

| Route | Page | Audience |
|---|---|---|
| `ScrollGraphics/index` | **Library** — left filter rail (zone / category / tier filters + search) + results grid | any member (global pool + their kingdom's private) |
| `ScrollGraphics/upload` | **Submit a Graphic** — single page: upload → wireframe zone picker → details/category → Amtgard\|Kingdom tier toggle → license + signature | any member |
| `ScrollGraphics/mine` | **My Submissions** — own uploads with status (pending/approved/rejected + reason), edit/withdraw | any member |
| `ScrollGraphics/moderate` | **Moderation queue** — tier-aware; plus admin "Manage Categories" tab | ORK admins (global) + kingdom officers (their kingdom) |

The nav "Moderate" link renders only for users with global or kingdom moderation authority.

### 4.1 Library page (left filter rail + grid)

Left rail: search box; placement-zone checkboxes (the 8 zones); category checkboxes (active categories); tier filter (All / Amtgard / My Kingdom). Grid cards: thumbnail, name, tier badge (Global=blue, Kingdom=green), category, hover actions ("Use in builder" / "Details"). The filter rail is a content-level rail inside the standard centered content column (not app chrome).

### 4.2 Submit page (single page)

1. **Upload** — drag/drop or click; PNG/JPEG/GIF, ≤ 2 MB.
2. **Place** — click a zone on the scroll wireframe diagram; selected zone highlights and the panel shows that zone's **exact target dimensions** (e.g. Full Border → 2550 × 3300 px @ 300 DPI) plus a **Download placement guide** link (the existing `generate_template_guide()` PNG).
3. **Details** — name, description, tags, category (dropdown of active categories).
4. **Tier** — the Amtgard \| Kingdom toggle question.
5. **License & signature** — boilerplate (§9), agree checkbox, type-full-legal-name signature → **Submit for Approval**.

### 4.3 My Submissions

Own uploads, filterable by status. Pending (with which queue), Approved (live), Rejected (shows moderator reason → edit & resubmit, which creates a fresh pending review, or dismiss). Per row: edit metadata (while pending/rejected), withdraw/delete (uploader can always remove own; unlinks file + row).

### 4.4 Moderation queue (tier-aware)

Scoped by viewer authority:
- **ORK admins** (`AUTH_ADMIN`, `AUTH_EDIT`) → **global** pending queue + admin-only **Manage Categories** tab.
- **Kingdom officers** (`AUTH_KINGDOM` over a kingdom) → **kingdom-private** pending queue for their kingdom(s) only.
- Both → segmented view of both.

Each row: thumbnail, name, submitter (persona link), zone + category + tier badge, submitted date, signed license name/timestamp. Actions: **Approve** / **Reject** (reject requires a reason → `rejection_reason`). Authority re-checked server-side per action.

---

## 5. Data model

### 5.1 `ork_scroll_artwork` — additive columns

Existing relevant columns (unchanged): `status` (`pending`/`approved`/`rejected`), `layout_location` (8-zone enum), `license_signer_name`, `license_signed_at`, `uploader_mundane_id`, `approved_by_mundane_id`, `approved_at`, `rejection_reason`, `tags`, plus the curated-family columns (`system_owned`, `family_key`, `asset_role`, `tint_mode`, `source_attribution`, `source_license`).

**New columns:**

| Column | Type | Notes |
|---|---|---|
| `visibility` | ENUM(`global`,`kingdom`) NOT NULL DEFAULT `global` | the sharing tier |
| `owner_kingdom_id` | INT UNSIGNED NULL | moderating/owning kingdom for kingdom-private; also stamped on global submissions for provenance/filtering |
| `category_id` | INT UNSIGNED NULL | FK → `ork_scroll_artwork_category` |

**New indexes:** `(visibility, status, layout_location)` (browse/global queue) and `(owner_kingdom_id, status)` (kingdom queue).

User submissions are `system_owned = 0`.

### 5.2 `ork_scroll_artwork_category` — new lookup table

| Column | Type | Notes |
|---|---|---|
| `category_id` | INT UNSIGNED PK AUTO_INCREMENT | |
| `slug` | VARCHAR(64) UNIQUE | stable key |
| `label` | VARCHAR(120) | display |
| `sort_order` | SMALLINT | ordering in lists |
| `active` | TINYINT(1) NOT NULL DEFAULT 1 | retire without deleting |
| `created_at` / `modified` | datetime / timestamp | |

**Seed:** Heraldic · Celtic & Knotwork · Floral & Botanical · Norse & Viking · Religious & Sacred · Geometric · Beasts & Creatures · Flourishes & Dividers · Other.

Categories are **thematic** and orthogonal to the 8 placement zones — a graphic has both a zone and a (single) category. Retiring a category (`active=0`) never orphans graphics; existing rows keep their `category_id`, it just drops out of filters and new-submission lists.

### 5.3 The 8 placement zones (unchanged)

`full_border`, `border_left`, `border_right`, `border_top`, `border_bottom`, `center_image`, `watermark`, `top_graphic` — with the existing `SLOT_DIMENSIONS` pixel geometry at 300 DPI. The wireframe / `generate_template_guide()` reflects these.

---

## 6. Visibility & moderation rules

- **Browse / insert visibility:** a member sees all `approved` + `global` graphics, plus `approved` + `kingdom` graphics whose `owner_kingdom_id` is their kingdom. Kingdom-private graphics from other kingdoms are never listed or insertable.
- **Submission tier → moderation routing:**
  - `visibility = global` → **ORK admin** queue (`AUTH_ADMIN`).
  - `visibility = kingdom` → that kingdom's **officer** queue (`AUTH_KINGDOM` over `owner_kingdom_id`).
- **Authority is always re-checked server-side** on approve/reject/category actions. Never trust the client.
- **State machine:** `pending` → `approved` (by the correct authority) → live; `pending` → `rejected` (with reason); `rejected` → edit & resubmit → new `pending`. Approved/rejected rows can't be re-decided (idempotent). Uploader can withdraw/delete their own at any state.

---

## 7. In-builder integration — ephemeral vs shared

The existing 300-DPI export loads artwork **by ID, approved-only** — which cannot serve a brand-new upload (`pending` at best). The builder therefore splits:

- **Per-zone actions in the builder:** "Browse Library" (insert an approved graphic by ID — existing render path) and "Upload your own" (opens the share modal).
- **Not shared (ephemeral):** the builder sends the **raw image bytes** (base64) for that slot on the preview/export request via a new `artwork_<slot>_raw` param; the renderer composites them directly. Nothing persists.
- **Shared:** same raw-image render for *this* scroll (immediate visual feedback) **and**, in parallel, a `pending` row is created via the upload endpoint with the chosen tier + license capture. It enters the library only after approval; the current scroll never waits on moderation.
- Compositing honors existing per-zone opacity (watermark 10%, center 15%, borders/top 100%).

### 7.1 In-builder share modal

After picking a file: preview + zone-fit check. A **"Share this with the Amtgard Graphics Library"** checkbox, **default unchecked**. When checked, reveals:
- the **Amtgard | Kingdom** tier question toggle (with the "reviewed by ORK admins / your kingdom's officers" note),
- the license agreement, agree checkbox, and full-legal-name signature.

Action button reads **"Use on My Scroll"** when not sharing, **"Use & Submit to Library"** when sharing.

---

## 8. AJAX endpoints (`controller.ScrollArtworkAjax.php`)

Existing endpoints to **extend**: `upload` (add `visibility`, `owner_kingdom_id`, `category_id`), `browse`/`search` (add tier + category + zone filters, enforce visibility), `pending` (make tier-aware — route global vs kingdom by authority), `approve`/`reject` (tier-aware authority), `my_uploads`, `delete`, `template_guide`.

**New endpoints:** category CRUD for admins (list/create/update/retire on `ork_scroll_artwork_category`); edit-metadata and withdraw for a submitter's own rows (if not already covered by `upload`/`delete`).

Auth helpers already present: `require_login()`, `require_admin()` (`AUTH_ADMIN` + `AUTH_EDIT`). Add a kingdom-officer authority check for the kingdom moderation path.

---

## 9. License boilerplate (DRAFT — pending human/legal review)

> By submitting this artwork, I affirm that I created it or otherwise hold the rights to it, and that it does not infringe anyone else's copyright. I grant Amtgard — and its kingdoms, parks, and members — a perpetual, worldwide, royalty-free, non-exclusive license to store, reproduce, modify (including recoloring and resizing to fit a scroll), and display this artwork on award scrolls and related Amtgard materials. I understand my submission will be reviewed before it appears in the library, that it may be removed at any time, and that typing my full legal name below constitutes my electronic signature to these terms.

**This wording is a starting point and must be reviewed by a human (ideally with legal input) before launch.** The signed name + timestamp are persisted to `license_signer_name` / `license_signed_at`.

---

## 10. Edge cases & error handling

- File validation reuses the existing guard (PNG/JPEG/GIF, ≤ 2 MB); the ephemeral raw-image export request gets the same size cap.
- **Kingdom-private visibility** enforced on browse *and* on library-insert (can't insert another kingdom's private graphic). Note: once rendered onto a scroll, the art is baked into the output image — selection is gated, not the resulting pixels.
- Retiring a category never orphans graphics (existing `category_id` retained).
- Rejected submissions can be edited + resubmitted (new pending row/state).
- Orphaned-file cleanup on delete; concurrent-approval idempotency (already-decided rows can't be re-decided).
- All approve/reject/category mutations re-check authority server-side.
- Follow project DB conventions: `$DB->Clear()` before raw Execute/DataSet; to clear a column via yapo assign `''` not `null`; read kingdom config / authority via existing helpers.

---

## 11. Testing

Follows the existing `tests/scroll/` PHP harness + the project's curl-auth AJAX session pattern:

- Visibility filtering — global visible to all; kingdom-private only to owning kingdom; other kingdoms' private hidden.
- Tiered-moderation authority — officer cannot approve global; admin can; officer sees only their kingdom's queue.
- Category CRUD + retire-without-orphan.
- Ephemeral raw-image export compositing (the `artwork_<slot>_raw` path) at correct per-zone opacity.
- License capture persistence (name + timestamp).
- Submission state machine — pending → approved/rejected → resubmit; idempotent re-decide guard.
- Dark-mode walkthrough of every new surface (`html[data-theme="dark"]`).

---

## 12. Out of scope (for now)

- Per-user **private** asset library (non-shared in-builder uploads are ephemeral, not persisted).
- In-builder kingdom-private submission is supported via the toggle, but the richer submission management lives on the standalone module.
- Admin-managed categories start as a simple lookup table; no nested/hierarchical categories.
- Versioning/replacement of an approved graphic's file (re-submit as new instead).

---

## 13. Open items before launch

1. **Legal/human review of the license text** (§9).
2. Confirm whether in-builder kingdom-private submissions should appear in the submitter's kingdom officer queue immediately (assumed yes per §6).
