<?php
	$error  = isset($error)  ? $error  : '';
	$detail = isset($detail) ? $detail : '';
	$isSuccess = (strlen($error) > 0);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
/* ===========================
   Forgot Username Page (fu-)
   =========================== */
.fu-wrap {
	max-width: 420px;
	margin: 40px auto;
	background: #fff;
	border-radius: 12px;
	box-shadow: 0 8px 32px rgba(0,0,0,0.12);
	padding: 44px 40px 36px;
}
.fu-logo-row {
	display: flex;
	align-items: center;
	gap: 12px;
	margin-bottom: 28px;
}
.fu-logo-icon {
	font-size: 26px;
	color: #2c5282;
}
.fu-logo-text {
	font-size: 18px;
	font-weight: 700;
	color: #1a202c;
}
.fu-logo-text span { color: #2c5282; }
.fu-heading {
	font-size: 21px;
	font-weight: 700;
	color: #1a202c;
	margin: 0 0 6px 0;
	background: transparent !important;
	border: none !important;
	padding: 0 !important;
	border-radius: 0 !important;
	text-shadow: none !important;
}
.fu-subheading {
	font-size: 13px;
	color: #718096;
	margin: 0 0 24px 0;
	line-height: 1.5;
}
.fu-field { margin-bottom: 0; }
.fu-label {
	display: block;
	font-size: 12px;
	font-weight: 600;
	color: #4a5568;
	text-transform: uppercase;
	letter-spacing: 0.5px;
	margin-bottom: 6px;
}
.fu-input {
	width: 100%;
	padding: 10px 12px;
	border: 1px solid #cbd5e0;
	border-radius: 6px;
	font-size: 14px;
	color: #2d3748;
	background: #f7fafc;
	transition: border-color 0.15s, box-shadow 0.15s;
	box-sizing: border-box;
}
.fu-input:focus {
	outline: none;
	border-color: #4299e1;
	box-shadow: 0 0 0 3px rgba(66,153,225,0.15);
	background: #fff;
}
.fu-btn {
	width: 100%;
	padding: 11px;
	background: #2c5282;
	color: #fff;
	border: none;
	border-radius: 6px;
	font-size: 15px;
	font-weight: 600;
	cursor: pointer;
	transition: background 0.15s;
	margin-top: 20px;
}
.fu-btn:hover { background: #2a4a7f; }
.fu-back {
	display: block;
	margin-top: 16px;
	text-align: center;
	font-size: 13px;
	color: #3182ce;
	text-decoration: none;
}
.fu-back:hover { text-decoration: underline; }
.fu-message {
	margin-top: 16px;
	padding: 10px 14px;
	border-radius: 6px;
	font-size: 13px;
	line-height: 1.5;
}
.fu-message-success {
	background: #f0fff4;
	border: 1px solid #9ae6b4;
	color: #276749;
}
.fu-message-detail {
	font-weight: 600;
	margin-top: 4px;
}

html[data-theme="dark"] .fu-wrap {
	background: var(--ork-card-bg);
	box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}
html[data-theme="dark"] .fu-logo-icon { color: #90cdf4; }
html[data-theme="dark"] .fu-logo-text { color: var(--ork-text); }
html[data-theme="dark"] .fu-logo-text span { color: #90cdf4; }
html[data-theme="dark"] .fu-heading { color: var(--ork-text); }
html[data-theme="dark"] .fu-subheading { color: var(--ork-text-secondary); }
html[data-theme="dark"] .fu-label { color: var(--ork-text-secondary); }
html[data-theme="dark"] .fu-input {
	background: var(--ork-bg-secondary);
	border-color: var(--ork-border);
	color: var(--ork-text);
}
html[data-theme="dark"] .fu-input:focus {
	background: var(--ork-bg-tertiary);
	border-color: #63b3ed;
	box-shadow: 0 0 0 3px rgba(99,179,237,0.2);
}
html[data-theme="dark"] .fu-btn { background: #2b4c7e; }
html[data-theme="dark"] .fu-btn:hover { background: #3a5f96; }
html[data-theme="dark"] .fu-back { color: #90cdf4; }
html[data-theme="dark"] .fu-message-success {
	background: #1c4532;
	border-color: #276749;
	color: #9ae6b4;
}
</style>

<div class="fu-wrap">
	<div class="fu-logo-row">
		<i class="fas fa-user-circle fu-logo-icon"></i>
		<div class="fu-logo-text">Amtgard <span>Online Record Keeper</span></div>
	</div>

	<h2 class="fu-heading">Recover your username</h2>
	<p class="fu-subheading">Enter the email address on your ORK profile and we'll send your username to it. If you can't remember which email you used, reach out to your Park or Kingdom Prime Minister.</p>

	<form action="<?= UIR ?>Login/forgotusername/recover" method="POST">
		<div class="fu-field">
			<label class="fu-label" for="fu-email">Email address</label>
			<input class="fu-input" type="email" id="fu-email" name="email" autocomplete="email" autofocus required />
		</div>

		<button type="submit" class="fu-btn">
			<i class="fas fa-paper-plane" style="margin-right:7px"></i> Email My Username
		</button>
	</form>

	<?php if (strlen($error) > 0): ?>
		<div class="fu-message fu-message-success">
			<?= htmlspecialchars($error) ?>
			<?php if (strlen($detail) > 0): ?>
				<div class="fu-message-detail"><?= htmlspecialchars($detail) ?></div>
			<?php endif; ?>
		</div>
	<?php endif; ?>

	<a href="<?= UIR ?>Login" class="fu-back">
		<i class="fas fa-arrow-left" style="margin-right:5px;font-size:11px"></i> Back to sign in
	</a>
</div>
