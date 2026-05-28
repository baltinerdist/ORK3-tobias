<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
/* ===========================
   Login Help Page (lh-)
   =========================== */
.lh-wrap {
	max-width: 520px;
	margin: 40px auto;
	background: #fff;
	border-radius: 12px;
	box-shadow: 0 8px 32px rgba(0,0,0,0.12);
	padding: 44px 40px 36px;
}
.lh-logo-row {
	display: flex;
	align-items: center;
	gap: 12px;
	margin-bottom: 28px;
}
.lh-logo-icon {
	font-size: 26px;
	color: #2c5282;
}
.lh-logo-text {
	font-size: 18px;
	font-weight: 700;
	color: #1a202c;
}
.lh-logo-text span { color: #2c5282; }
.lh-heading {
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
.lh-subheading {
	font-size: 13px;
	color: #718096;
	margin: 0 0 24px 0;
	line-height: 1.5;
}
.lh-step {
	display: none;
}
.lh-step.active {
	display: block;
}
.lh-options {
	display: flex;
	flex-direction: column;
	gap: 10px;
	margin-top: 8px;
}
.lh-option-btn {
	width: 100%;
	padding: 14px 16px;
	background: #f7fafc;
	color: #2d3748;
	border: 1px solid #cbd5e0;
	border-radius: 8px;
	font-size: 14px;
	font-weight: 500;
	cursor: pointer;
	text-align: left;
	transition: background 0.15s, border-color 0.15s, transform 0.1s;
	display: flex;
	align-items: center;
	gap: 12px;
}
.lh-option-btn:hover {
	background: #ebf8ff;
	border-color: #4299e1;
}
.lh-option-btn:active {
	transform: scale(0.99);
}
.lh-option-btn i {
	color: #2c5282;
	font-size: 16px;
	flex-shrink: 0;
}
.lh-answer {
	margin-top: 12px;
	padding: 16px 18px;
	background: #ebf8ff;
	border: 1px solid #bee3f8;
	border-radius: 8px;
	font-size: 14px;
	color: #2b6cb0;
	line-height: 1.6;
}
.lh-answer-warn {
	background: #fffaf0;
	border-color: #fbd38d;
	color: #975a16;
}
.lh-answer i {
	margin-right: 6px;
}
.lh-back {
	display: inline-flex;
	align-items: center;
	margin-top: 18px;
	font-size: 13px;
	color: #3182ce;
	text-decoration: none;
	background: none;
	border: none;
	padding: 0;
	cursor: pointer;
}
.lh-back:hover { text-decoration: underline; }
.lh-back i { margin-right: 5px; font-size: 11px; }
.lh-footer-link {
	display: block;
	margin-top: 22px;
	text-align: center;
	font-size: 13px;
	color: #3182ce;
	text-decoration: none;
}
.lh-footer-link:hover { text-decoration: underline; }

/* ===========================
   Dark Mode
   =========================== */
html[data-theme="dark"] .lh-wrap {
	background: var(--ork-card-bg);
	box-shadow: 0 8px 32px rgba(0,0,0,0.4);
}
html[data-theme="dark"] .lh-logo-icon { color: #90cdf4; }
html[data-theme="dark"] .lh-logo-text { color: var(--ork-text); }
html[data-theme="dark"] .lh-logo-text span { color: #90cdf4; }
html[data-theme="dark"] .lh-heading { color: var(--ork-text); }
html[data-theme="dark"] .lh-subheading { color: var(--ork-text-secondary); }
html[data-theme="dark"] .lh-option-btn {
	background: var(--ork-bg-secondary);
	border-color: var(--ork-border);
	color: var(--ork-text);
}
html[data-theme="dark"] .lh-option-btn:hover {
	background: var(--ork-bg-tertiary);
	border-color: #63b3ed;
}
html[data-theme="dark"] .lh-option-btn i { color: #90cdf4; }
html[data-theme="dark"] .lh-answer {
	background: #1a365d;
	border-color: #2a4365;
	color: #90cdf4;
}
html[data-theme="dark"] .lh-answer-warn {
	background: #5f370e;
	border-color: #975a16;
	color: #fbd38d;
}
html[data-theme="dark"] .lh-back { color: #90cdf4; }
html[data-theme="dark"] .lh-footer-link { color: #90cdf4; }
</style>

<div class="lh-wrap">
	<div class="lh-logo-row">
		<i class="fas fa-life-ring lh-logo-icon"></i>
		<div class="lh-logo-text">Amtgard <span>Login Help</span></div>
	</div>

	<!-- Step 1: Which best describes your situation? -->
	<div class="lh-step active" id="lh-step-situation">
		<h2 class="lh-heading">Which best describes your situation?</h2>
		<p class="lh-subheading">Pick the option that sounds most like what's going on. We'll guide you from there.</p>

		<div class="lh-options">
			<button type="button" class="lh-option-btn" onclick="lhShow('lh-answer-noaccount')">
				<i class="fas fa-user-slash"></i>
				I don't have an ORK account.
			</button>
			<button type="button" class="lh-option-btn" onclick="lhPickBranch('username')">
				<i class="fas fa-user-question"></i>
				I have an ORK account, but I can't remember my username.
			</button>
			<button type="button" class="lh-option-btn" onclick="lhPickBranch('password')">
				<i class="fas fa-key"></i>
				I have an ORK account, but I can't remember my password.
			</button>
			<button type="button" class="lh-option-btn" onclick="lhPickBranch('expired')">
				<i class="fas fa-exclamation-triangle"></i>
				I have an ORK account, but my password isn't working or is expired.
			</button>
		</div>
	</div>

	<!-- Answer: No account -->
	<div class="lh-step" id="lh-answer-noaccount">
		<h2 class="lh-heading">Let's get you set up</h2>
		<div class="lh-answer">
			<i class="fas fa-info-circle"></i>
			No problem. Your ORK account is initially set up by your local park officers. Reach out to your Monarch or Prime Minister / Chancellor for assistance getting set up.
		</div>
		<button type="button" class="lh-back" onclick="lhBack('lh-step-situation')">
			<i class="fas fa-arrow-left"></i> Back to options
		</button>
	</div>

	<!-- Step 2: Do you have an email on your ORK profile? -->
	<div class="lh-step" id="lh-step-email">
		<h2 class="lh-heading">Do you have an email address on your ORK profile?</h2>
		<p class="lh-subheading">We can only send a reset if your profile has an email address on file.</p>

		<div class="lh-options">
			<button type="button" class="lh-option-btn" onclick="lhYesEmail()">
				<i class="fas fa-check-circle"></i>
				Yes, I do!
			</button>
			<button type="button" class="lh-option-btn" onclick="lhShow('lh-answer-officer')">
				<i class="fas fa-times-circle"></i>
				No, I don't!
			</button>
			<button type="button" class="lh-option-btn" onclick="lhShow('lh-answer-officer')">
				<i class="fas fa-question-circle"></i>
				I'm not sure...
			</button>
		</div>

		<button type="button" class="lh-back" onclick="lhBack('lh-step-situation')">
			<i class="fas fa-arrow-left"></i> Back to options
		</button>
	</div>

	<!-- Answer: Officer assistance needed -->
	<div class="lh-step" id="lh-answer-officer">
		<h2 class="lh-heading">You may need officer assistance</h2>
		<div class="lh-answer lh-answer-warn">
			<i class="fas fa-shield-alt"></i>
			You may need officer assistance to access your account. Reach out to your Monarch or Prime Minister / Chancellor for assistance getting back in.
		</div>
		<button type="button" class="lh-back" onclick="lhBack('lh-step-email')">
			<i class="fas fa-arrow-left"></i> Back
		</button>
	</div>

	<a href="<?= UIR ?>Login" class="lh-footer-link">
		<i class="fas fa-arrow-left" style="margin-right:5px;font-size:11px"></i> Back to sign in
	</a>
</div>

<script>
var lhBranch = null;
var LH_URL_FORGOT_PASSWORD = '<?= UIR ?>Login/forgotpassword';
var LH_URL_FORGOT_USERNAME = '<?= UIR ?>Login/forgotusername';

function lhShow(stepId) {
	document.querySelectorAll('.lh-step').forEach(function(el) {
		el.classList.remove('active');
	});
	var target = document.getElementById(stepId);
	if (target) target.classList.add('active');
	window.scrollTo({ top: 0, behavior: 'smooth' });
}
function lhBack(stepId) {
	lhShow(stepId);
}
function lhPickBranch(branch) {
	lhBranch = branch;
	lhShow('lh-step-email');
}
function lhYesEmail() {
	window.location = (lhBranch === 'username') ? LH_URL_FORGOT_USERNAME : LH_URL_FORGOT_PASSWORD;
}
</script>
