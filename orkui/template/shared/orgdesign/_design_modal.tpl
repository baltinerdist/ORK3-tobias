<?php
/**
 * Shared Org Design modal (Header / About / Milestones).
 *
 * Plain-PHP include — od- prefixed, org-neutral. Renders ONLY for managers; the
 * caller guards on $ctx['can_manage'] but we double-guard here for safety.
 *
 * Expects in scope:
 *   $ctx['org']           : org slug for the AJAX base, e.g. 'kingdom'
 *   $ctx['id']            : (int) entity id
 *   $ctx['ajax']          : AJAX base path, e.g. 'KingdomAjax/kingdom'
 *   $ctx['org_name']      : display name (heading + font sample + about label)
 *   $ctx['can_manage']    : bool
 *   $ctx['about_text']    : string markdown
 *   $ctx['our_history']   : string markdown
 *   $ctx['color_primary'] / color_accent / color_secondary : hex strings
 *   $ctx['overlay']       : low|med|high|vignette
 *   $ctx['name_font']     : font key
 *   $ctx['tagline']       : string
 *   $ctx['announcement']  / announcement_until : strings
 *   $ctx['social_links']  : slug => url map
 *   $ctx['about_enabled'] : 0|1 (opt-in gate); omit/false => no opt-in toggle
 *   $ctx['milestone_config'] : decoded config array (type => bool, newest_first)
 *   $ctx['custom_milestones'] : array of custom (non-derived) milestone rows
 *   $ctx['features']      : ['reign'=>bool,'recruitment'=>bool,'how_to_join'=>bool]
 *   $ctx['reign']         : ['monarch_started'=>'','regent_started'=>'','lore'=>'']  (when features.reign)
 *   $ctx['recruitment']   : ['status'=>'open|invite|closed|'']                       (when features.recruitment)
 *   $ctx['how_to_join']   : string markdown                                           (when features.how_to_join)
 *
 *   $OD_SOCIAL_PLATFORMS / $OD_FONTS : from _helpers.php
 */
if (empty($ctx['can_manage'])) {
    return;
}

$_odOrg     = (string)($ctx['org'] ?? '');
$_odId      = (int)($ctx['id'] ?? 0);
$_odAjax    = (string)($ctx['ajax'] ?? '');
$_odName    = (string)($ctx['org_name'] ?? '');
$_odAbout   = (string)($ctx['about_text'] ?? '');
$_odHistory = (string)($ctx['our_history'] ?? '');
$_odPrimary = trim((string)($ctx['color_primary'] ?? ''));
$_odAccent  = trim((string)($ctx['color_accent'] ?? ''));
$_odSecond  = trim((string)($ctx['color_secondary'] ?? ''));
$_odOverlay = strtolower(trim((string)($ctx['overlay'] ?? 'med')));
if (!in_array($_odOverlay, ['low', 'med', 'high', 'vignette'], true)) {
    $_odOverlay = 'med';
}
$_odFont      = (string)($ctx['name_font'] ?? '');
$_odTagline   = (string)($ctx['tagline'] ?? '');
$_odAnnounce  = (string)($ctx['announcement'] ?? '');
$_odAnnUntil  = (string)($ctx['announcement_until'] ?? '');
$_odSocial    = isset($ctx['social_links']) && is_array($ctx['social_links']) ? $ctx['social_links'] : [];
$_odPlatforms = isset($OD_SOCIAL_PLATFORMS) && is_array($OD_SOCIAL_PLATFORMS) ? $OD_SOCIAL_PLATFORMS : [];

$_odFeatures   = isset($ctx['features']) && is_array($ctx['features']) ? $ctx['features'] : [];
$_odHasReign   = !empty($_odFeatures['reign']);
$_odHasRecruit = !empty($_odFeatures['recruitment']);
$_odHasJoin    = !empty($_odFeatures['how_to_join']);

$_odReign = isset($ctx['reign']) && is_array($ctx['reign']) ? $ctx['reign'] : [];
$_odMonarchStarted = trim((string)($_odReign['monarch_started'] ?? ''));
$_odRegentStarted  = trim((string)($_odReign['regent_started'] ?? ''));
$_odReignLore      = (string)($_odReign['lore'] ?? '');

$_odRecruitStatus = '';
if ($_odHasRecruit) {
    $_odRecruitStatus = strtolower(trim((string)(($ctx['recruitment']['status'] ?? ''))));
    if (!in_array($_odRecruitStatus, ['open', 'invite', 'closed'], true)) {
        $_odRecruitStatus = '';
    }
}
$_odHowToJoin = $_odHasJoin ? (string)($ctx['how_to_join'] ?? '') : '';

// Opt-in gate: render the toggle only when the feature provides an about_enabled value.
$_odHasOptIn   = array_key_exists('about_enabled', $ctx);
$_odAboutOn    = ((int)($ctx['about_enabled'] ?? 0)) === 1;

// Milestone visibility config.
$_odMsCfg = isset($ctx['milestone_config']) && is_array($ctx['milestone_config']) ? $ctx['milestone_config'] : [];
$_odMsVisible = function ($type) use ($_odMsCfg) {
    if (!array_key_exists($type, $_odMsCfg)) {
        return true;
    }
    return !empty($_odMsCfg[$type]);
};
$_odMsNewestFirst = !empty($_odMsCfg['newest_first']);

$_odIcons = ['fa-star', 'fa-trophy', 'fa-flag', 'fa-chess-rook', 'fa-crown', 'fa-medal', 'fa-shield-alt', 'fa-fire', 'fa-bolt', 'fa-scroll', 'fa-campground', 'fa-map-marker-alt', 'fa-users', 'fa-dragon', 'fa-hammer', 'fa-heart'];
?>
<div class="od-dm-overlay" id="od-dm-overlay"
     data-od-org="<?= htmlspecialchars($_odOrg) ?>"
     data-od-id="<?= $_odId ?>"
     data-od-ajax="<?= htmlspecialchars($_odAjax) ?>"
     data-od-uir="<?= htmlspecialchars(UIR) ?>"
     data-od-name="<?= htmlspecialchars($_odName) ?>"
     data-od-name-font="<?= htmlspecialchars($_odFont) ?>">
	<div class="od-dm-modal">
		<div class="od-dm-header">
			<h3 class="od-dm-title"><i class="fas fa-palette"></i>Design <?= htmlspecialchars($_odName) ?></h3>
			<button class="od-dm-close" id="od-dm-close" aria-label="Close">&times;</button>
		</div>
		<div class="od-dm-tabs">
			<button class="od-dm-tab od-active" data-odtab-dm="about"><i class="fas fa-scroll"></i> About</button>
			<button class="od-dm-tab" data-odtab-dm="header"><i class="fas fa-image"></i> Header</button>
			<button class="od-dm-tab" data-odtab-dm="milestones"><i class="fas fa-stream"></i> Milestones</button>
		</div>
		<div class="od-dm-body">
			<?php if ($_odHasOptIn): ?>
			<div class="od-dm-optin">
				<label class="od-dm-optin-switch" data-tip="While off, visitors see your current About page.">
					<input type="checkbox" id="od-dm-about-enabled"<?= $_odAboutOn ? ' checked' : '' ?> />
					<span class="od-dm-optin-slider"></span>
				</label>
				<div class="od-dm-optin-text">
					<div class="od-dm-optin-label">Enable the About Page</div>
					<div class="od-dm-optin-hint">While off, visitors see your current About page. Turn it on to publish the new design (custom About, History, Reign, Milestones). Hero colors &amp; tagline always apply.</div>
				</div>
			</div>
			<?php endif; ?>
			<div class="od-dm-error" id="od-dm-error"></div>

			<!-- ===== Header panel ===== -->
			<div class="od-dm-panel" id="od-dm-panel-header">
				<div class="od-dm-hint" style="margin-bottom:12px"><i class="fas fa-moon" style="margin-right:6px"></i><strong>Dark mode viewers</strong> see your hero with a slight darkening filter so colors stay readable. Preview both themes with the moon icon in the site header before saving.</div>

				<div class="od-dm-field">
					<label>Color Presets</label>
					<div class="od-dm-preset-grid" id="od-dm-presets">
						<div class="od-dm-swatch" data-primary="#2c5282" data-accent="#4299e1" style="background:#2c5282"></div>
						<div class="od-dm-swatch" data-primary="#276749" data-accent="#48bb78" style="background:#276749"></div>
						<div class="od-dm-swatch" data-primary="#9b2c2c" data-accent="#fc8181" style="background:#9b2c2c"></div>
						<div class="od-dm-swatch" data-primary="#553c9a" data-accent="#9f7aea" style="background:#553c9a"></div>
						<div class="od-dm-swatch" data-primary="#975a16" data-accent="#ecc94b" style="background:#975a16"></div>
						<div class="od-dm-swatch" data-primary="#2d3748" data-accent="#a0aec0" style="background:#2d3748"></div>
						<div class="od-dm-swatch" data-primary="#285e61" data-accent="#38b2ac" style="background:#285e61"></div>
						<div class="od-dm-swatch" data-primary="#744210" data-accent="#ed8936" style="background:#744210"></div>
					</div>
				</div>

				<div class="od-dm-field">
					<label>Gradient Presets</label>
					<div class="od-dm-preset-grid" id="od-dm-gradient-presets">
						<div class="od-dm-swatch" data-primary="#1a365d" data-accent="#4299e1" data-secondary="#553c9a" style="background:linear-gradient(135deg,#1a365d,#553c9a)"></div>
						<div class="od-dm-swatch" data-primary="#1a4731" data-accent="#48bb78" data-secondary="#2c5282" style="background:linear-gradient(135deg,#1a4731,#2c5282)"></div>
						<div class="od-dm-swatch" data-primary="#742a2a" data-accent="#fc8181" data-secondary="#975a16" style="background:linear-gradient(135deg,#742a2a,#975a16)"></div>
						<div class="od-dm-swatch" data-primary="#44337a" data-accent="#d6bcfa" data-secondary="#97266d" style="background:linear-gradient(135deg,#44337a,#97266d)"></div>
						<div class="od-dm-swatch" data-primary="#234e52" data-accent="#38b2ac" data-secondary="#276749" style="background:linear-gradient(135deg,#234e52,#276749)"></div>
						<div class="od-dm-swatch" data-primary="#2c5282" data-accent="#4299e1" data-secondary="#285e61" style="background:linear-gradient(135deg,#2c5282,#285e61)"></div>
						<div class="od-dm-swatch" data-primary="#744210" data-accent="#ecc94b" data-secondary="#9b2c2c" style="background:linear-gradient(135deg,#744210,#9b2c2c)"></div>
						<div class="od-dm-swatch" data-primary="#1a202c" data-accent="#a0aec0" data-secondary="#2d3748" style="background:linear-gradient(135deg,#1a202c,#2d3748)"></div>
					</div>
				</div>

				<div class="od-dm-field">
					<label>Custom Colors</label>
					<div class="od-dm-color-row">
						<div class="od-dm-color-col">
							<div class="od-dm-hint" style="margin-bottom:4px">Primary (hero background)</div>
							<div class="od-dm-color-input">
								<input type="color" id="od-dm-color-primary" value="<?= htmlspecialchars($_odPrimary ?: '#2c5282') ?>" />
								<input type="text" id="od-dm-color-primary-hex" value="<?= htmlspecialchars($_odPrimary ?: '#2c5282') ?>" maxlength="7" />
							</div>
						</div>
						<div class="od-dm-color-col">
							<div class="od-dm-hint" style="margin-bottom:4px">Accent (links &amp; tabs)</div>
							<div class="od-dm-color-input">
								<input type="color" id="od-dm-color-accent" value="<?= htmlspecialchars($_odAccent ?: '#4299e1') ?>" />
								<input type="text" id="od-dm-color-accent-hex" value="<?= htmlspecialchars($_odAccent ?: '#4299e1') ?>" maxlength="7" />
							</div>
						</div>
					</div>
				</div>

				<div class="od-dm-field">
					<label>Gradient (Optional)</label>
					<div class="od-dm-color-row">
						<div class="od-dm-color-col">
							<div class="od-dm-hint" style="margin-bottom:4px">Secondary color</div>
							<div class="od-dm-color-input">
								<input type="color" id="od-dm-color-secondary" value="<?= htmlspecialchars($_odSecond ?: ($_odPrimary ?: '#2c5282')) ?>" />
								<input type="text" id="od-dm-color-secondary-hex" value="<?= htmlspecialchars($_odSecond) ?>" maxlength="7" placeholder="None" />
							</div>
						</div>
						<div class="od-dm-color-col" style="display:flex;align-items:center;padding-top:18px">
							<label style="text-transform:none;letter-spacing:0;display:flex;align-items:center;gap:6px;cursor:pointer;font-weight:500;color:#4a5568;font-size:13px;margin-bottom:0">
								<input type="checkbox" id="od-dm-gradient-enabled" <?= $_odSecond !== '' ? 'checked' : '' ?> />
								Enable gradient
							</label>
						</div>
					</div>
				</div>

				<div class="od-dm-field">
					<label>Heraldry Overlay Strength</label>
					<div class="od-dm-hint" style="margin-bottom:6px">Controls how much the heraldry shows through the hero background.</div>
					<div class="od-dm-overlay-btns">
						<button type="button" class="od-dm-overlay-btn<?= $_odOverlay === 'low' ? ' od-active' : '' ?>" data-overlay="low">Low</button>
						<button type="button" class="od-dm-overlay-btn<?= $_odOverlay === 'med' ? ' od-active' : '' ?>" data-overlay="med">Medium</button>
						<button type="button" class="od-dm-overlay-btn<?= $_odOverlay === 'high' ? ' od-active' : '' ?>" data-overlay="high">High</button>
						<button type="button" class="od-dm-overlay-btn<?= $_odOverlay === 'vignette' ? ' od-active' : '' ?>" data-overlay="vignette">Vignette</button>
					</div>
					<input type="hidden" id="od-dm-hero-overlay" value="<?= htmlspecialchars($_odOverlay) ?>" />
				</div>

				<div class="od-dm-field">
					<label>Name Font</label>
					<div class="od-dm-hint" style="margin-bottom:6px">A decorative font for the name in the hero. Viewers with accessibility fonts enabled will see their preferred font instead.</div>
					<div class="od-dm-font-picker" id="od-dm-font-picker"></div>
				</div>

				<div class="od-dm-field">
					<label>Tagline</label>
					<div class="od-dm-hint" style="margin-bottom:6px">A short one-liner that appears under the name in the hero. 160 characters max.</div>
					<input type="text" id="od-dm-tagline" maxlength="160" value="<?= htmlspecialchars($_odTagline) ?>" placeholder="e.g. Honor, Glory, and the Sound of Sword on Shield." style="width:100%;padding:8px 10px;font-size:13px;border:1px solid #cbd5e0;border-radius:5px" />
					<div class="od-dm-counter" id="od-dm-tagline-counter">0 / 160</div>
				</div>

				<div class="od-dm-field">
					<label>Announcement Banner</label>
					<div class="od-dm-hint" style="margin-bottom:6px">A short amber banner that appears above the hero. Use for upcoming events, weather cancellations, or news. 280 characters max.</div>
					<textarea id="od-dm-announcement" maxlength="280" placeholder="e.g. Crown List sign-ups close Friday at midnight. RSVP on the events page!" style="width:100%;padding:8px 10px;font-size:13px;border:1px solid #cbd5e0;border-radius:5px;min-height:60px;resize:vertical"><?= htmlspecialchars($_odAnnounce) ?></textarea>
					<div class="od-dm-counter" id="od-dm-announcement-counter">0 / 280</div>
					<div style="display:flex;gap:8px;align-items:center;margin-top:8px;flex-wrap:wrap">
						<label style="font-size:12px;color:#4a5568;text-transform:none;letter-spacing:0;margin-bottom:0">Show until (optional):</label>
						<input type="date" id="od-dm-announcement-until" value="<?= htmlspecialchars(($_odAnnUntil !== '' && $_odAnnUntil !== '0000-00-00') ? $_odAnnUntil : '') ?>" style="padding:5px 8px;font-size:12px;border:1px solid #cbd5e0;border-radius:4px" />
						<button type="button" id="od-dm-announcement-clear" style="background:transparent;border:0;color:#718096;font-size:11px;cursor:pointer;text-decoration:underline">Clear date</button>
					</div>
				</div>
			</div>

			<!-- ===== About panel ===== -->
			<div class="od-dm-panel od-active" id="od-dm-panel-about">
				<?php if ($_odHasReign): ?>
				<div class="od-dm-field">
					<label>Reign Banner</label>
					<div class="od-dm-hint" style="margin-bottom:8px">Personae are derived from current Monarch &amp; Regent on the Officers list. Set reign-start dates and add optional lore (Markdown supported, 2,000 char max).</div>
					<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px">
						<div>
							<label style="font-size:11px;color:#4a5568;text-transform:none;letter-spacing:0">Monarch reign started</label>
							<input type="date" id="od-dm-monarch-reign" value="<?= htmlspecialchars(($_odMonarchStarted !== '' && $_odMonarchStarted !== '0000-00-00') ? $_odMonarchStarted : '') ?>" style="width:100%;padding:6px 8px;font-size:12px;border:1px solid #cbd5e0;border-radius:4px" />
						</div>
						<div>
							<label style="font-size:11px;color:#4a5568;text-transform:none;letter-spacing:0">Regent reign started</label>
							<input type="date" id="od-dm-regent-reign" value="<?= htmlspecialchars(($_odRegentStarted !== '' && $_odRegentStarted !== '0000-00-00') ? $_odRegentStarted : '') ?>" style="width:100%;padding:6px 8px;font-size:12px;border:1px solid #cbd5e0;border-radius:4px" />
						</div>
					</div>
					<div class="od-dm-md-toolbar">
						<label style="margin-bottom:0;font-size:11px;text-transform:none;letter-spacing:0;color:#4a5568">Reign Lore (optional, Markdown)</label>
						<div class="od-dm-md-toggle">
							<button type="button" class="od-active" data-odmd-target="edit" data-odmd-field="reign">Write</button>
							<button type="button" data-odmd-target="preview" data-odmd-field="reign">Preview</button>
						</div>
					</div>
					<textarea id="od-dm-reign-text" maxlength="2000" placeholder="Our Monarchy welcomes you to our kingdom! The theme for this reign is..." style="width:100%;min-height:120px"><?= htmlspecialchars($_odReignLore) ?></textarea>
					<div class="od-dm-md-preview" id="od-dm-reign-preview" style="display:none"></div>
					<div class="od-dm-counter" id="od-dm-reign-counter">0 / 2,000</div>
				</div>
				<?php endif; ?>

				<?php if ($_odHasRecruit): ?>
				<div class="od-dm-field">
					<label>Recruitment Status</label>
					<div class="od-dm-hint" style="margin-bottom:6px">Show visitors whether you're taking new members. Appears as a pill near the name.</div>
					<div class="od-dm-recruit-row" id="od-dm-recruit-row">
						<button type="button" class="od-dm-recruit-opt<?= $_odRecruitStatus === '' ? ' od-active' : '' ?>" data-recruit="">No pill</button>
						<button type="button" class="od-dm-recruit-opt<?= $_odRecruitStatus === 'open' ? ' od-active' : '' ?>" data-recruit="open">Open</button>
						<button type="button" class="od-dm-recruit-opt<?= $_odRecruitStatus === 'invite' ? ' od-active' : '' ?>" data-recruit="invite">By Invite</button>
						<button type="button" class="od-dm-recruit-opt<?= $_odRecruitStatus === 'closed' ? ' od-active' : '' ?>" data-recruit="closed">Closed</button>
					</div>
					<input type="hidden" id="od-dm-recruit-status" value="<?= htmlspecialchars($_odRecruitStatus) ?>" />
				</div>
				<?php endif; ?>

				<div class="od-dm-field">
					<label>Social Links</label>
					<div class="od-dm-hint" style="margin-bottom:8px">Add any platforms you use. Empty fields aren't shown. We'll add <code>https://</code> automatically if you omit it.</div>
					<?php foreach ($_odPlatforms as $_slug => $_meta): ?>
					<div class="od-dm-social-row">
						<div class="od-dm-social-label"><span class="od-dm-social-icon-chip" style="background:<?= htmlspecialchars($_meta['bg']) ?>"><i class="<?= $_meta['icon'] ?>"></i></span><?= htmlspecialchars($_meta['label']) ?></div>
						<input type="url" data-odsoc="<?= htmlspecialchars($_slug) ?>" placeholder="<?= htmlspecialchars($_meta['placeholder']) ?>" value="<?= htmlspecialchars((string)($_odSocial[$_slug] ?? '')) ?>" maxlength="500" />
					</div>
					<?php endforeach; ?>
				</div>

				<div class="od-dm-hint" style="margin-bottom:14px"><i class="fas fa-info-circle" style="margin-right:6px"></i>Both fields below support <strong>Markdown</strong>. Use <em>About</em> for a current snapshot; use <em>Our History</em> for the founding story, past reigns, and notable moments.</div>

				<div class="od-dm-field">
					<div class="od-dm-md-toolbar">
						<label style="margin-bottom:0">About <?= htmlspecialchars($_odName) ?></label>
						<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
							<div class="od-dm-md-toggle">
								<button type="button" class="od-active" data-odmd-target="edit" data-odmd-field="about">Write</button>
								<button type="button" data-odmd-target="preview" data-odmd-field="about">Preview</button>
							</div>
							<div class="od-dm-md-quick">
								<button type="button" class="od-dm-md-quick-btn" data-odquick="newbies" data-odfield="about"><i class="fas fa-hand-sparkles"></i> New Player Welcome</button>
								<button type="button" class="od-dm-md-quick-btn" data-odquick="vibe" data-odfield="about"><i class="fas fa-fire"></i> Kingdom Vibe</button>
								<button type="button" class="od-dm-md-quick-btn" data-odquick="findus" data-odfield="about"><i class="fas fa-map-marker-alt"></i> Where We Play</button>
							</div>
						</div>
					</div>
					<textarea id="od-dm-about-text" maxlength="10000" placeholder="Welcome... (Markdown supported)"><?= htmlspecialchars($_odAbout) ?></textarea>
					<div class="od-dm-md-preview" id="od-dm-about-preview" style="display:none"></div>
				</div>

				<div class="od-dm-field">
					<div class="od-dm-md-toolbar">
						<label style="margin-bottom:0">Our History</label>
						<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
							<div class="od-dm-md-toggle">
								<button type="button" class="od-active" data-odmd-target="edit" data-odmd-field="history">Write</button>
								<button type="button" data-odmd-target="preview" data-odmd-field="history">Preview</button>
							</div>
							<div class="od-dm-md-quick">
								<button type="button" class="od-dm-md-quick-btn" data-odquick="founding" data-odfield="history"><i class="fas fa-flag"></i> Founding</button>
								<button type="button" class="od-dm-md-quick-btn" data-odquick="charter" data-odfield="history"><i class="fas fa-chess-rook"></i> Charter</button>
								<button type="button" class="od-dm-md-quick-btn" data-odquick="pastmonarchs" data-odfield="history"><i class="fas fa-crown"></i> Past Monarchs</button>
							</div>
						</div>
					</div>
					<textarea id="od-dm-history-text" maxlength="10000" placeholder="The kingdom was founded in... (Markdown supported)"><?= htmlspecialchars($_odHistory) ?></textarea>
					<div class="od-dm-md-preview" id="od-dm-history-preview" style="display:none"></div>
				</div>

				<?php if ($_odHasJoin): ?>
				<div class="od-dm-field">
					<div class="od-dm-md-toolbar">
						<label style="margin-bottom:0">How to Join</label>
						<div class="od-dm-md-toggle">
							<button type="button" class="od-active" data-odmd-target="edit" data-odmd-field="join">Write</button>
							<button type="button" data-odmd-target="preview" data-odmd-field="join">Preview</button>
						</div>
					</div>
					<textarea id="od-dm-join-text" maxlength="10000" placeholder="How prospective members can get involved... (Markdown supported)"><?= htmlspecialchars($_odHowToJoin) ?></textarea>
					<div class="od-dm-md-preview" id="od-dm-join-preview" style="display:none"></div>
				</div>
				<?php endif; ?>
			</div>

			<!-- ===== Milestones panel ===== -->
			<div class="od-dm-panel" id="od-dm-panel-milestones">
				<div class="od-dm-hint" style="margin-bottom:10px">Milestones appear in date order. Some are derived from attendance data (first sign-in, count thresholds); the rest are custom entries you add below.</div>

				<div class="od-dm-field">
					<label>Visible Milestone Types</label>
					<div class="od-dm-ms-toggles" id="od-dm-ms-toggles">
						<label class="od-dm-ms-toggle"><input type="checkbox" data-odms-type="first_attendance" <?= $_odMsVisible('first_attendance') ? 'checked' : '' ?> /> <i class="fas fa-door-open"></i> First Attendance</label>
						<label class="od-dm-ms-toggle"><input type="checkbox" data-odms-type="attendance_count" <?= $_odMsVisible('attendance_count') ? 'checked' : '' ?> /> <i class="fas fa-clipboard-list"></i> Attendance Crossings</label>
						<label class="od-dm-ms-toggle"><input type="checkbox" data-odms-type="distinct_members" <?= $_odMsVisible('distinct_members') ? 'checked' : '' ?> /> <i class="fas fa-users"></i> Member Crossings</label>
						<label class="od-dm-ms-toggle"><input type="checkbox" data-odms-type="custom" <?= $_odMsVisible('custom') ? 'checked' : '' ?> /> <i class="fas fa-pen"></i> Custom Milestones</label>
					</div>
					<label class="od-dm-ms-toggle" style="margin-top:4px">
						<input type="checkbox" id="od-dm-ms-newest-first" <?= $_odMsNewestFirst ? 'checked' : '' ?> />
						Show newest first
					</label>
				</div>

				<div class="od-dm-field">
					<label>Custom Milestones</label>
					<div class="od-dm-ms-list" id="od-dm-ms-list"></div>
					<div class="od-dm-ms-add">
						<div>
							<input type="text" id="od-dm-ms-add-desc" placeholder="What happened?" maxlength="500" />
						</div>
						<div>
							<input type="date" id="od-dm-ms-add-date" />
						</div>
						<div>
							<button type="button" class="od-dm-btn od-dm-btn-primary" id="od-dm-ms-add-btn" style="width:100%"><i class="fas fa-plus"></i> Add</button>
						</div>
					</div>
					<div class="od-dm-ms-icons" id="od-dm-ms-icons" style="margin-top:8px">
						<?php foreach ($_odIcons as $_ic): ?>
						<div class="od-dm-ms-icon-opt<?= $_ic === 'fa-star' ? ' od-active' : '' ?>" data-icon="<?= htmlspecialchars($_ic) ?>"><i class="fas <?= htmlspecialchars($_ic) ?>"></i></div>
						<?php endforeach; ?>
					</div>
					<div class="od-dm-hint" id="od-dm-ms-add-err" style="color:#c53030;display:none;margin-top:6px"></div>
				</div>
			</div>
		</div>
		<div class="od-dm-footer">
			<button class="od-dm-btn" id="od-dm-cancel">Cancel</button>
			<button class="od-dm-btn od-dm-btn-primary" id="od-dm-save"><i class="fas fa-save"></i> Save Changes</button>
		</div>
	</div>
</div>

<?php
// Custom (non-derived) milestones bootstrapped into the JS module via a data island.
$_odCustomMs = isset($ctx['custom_milestones']) && is_array($ctx['custom_milestones']) ? $ctx['custom_milestones'] : [];
$_odCustomMsJson = array_map(function ($m) {
    return [
        'MilestoneId'   => (int)($m['MilestoneId'] ?? 0),
        'Icon'          => (string)($m['Icon'] ?? 'fa-star'),
        'Description'   => (string)($m['Description'] ?? ''),
        'MilestoneDate' => (string)($m['MilestoneDate'] ?? ''),
    ];
}, array_values($_odCustomMs));
?>
<script type="application/json" id="od-dm-bootstrap"><?= json_encode([
    'snippets'   => isset($OD_SNIPPETS) && is_array($OD_SNIPPETS) ? $OD_SNIPPETS : [],
    'fonts'      => isset($OD_FONTS) && is_array($OD_FONTS) ? $OD_FONTS : [],
    'customMs'   => $_odCustomMsJson,
    'sampleName' => $_odName,
    'nameFont'   => $_odFont,
    'features'   => [
        'reign'       => $_odHasReign,
        'recruitment' => $_odHasRecruit,
        'how_to_join' => $_odHasJoin,
    ],
    'hasOptIn'   => $_odHasOptIn,
], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?></script>
