<div class="sl-notfound">
    <i class="fas fa-link" aria-hidden="true"></i>
    <h2>Shortcut not found</h2>
    <p>We couldn't find <strong>/me/<?= $stub ?></strong>. It may have been changed or never existed.</p>
    <p>
        <a class="sl-notfound-btn" href="<?= htmlspecialchars($search_url, ENT_QUOTES) ?>">Search the ORK</a>
        <a class="sl-notfound-btn sl-notfound-btn--ghost" href="<?= htmlspecialchars($home_url, ENT_QUOTES) ?>">Go home</a>
    </p>
</div>
<style>
.sl-notfound{max-width:520px;margin:60px auto;padding:32px;text-align:center;
  background:var(--ork-card-bg,#fff);border:1px solid var(--ork-border,#e2e8f0);border-radius:10px}
.sl-notfound i{font-size:34px;color:var(--ork-text-secondary,#a0aec0);margin-bottom:8px}
.sl-notfound h2{background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;
  margin:6px 0 10px;font-size:22px;color:var(--ork-text,#2d3748)}
.sl-notfound p{color:var(--ork-text-secondary,#4a5568);margin:6px 0}
.sl-notfound-btn{display:inline-block;margin:12px 6px 0;padding:8px 16px;border-radius:6px;
  background:#2b6cb0;color:#fff;text-decoration:none;font-weight:600}
.sl-notfound-btn--ghost{background:transparent;color:var(--ork-text,#2d3748);
  border:1px solid var(--ork-border,#cbd5e0)}
html[data-theme="dark"] .sl-notfound-btn--ghost{color:var(--ork-text-secondary,#cbd5e0)}
</style>
