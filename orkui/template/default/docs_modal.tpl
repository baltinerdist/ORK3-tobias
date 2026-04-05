<!-- ORK Documentation Modal -->
<style>
/* ========== ORK Documentation Modal ========== */
.orkdoc-overlay {
	display: none;
	position: fixed;
	inset: 0;
	background: rgba(0,0,0,0.6);
	z-index: 11000;
}
.orkdoc-overlay.orkdoc-open {
	display: flex;
}

.orkdoc-container {
	display: flex;
	flex-direction: column;
	width: 100%;
	height: 100%;
	background: #fff;
}

/* --- Header --- */
.orkdoc-header {
	display: flex;
	align-items: center;
	justify-content: space-between;
	padding: 14px 24px;
	background: #2d3748;
	color: #fff;
	flex-shrink: 0;
	min-height: 56px;
	box-sizing: border-box;
}
.orkdoc-header-left {
	display: flex;
	align-items: center;
	gap: 12px;
}
.orkdoc-header-icon {
	font-size: 22px;
	color: #63b3ed;
}
.orkdoc-header-title {
	font-size: 18px;
	font-weight: 700;
	color: #fff;
	background: transparent;
	border: none;
	padding: 0;
	border-radius: 0;
	text-shadow: none;
}
.orkdoc-header-close {
	background: none;
	border: none;
	color: #a0aec0;
	font-size: 22px;
	cursor: pointer;
	padding: 4px 8px;
	border-radius: 4px;
	transition: color 0.15s, background 0.15s;
	line-height: 1;
}
.orkdoc-header-close:hover {
	color: #fff;
	background: rgba(255,255,255,0.1);
}
.orkdoc-mobile-toggle {
	display: none;
	background: none;
	border: none;
	color: #a0aec0;
	font-size: 20px;
	cursor: pointer;
	padding: 4px 8px;
	border-radius: 4px;
	margin-right: 8px;
}
.orkdoc-mobile-toggle:hover {
	color: #fff;
	background: rgba(255,255,255,0.1);
}

/* --- Body layout --- */
.orkdoc-body {
	display: flex;
	flex: 1;
	min-height: 0;
	overflow: hidden;
}

/* --- Sidebar --- */
.orkdoc-sidebar {
	width: 280px;
	min-width: 280px;
	background: #f7fafc;
	border-right: 1px solid #e2e8f0;
	display: flex;
	flex-direction: column;
	overflow: hidden;
	flex-shrink: 0;
}
.orkdoc-search-wrap {
	padding: 16px;
	border-bottom: 1px solid #e2e8f0;
	flex-shrink: 0;
}
.orkdoc-search {
	width: 100%;
	padding: 8px 12px 8px 34px;
	border: 1px solid #e2e8f0;
	border-radius: 6px;
	font-size: 13px;
	color: #2d3748;
	background: #fff;
	outline: none;
	box-sizing: border-box;
	font-family: inherit;
	transition: border-color 0.15s;
}
.orkdoc-search:focus {
	border-color: #4299e1;
	box-shadow: 0 0 0 3px rgba(66,153,225,0.15);
}
.orkdoc-search-wrap {
	position: relative;
}
.orkdoc-search-icon {
	position: absolute;
	left: 28px;
	top: 50%;
	transform: translateY(-50%);
	color: #a0aec0;
	font-size: 13px;
	pointer-events: none;
}
.orkdoc-nav {
	flex: 1;
	overflow-y: auto;
	padding: 8px 0;
}

/* --- Section accordion --- */
.orkdoc-section {
	margin: 0;
}
.orkdoc-section-btn {
	display: flex;
	align-items: center;
	gap: 10px;
	width: 100%;
	padding: 10px 16px;
	background: none;
	border: none;
	cursor: pointer;
	font-size: 13px;
	font-weight: 600;
	color: #2d3748;
	text-align: left;
	font-family: inherit;
	transition: background 0.12s;
}
.orkdoc-section-btn:hover {
	background: #edf2f7;
}
.orkdoc-section-btn.orkdoc-section-active {
	color: #4299e1;
}
.orkdoc-section-icon {
	width: 18px;
	text-align: center;
	color: #718096;
	font-size: 13px;
	flex-shrink: 0;
}
.orkdoc-section-btn.orkdoc-section-active .orkdoc-section-icon {
	color: #4299e1;
}
.orkdoc-section-chevron {
	margin-left: auto;
	font-size: 10px;
	color: #a0aec0;
	transition: transform 0.2s;
	flex-shrink: 0;
}
.orkdoc-section-btn.orkdoc-section-expanded .orkdoc-section-chevron {
	transform: rotate(90deg);
}
.orkdoc-article-list {
	display: none;
	padding: 0;
	margin: 0;
	list-style: none;
}
.orkdoc-article-list.orkdoc-articles-open {
	display: block;
}
.orkdoc-article-link {
	display: block;
	padding: 7px 16px 7px 44px;
	font-size: 13px;
	color: #4a5568;
	cursor: pointer;
	text-decoration: none;
	transition: background 0.12s, color 0.12s;
	border-left: 3px solid transparent;
}
.orkdoc-article-link:hover {
	background: #edf2f7;
	color: #2d3748;
}
.orkdoc-article-link.orkdoc-article-active {
	background: #ebf8ff;
	color: #4299e1;
	border-left-color: #4299e1;
	font-weight: 600;
}
.orkdoc-no-results {
	padding: 20px 16px;
	font-size: 13px;
	color: #a0aec0;
	text-align: center;
	font-style: italic;
}

/* --- Main content area --- */
.orkdoc-main {
	flex: 1;
	display: flex;
	flex-direction: column;
	overflow-y: auto;
	min-width: 0;
	background: #fff;
}
.orkdoc-breadcrumb {
	padding: 14px 32px;
	font-size: 12px;
	color: #718096;
	border-bottom: 1px solid #e2e8f0;
	flex-shrink: 0;
	display: flex;
	align-items: center;
	gap: 6px;
	flex-wrap: wrap;
}
.orkdoc-breadcrumb-link {
	color: #4299e1;
	cursor: pointer;
	text-decoration: none;
}
.orkdoc-breadcrumb-link:hover {
	text-decoration: underline;
}
.orkdoc-breadcrumb-sep {
	color: #cbd5e0;
}
.orkdoc-breadcrumb-current {
	color: #2d3748;
	font-weight: 600;
}
.orkdoc-content {
	flex: 1;
	padding: 32px;
	max-width: 800px;
	width: 100%;
	box-sizing: border-box;
}
.orkdoc-article-title {
	font-size: 26px;
	font-weight: 700;
	color: #2d3748;
	margin: 0 0 24px 0;
	padding-bottom: 16px;
	border-bottom: 2px solid #e2e8f0;
	background: transparent;
	border-top: none;
	border-left: none;
	border-right: none;
	border-radius: 0;
	text-shadow: none;
}
.orkdoc-article-body {
	font-size: 15px;
	color: #4a5568;
	line-height: 1.7;
}

/* Reset global h1-h6 gray box styles inside doc content */
.orkdoc-article-body h1,
.orkdoc-article-body h2,
.orkdoc-article-body h3,
.orkdoc-article-body h4,
.orkdoc-article-body h5,
.orkdoc-article-body h6 {
	background: transparent;
	border: none;
	padding: 0;
	border-radius: 0;
	text-shadow: none;
}
.orkdoc-article-body h1 { font-size: 24px; font-weight: 700; color: #2d3748; margin: 32px 0 12px; }
.orkdoc-article-body h2 { font-size: 20px; font-weight: 700; color: #2d3748; margin: 28px 0 10px; }
.orkdoc-article-body h3 { font-size: 17px; font-weight: 600; color: #2d3748; margin: 24px 0 8px; }
.orkdoc-article-body h4 { font-size: 15px; font-weight: 600; color: #4a5568; margin: 20px 0 8px; }
.orkdoc-article-body h5 { font-size: 14px; font-weight: 600; color: #4a5568; margin: 16px 0 6px; }
.orkdoc-article-body h6 { font-size: 13px; font-weight: 600; color: #718096; margin: 16px 0 6px; }
.orkdoc-article-body p { margin: 0 0 16px; }
.orkdoc-article-body ul,
.orkdoc-article-body ol { margin: 0 0 16px; padding-left: 24px; }
.orkdoc-article-body li { margin-bottom: 6px; }
.orkdoc-article-body a { color: #4299e1; text-decoration: none; }
.orkdoc-article-body a:hover { text-decoration: underline; }
.orkdoc-article-body code {
	background: #f1f5f9;
	padding: 2px 6px;
	border-radius: 4px;
	font-size: 13px;
	color: #d53f8c;
	font-family: 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
}
.orkdoc-article-body pre {
	background: #2d3748;
	color: #e2e8f0;
	padding: 16px;
	border-radius: 6px;
	overflow-x: auto;
	margin: 0 0 16px;
	font-size: 13px;
	line-height: 1.5;
}
.orkdoc-article-body pre code {
	background: none;
	color: inherit;
	padding: 0;
	border-radius: 0;
}
.orkdoc-article-body blockquote {
	border-left: 4px solid #4299e1;
	margin: 0 0 16px;
	padding: 12px 16px;
	background: #ebf8ff;
	color: #2d3748;
	border-radius: 0 6px 6px 0;
}
.orkdoc-article-body table {
	width: 100%;
	border-collapse: collapse;
	margin: 0 0 16px;
}
.orkdoc-article-body th,
.orkdoc-article-body td {
	padding: 8px 12px;
	border: 1px solid #e2e8f0;
	text-align: left;
}
.orkdoc-article-body th {
	background: #f7fafc;
	font-weight: 600;
	color: #2d3748;
}
.orkdoc-article-body img {
	max-width: 100%;
	height: auto;
	border-radius: 6px;
}

/* --- Welcome/landing state --- */
.orkdoc-welcome {
	display: flex;
	flex-direction: column;
	align-items: center;
	justify-content: center;
	text-align: center;
	padding: 60px 32px;
	flex: 1;
}
.orkdoc-welcome-icon {
	font-size: 48px;
	color: #cbd5e0;
	margin-bottom: 16px;
}
.orkdoc-welcome-title {
	font-size: 22px;
	font-weight: 700;
	color: #2d3748;
	margin-bottom: 8px;
	background: transparent;
	border: none;
	padding: 0;
	border-radius: 0;
	text-shadow: none;
}
.orkdoc-welcome-sub {
	font-size: 14px;
	color: #718096;
	max-width: 400px;
}

/* --- Mobile responsive --- */
@media (max-width: 768px) {
	.orkdoc-mobile-toggle {
		display: inline-flex;
	}
	.orkdoc-sidebar {
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		z-index: 100;
		transform: translateX(-100%);
		transition: transform 0.25s ease;
		box-shadow: none;
		width: 280px;
		min-width: 280px;
	}
	.orkdoc-sidebar.orkdoc-sidebar-open {
		transform: translateX(0);
		box-shadow: 4px 0 24px rgba(0,0,0,0.15);
	}
	.orkdoc-body {
		position: relative;
	}
	.orkdoc-content {
		padding: 20px 16px;
	}
	.orkdoc-breadcrumb {
		padding: 12px 16px;
	}
	.orkdoc-article-title {
		font-size: 22px;
	}
}
</style>

<div class="orkdoc-overlay" id="orkdoc-overlay">
	<div class="orkdoc-container">
		<!-- Header -->
		<div class="orkdoc-header">
			<div class="orkdoc-header-left">
				<button class="orkdoc-mobile-toggle" id="orkdoc-mobile-toggle" onclick="orkDocToggleSidebar()" title="Toggle navigation">
					<i class="fas fa-bars"></i>
				</button>
				<span class="orkdoc-header-icon"><i class="fas fa-book"></i></span>
				<span class="orkdoc-header-title">ORK Documentation</span>
			</div>
			<button class="orkdoc-header-close" onclick="orkDocClose()" title="Close (Esc)">
				<i class="fas fa-times"></i>
			</button>
		</div>

		<!-- Body -->
		<div class="orkdoc-body">
			<!-- Sidebar -->
			<div class="orkdoc-sidebar" id="orkdoc-sidebar">
				<div class="orkdoc-search-wrap">
					<span class="orkdoc-search-icon"><i class="fas fa-search"></i></span>
					<input type="text" class="orkdoc-search" id="orkdoc-search" placeholder="Search documentation..." autocomplete="off" />
				</div>
				<div class="orkdoc-nav" id="orkdoc-nav">
					<!-- Populated by JS -->
				</div>
			</div>

			<!-- Main content -->
			<div class="orkdoc-main" id="orkdoc-main">
				<!-- Populated by JS -->
			</div>
		</div>
	</div>
</div>

<script>
/* ========== ORK Documentation Data ========== */
var ORKDOC_DATA = {
	sections: [
		{
		  id: 'getting-started',
		  title: 'Getting Started',
		  icon: 'fas fa-rocket',
		  articles: [
		    {
		      id: 'welcome',
		      title: 'Welcome to the ORK',
		      body: '<h2>Welcome to the Online Record Keeper</h2>' +
		        '<p>The <strong>ORK</strong> (Online Record Keeper) is the official record-keeping system for <strong>Amtgard</strong>, an international live-action roleplaying (LARP) organization where players participate in foam-weapon combat, arts and sciences, and community building.</p>' +
		        '<p>The ORK tracks the essential records that make Amtgard work:</p>' +
		        '<ul>' +
		        '<li><strong>Players</strong> &mdash; Every Amtgard participant has a player profile with their persona name, awards, and history</li>' +
		        '<li><strong>Kingdoms &amp; Parks</strong> &mdash; Amtgard is organized into kingdoms (large regional chapters) and parks (local chapters that hold regular game days)</li>' +
		        '<li><strong>Attendance</strong> &mdash; Your attendance at park days and events earns class credits that advance your character</li>' +
		        '<li><strong>Awards</strong> &mdash; Honors given by the monarchy for achievements in combat, arts, service, and more</li>' +
		        '<li><strong>Events</strong> &mdash; Tournaments, feasts, quests, and multi-day gatherings hosted by parks and kingdoms</li>' +
		        '</ul>' +
		        '<h3>What Can You Do on the ORK?</h3>' +
		        '<p>Without logging in, you can browse kingdoms, search for players, and view public profiles. Once you log in, you unlock the full experience:</p>' +
		        '<ul>' +
		        '<li>View and edit your own player profile</li>' +
		        '<li>Recommend players for awards</li>' +
		        '<li>RSVP to upcoming events</li>' +
		        '<li>Access reports like Knights &amp; Masters, Top Parks, and Class Masters</li>' +
		        '<li>Manage your park or kingdom (if you hold an officer position)</li>' +
		        '</ul>' +
		        '<blockquote><strong>New to Amtgard?</strong> Visit <a href="https://play.amtgard.com" target="_blank">play.amtgard.com</a> to find a chapter near you and start playing!</blockquote>'
		    },
		    {
		      id: 'logging-in',
		      title: 'Logging In',
		      body: '<h2>Logging In</h2>' +
		        '<p>To access your ORK account, you have two ways to sign in.</p>' +
		        '<h3>Username and Password</h3>' +
		        '<p>On the login page, enter your <strong>Username</strong> and <strong>Password</strong>, then click the <strong>Sign In</strong> button. Your username was set when your account was created &mdash; it is typically different from your persona name.</p>' +
		        '<h3>Sign in with Amtgard</h3>' +
		        '<p>If your account is linked to the Amtgard identity service, you can click the <strong>Sign in with Amtgard</strong> button instead. This takes you to the Amtgard authentication page, where you log in once and are returned to the ORK automatically.</p>' +
		        '<h3>Password Expiration</h3>' +
		        '<p>For security, ORK passwords expire every <strong>2 years</strong>. When your password expires:</p>' +
		        '<ul>' +
		        '<li>You will not be able to log in until you change it</li>' +
		        '<li>If you are already viewing your profile, you will see a warning banner alerting you that your password has expired or is expiring soon</li>' +
		        '<li>Use the <strong>Forgot your password?</strong> link on the login page to receive a temporary password by email, then log in and set a new one</li>' +
		        '</ul>' +
		        '<blockquote><strong>Tip:</strong> Your profile page shows when your password expires under the <strong>Player Details</strong> card. If it is within two weeks, you will see a yellow warning.</blockquote>' +
		        '<h3>Don\'t Have an Account?</h3>' +
		        '<p>You cannot create your own account. Your local park\'s officers will create one for you when you start participating. Reach out to your park officers to get set up.</p>'
		    },
		    {
		      id: 'forgot-password',
		      title: 'Forgot Your Password',
		      body: '<h2>Forgot Your Password</h2>' +
		        '<p>If you cannot remember your password or it has expired, you can request a reset from the login page.</p>' +
		        '<h3>How to Reset Your Password</h3>' +
		        '<ol>' +
		        '<li>From the login page, click the <strong>Forgot your password?</strong> link</li>' +
		        '<li>Enter your <strong>Username</strong> and the <strong>Email address</strong> associated with your account</li>' +
		        '<li>Click <strong>Send Reset Email</strong></li>' +
		        '<li>Check your email for a message from the ORK with a temporary password</li>' +
		        '<li>Use the temporary password to log in, then immediately change your password from your profile</li>' +
		        '</ol>' +
		        '<h3>Important Details</h3>' +
		        '<ul>' +
		        '<li>The temporary password is valid for <strong>24 hours</strong> only &mdash; if you do not use it in time, you will need to request another one</li>' +
		        '<li>You must provide both your username and email &mdash; they must match what is on file for your account</li>' +
		        '<li>After logging in with the temporary password, change it right away by editing your profile (click the pencil icon on <strong>Player Details</strong>)</li>' +
		        '</ul>' +
		        '<blockquote><strong>Can\'t remember your username or email?</strong> Contact your park or kingdom Prime Minister. They can look up your account and help you regain access.</blockquote>'
		    },
		    {
		      id: 'navigation',
		      title: 'Navigating the ORK',
		      body: '<h2>Navigating the ORK</h2>' +
		        '<p>The ORK navigation bar appears at the bottom of every page. It provides quick access to all major features.</p>' +
		        '<h3>Breadcrumb Navigation (Left Side)</h3>' +
		        '<p>On the left side of the nav bar, you will see breadcrumb links showing where you are &mdash; for example, <strong>Kingdom &raquo; Park &raquo; Player</strong>. Click any breadcrumb to jump back to that page. On mobile, tap the home icon to return to the front page.</p>' +
		        '<h3>Search</h3>' +
		        '<p>Click the <strong>magnifying glass</strong> icon to open the universal search bar. Start typing to search across players, parks, kingdoms, and companies/households. See the <strong>Using Search</strong> article for more details.</p>' +
		        '<h3>Home Kingdom &amp; Park Links</h3>' +
		        '<p>When you are logged in, you will see quick-link buttons for your home <strong>kingdom</strong> (chess rook icon) and home <strong>park</strong> (tree icon). Click either one to jump directly to that page.</p>' +
		        '<h3>Resources Menu</h3>' +
		        '<p>Click the <strong>book</strong> icon to open the Resources dropdown, which contains:</p>' +
		        '<ul>' +
		        '<li><strong>Amtgard Website</strong> &mdash; The official amtgard.com site</li>' +
		        '<li><strong>Amtgard Wiki</strong> &mdash; Community wiki with rules, history, and more</li>' +
		        '<li><strong>Find a Chapter</strong> &mdash; Interactive map at play.amtgard.com</li>' +
		        '<li><strong>ORK Documentation</strong> &mdash; Opens this help system</li>' +
		        '</ul>' +
		        '<h3>Your Profile Menu</h3>' +
		        '<p>When logged in, your persona name and avatar appear on the far right. Click to open a dropdown with:</p>' +
		        '<ul>' +
		        '<li><strong>View Profile</strong> &mdash; Go to your player profile page</li>' +
		        '<li><strong>ORK Admin</strong> &mdash; Access the admin panel (only visible if you have officer or admin permissions)</li>' +
		        '<li><strong>Log Out</strong> &mdash; Sign out of your account</li>' +
		        '</ul>' +
		        '<p>If you are not logged in, you will see a <strong>Login</strong> button instead.</p>'
		    },
		    {
		      id: 'search',
		      title: 'Using Search',
		      body: '<h2>Using Search</h2>' +
		        '<p>The ORK has a universal search built into the navigation bar that lets you quickly find players, parks, kingdoms, and companies or households.</p>' +
		        '<h3>How to Search</h3>' +
		        '<ol>' +
		        '<li>Click the <strong>magnifying glass</strong> icon in the nav bar</li>' +
		        '<li>Type at least <strong>2 characters</strong> into the search field</li>' +
		        '<li>Results appear automatically in a dropdown, grouped by category: <strong>Players</strong>, <strong>Parks</strong>, <strong>Kingdoms</strong>, and <strong>Companies &amp; Households</strong></li>' +
		        '<li>Click any result to go to that page</li>' +
		        '</ol>' +
		        '<h3>Search Priority</h3>' +
		        '<p>Results from your home kingdom and park are prioritized and appear first. This makes it faster to find people in your local community.</p>' +
		        '<h3>Prefix Scoping</h3>' +
		        '<p>You can narrow your search to a specific kingdom or park using abbreviation prefixes:</p>' +
		        '<ul>' +
		        '<li><strong>KD: search term</strong> &mdash; Replace "KD" with a kingdom abbreviation (e.g., <strong>GE: Aragon</strong>) to search only within that kingdom</li>' +
		        '<li><strong>KD:PK search term</strong> &mdash; Add a park abbreviation after the kingdom (e.g., <strong>GE:CL Aragon</strong>) to search within a specific park of that kingdom</li>' +
		        '</ul>' +
		        '<h3>Full Player Search Page</h3>' +
		        '<p>For a more thorough search that includes inactive players, go to the <strong>Search Players</strong> link on the home page under Reports and Utilities. This opens a dedicated search page with results displayed in a table showing kingdom, park, and player name. Results include both active and inactive players, with inactive and banned players clearly marked.</p>' +
		        '<blockquote><strong>Tip:</strong> You can use the keyboard to navigate search results. Press <strong>Arrow Down</strong> to move into the results, <strong>Arrow Up</strong> to move back, and <strong>Escape</strong> to close the dropdown.</blockquote>'
		    }
		  ]
		},
		{
		  id: 'player-profiles',
		  title: 'Player Profiles',
		  icon: 'fas fa-user',
		  articles: [
		    {
		      id: 'viewing-profile',
		      title: 'Viewing Your Profile',
		      body: '<h2>Viewing Your Profile</h2>' +
		        '<p>Your player profile is the central hub for your Amtgard record. To get there, click your persona name in the top-right corner of the nav bar and choose <strong>View Profile</strong>.</p>' +
		        '<h3>My Amtgard Dashboard</h3>' +
		        '<p>When you view your own profile, the first tab you see is <strong>My Amtgard</strong> &mdash; a personal dashboard designed to give you a quick overview of your Amtgard life.</p>' +
		        '<p>The dashboard includes:</p>' +
		        '<ul>' +
		        '<li><strong>Alerts</strong> &mdash; Important notifications appear at the top, such as overdue dues, missing waiver status, or an expired/expiring password</li>' +
		        '<li><strong>Recent Attendance Sparkline</strong> &mdash; A visual chart showing your attendance over recent months, with green bars for weeks you attended and gray bars for weeks you did not</li>' +
		        '<li><strong>Class Progression</strong> &mdash; Your three most recently played classes with progress bars showing how close you are to the next level (levels 1 through 6)</li>' +
		        '<li><strong>Recent Awards</strong> &mdash; Your most recently received awards</li>' +
		        '<li><strong>Officer Positions</strong> &mdash; Any current officer roles you hold at your park or kingdom</li>' +
		        '<li><strong>Upcoming Events</strong> &mdash; Events you have RSVP\'d to</li>' +
		        '<li><strong>Member Tenure</strong> &mdash; How many years you have been a member, calculated from your oldest attendance record</li>' +
		        '</ul>' +
		        '<h3>Stats Row</h3>' +
		        '<p>Below the profile hero, four stat cards show your total <strong>Attendance</strong>, <strong>Awards</strong>, <strong>Titles</strong>, and <strong>Last Played</strong> class. Click any of these to jump directly to that tab.</p>' +
		        '<blockquote><strong>Note:</strong> The My Amtgard dashboard only appears when viewing your own profile. When viewing another player, the profile opens to the Awards tab instead.</blockquote>'
		    },
		    {
		      id: 'editing-profile',
		      title: 'Editing Your Profile',
		      body: '<h2>Editing Your Profile</h2>' +
		        '<p>You can update your account details from your profile page. Look for the pencil icon on the <strong>Player Details</strong> card in the sidebar and click it to open the Update Account modal.</p>' +
		        '<h3>Fields You Can Edit</h3>' +
		        '<ul>' +
		        '<li><strong>Given Name</strong> and <strong>Surname</strong> &mdash; Your real name (only visible to you and officers)</li>' +
		        '<li><strong>Persona</strong> &mdash; Your Amtgard character name (required)</li>' +
		        '<li><strong>Email</strong> &mdash; Used for password resets; keep this up to date</li>' +
		        '<li><strong>Username</strong> &mdash; Your login name (required)</li>' +
		        '<li><strong>Password</strong> &mdash; Enter a new password and confirm it to change; leave blank to keep your current password</li>' +
		        '<li><strong>Pronouns</strong> &mdash; Choose from a dropdown of common pronouns, or click <strong>Custom</strong> to build a custom set by selecting subjective, objective, possessive, possessive pronoun, and reflexive forms</li>' +
		        '</ul>' +
		        '<h3>Uploading a Player Photo</h3>' +
		        '<p>Your player photo appears as the circular avatar on your profile. To update it:</p>' +
		        '<ol>' +
		        '<li>Hover over your photo and click the <strong>camera icon</strong> that appears</li>' +
		        '<li>Choose an image file (JPEG, PNG, or GIF, maximum 340 KB &mdash; larger images are automatically resized)</li>' +
		        '<li>Use the crop tool to adjust the framing</li>' +
		        '<li>Click <strong>Upload</strong> to save</li>' +
		        '</ol>' +
		        '<h3>Administrative Fields (Officers Only)</h3>' +
		        '<p>If you are an officer with edit permissions for this player\'s park, you will also see administrative options including <strong>Status</strong> (Visible/Retired), <strong>Waiver</strong> status, <strong>Restricted Account</strong> toggle, and <strong>Park Member Since</strong> date.</p>'
		    },
		    {
		      id: 'profile-sections',
		      title: 'Profile Sections',
		      body: '<h2>Profile Sections</h2>' +
		        '<p>Your player profile is organized into tabs. Each tab contains a sortable table of records.</p>' +
		        '<h3>Awards Tab</h3>' +
		        '<p>Lists every award you have received, with columns for <strong>Award Name</strong>, <strong>Date</strong>, <strong>Rank/Ladder</strong> (the level of the award), <strong>Given By</strong> (who bestowed it), and <strong>Entered By</strong>. Click any column header to sort. If an award is missing the "Given By" information, a red warning icon explains that the record is incomplete.</p>' +
		        '<h3>Titles Tab</h3>' +
		        '<p>Shows titles (like Lord, Lady, Baronet, etc.) and officer roles (like Monarch, Regent, Prime Minister). Titles include the date awarded and who bestowed the title. Officer roles show the position held, the park or kingdom, and the term dates.</p>' +
		        '<h3>Attendance Tab</h3>' +
		        '<p>Your complete attendance history at park days and events. Each row shows the <strong>Date</strong>, <strong>Park</strong>, <strong>Event</strong> (if applicable), <strong>Class</strong> you played, and the number of <strong>Credits</strong> earned. Click column headers to sort by any field.</p>' +
		        '<h3>Recommendations Tab</h3>' +
		        '<p>Shows all open award recommendations for this player &mdash; awards that someone has suggested the player should receive. Each recommendation shows the <strong>Award</strong>, suggested <strong>Rank</strong>, the <strong>Recommender</strong>, and any notes they included. Officers can delete recommendations from this tab.</p>' +
		        '<h3>Notes Tab</h3>' +
		        '<p>Private notes attached to this player\'s record, typically used by officers for administrative purposes.</p>' +
		        '<h3>Class Levels Tab</h3>' +
		        '<p>Displays your level in each Amtgard class, calculated from attendance credits. The table shows the class name, total credits earned, reconciled credits (imported from older records), and your computed level (1 through 6). Classes where you have earned the Paragon award are specially marked.</p>'
		    },
		    {
		      id: 'heraldry',
		      title: 'Heraldry & Images',
		      body: '<h2>Heraldry &amp; Images</h2>' +
		        '<p>Your player profile has two images: a <strong>player photo</strong> and a <strong>heraldry</strong> image. Understanding the difference helps you set up your profile.</p>' +
		        '<h3>Player Photo</h3>' +
		        '<p>Your player photo is the circular image that appears in the top-left of your profile hero. This is typically a photo of you (in or out of costume). It appears next to your persona name throughout the ORK.</p>' +
		        '<h3>Heraldry</h3>' +
		        '<p>Heraldry is your character\'s coat of arms or personal device &mdash; an image that represents your Amtgard persona. Your heraldry appears as the background of your profile hero section and in the <strong>Heraldry</strong> card in the sidebar.</p>' +
		        '<h3>Uploading Images</h3>' +
		        '<p>To upload or change either image:</p>' +
		        '<ol>' +
		        '<li>Hover over the image and click the <strong>camera icon</strong> that appears</li>' +
		        '<li>Choose a file &mdash; accepted formats are <strong>JPEG</strong>, <strong>PNG</strong>, or <strong>GIF</strong></li>' +
		        '<li>Maximum file size is <strong>340 KB</strong> (larger images are automatically resized to fit)</li>' +
		        '<li>Use the crop tool to frame the image, then click <strong>Upload</strong></li>' +
		        '</ol>' +
		        '<p>You can also remove an existing image by clicking the <strong>Remove Image</strong> button in the upload modal.</p>' +
		        '<blockquote><strong>Tip:</strong> You can only edit images on your own profile. Officers with edit permissions for your park can also update your images.</blockquote>'
		    },
		    {
		      id: 'waivers-dues',
		      title: 'Waivers & Dues',
		      body: '<h2>Waivers &amp; Dues</h2>' +
		        '<p>Waivers and dues are important parts of your Amtgard membership. Your profile tracks both so you and your officers can stay on top of them.</p>' +
		        '<h3>Waivers</h3>' +
		        '<p>A waiver is a liability document that you sign at your local park acknowledging the physical nature of Amtgard activities. Having a waiver on file is required for participation.</p>' +
		        '<p>Your waiver status appears as a badge on your profile:</p>' +
		        '<ul>' +
		        '<li><strong>Waivered</strong> (blue badge) &mdash; Your park has a waiver on file for you</li>' +
		        '<li><strong>Needs Waiver</strong> (yellow badge) &mdash; No waiver is on file; speak with your park officers to get one signed</li>' +
		        '</ul>' +
		        '<p>Waiver status is managed by your park officers &mdash; they update it in the ORK after you sign a physical waiver at your park.</p>' +
		        '<h3>Dues</h3>' +
		        '<p>Dues are periodic membership payments made to your park or kingdom. Your dues status is displayed in the <strong>Dues</strong> card in the profile sidebar, showing each park where you have paid and the date through which your dues are current.</p>' +
		        '<ul>' +
		        '<li><strong>Dues Paid</strong> (green badge) &mdash; Your dues are current</li>' +
		        '<li><strong>Dues Expired</strong> (gray badge) &mdash; Your dues have lapsed</li>' +
		        '<li><strong>Dues for Life</strong> &mdash; If your park or kingdom offers a lifetime dues option and you have paid it, your record will show "Lifetime" instead of an expiration date</li>' +
		        '</ul>' +
		        '<p>Logged-in users can view their full dues payment history by clicking the history icon on the Dues card. Officers can add new dues entries by clicking the pencil icon.</p>' +
		        '<h3>Qualifications</h3>' +
		        '<p>The <strong>Qualifications</strong> card in your profile sidebar tracks two certifications:</p>' +
		        '<ul>' +
		        '<li><strong>Reeve Qualified</strong> &mdash; Indicates you have passed the rules test and can referee games</li>' +
		        '<li><strong>Corpora Qualified</strong> &mdash; Indicates you have passed the organizational rules test</li>' +
		        '</ul>' +
		        '<p>Each qualification shows whether it is active and its expiration date. These are managed by officers.</p>' +
		        '<blockquote><strong>Tip:</strong> If your My Amtgard dashboard shows an alert about lapsed dues or a missing waiver, reach out to your park officers to get current.</blockquote>'
		    }
		  ]
		},

		{
		  id: 'parks',
		  title: 'Parks',
		  icon: 'fas fa-tree',
		  articles: [
		    {
		      id: 'park-overview',
		      title: 'Park Profile Overview',
		      body: '<h2>Park Profile Overview</h2>' +
		        '<p>A <strong>park</strong> is your local Amtgard chapter — the group of players who meet regularly in your area to play. Every park belongs to a kingdom (a larger regional organization) and has its own profile page in the ORK.</p>' +
		        '<h3>What You See on a Park Profile</h3>' +
		        '<p>When you visit a park profile, the top of the page displays a <strong>hero header</strong> with the following information:</p>' +
		        '<ul>' +
		          '<li><strong>Park name</strong> and park title (Shire, Barony, Duchy, etc.)</li>' +
		          '<li><strong>Heraldry</strong> — the park\'s coat of arms or logo</li>' +
		          '<li><strong>Kingdom link</strong> — click to visit the parent kingdom\'s profile</li>' +
		          '<li><strong>Location</strong> — city and state/province</li>' +
		          '<li><strong>Monarch and Regent</strong> — the park\'s current elected leaders</li>' +
		          '<li><strong>Status badge</strong> — if the park is inactive, a badge will appear</li>' +
		        '</ul>' +
		        '<h3>Stats Cards</h3>' +
		        '<p>Below the hero header, four summary cards give you a quick snapshot of the park:</p>' +
		        '<ul>' +
		          '<li><strong>Next Park Day</strong> — the date and day of the week of the next scheduled meeting</li>' +
		          '<li><strong>Active Players</strong> — the number of players who have signed in at this park within the past year</li>' +
		          '<li><strong>Avg / Month</strong> — the average monthly attendance</li>' +
		          '<li><strong>Events</strong> — the number of upcoming events associated with this park</li>' +
		        '</ul>' +
		        '<p>Clicking on the <strong>Active Players</strong> or <strong>Events</strong> stat card will jump you directly to that tab.</p>' +
		        '<h3>Sidebar</h3>' +
		        '<p>The left sidebar shows:</p>' +
		        '<ul>' +
		          '<li><strong>Officers</strong> — a full list of the park\'s current officers (Monarch, Regent, Prime Minister, etc.)</li>' +
		          '<li><strong>Map</strong> — if the park has a location on file, an embedded Google Map appears</li>' +
		          '<li><strong>Quick Links</strong> — shortcuts to search players, view heraldry, see companies and households, the park website, and a map link</li>' +
		        '</ul>'
		    },
		    {
		      id: 'park-schedule',
		      title: 'Park Schedule & Park Days',
		      body: '<h2>Park Schedule &amp; Park Days</h2>' +
		        '<p>The <strong>About</strong> tab on a park profile shows the park\'s description, directions, and — most importantly — its <strong>schedule</strong> of recurring meetings (park days).</p>' +
		        '<h3>Park Day Cards</h3>' +
		        '<p>Each scheduled park day appears as a card displaying:</p>' +
		        '<ul>' +
		          '<li><strong>Day and time</strong> — for example, "Every Saturday" at "2:00 PM"</li>' +
		          '<li><strong>Purpose</strong> — the type of meeting, shown as a colored badge:' +
		            '<ul>' +
		              '<li><strong>Park Day</strong> — a standard meeting day for all activities</li>' +
		              '<li><strong>Fighter Practice</strong> — focused on combat and sparring</li>' +
		              '<li><strong>A&amp;S Day</strong> — focused on Arts and Sciences (crafting, garb-making, etc.)</li>' +
		            '</ul>' +
		          '</li>' +
		          '<li><strong>Location</strong> — the street address where the park meets</li>' +
		          '<li><strong>Map link</strong> — click to open directions in Google Maps</li>' +
		          '<li><strong>Online badge</strong> — if the park day is held online rather than in-person, an "Online" badge is shown instead of an address</li>' +
		          '<li><strong>Description</strong> — optional additional details about what happens at this meeting</li>' +
		        '</ul>' +
		        '<h3>Recurrence Types</h3>' +
		        '<p>Park days can recur on different schedules:</p>' +
		        '<ul>' +
		          '<li><strong>Weekly</strong> — meets the same day every week (e.g. "Every Saturday")</li>' +
		          '<li><strong>Week-of-Month</strong> — meets on a specific weekday of the month (e.g. "Every 3rd Tuesday")</li>' +
		          '<li><strong>Monthly</strong> — meets on a specific date each month (e.g. "Monthly on the 15th")</li>' +
		        '</ul>' +
		        '<h3>Calendar View</h3>' +
		        '<p>Park days also appear on the <strong>Events</strong> tab\'s calendar view as green entries, so you can see exactly when the next meeting falls on the calendar alongside other events.</p>' +
		        '<blockquote><strong>Tip:</strong> If a park day has an alternate location that differs from the park\'s main address, the card will show that specific address with its own map link.</blockquote>'
		    },
		    {
		      id: 'park-events-players',
		      title: 'Park Events & Players',
		      body: '<h2>Park Events &amp; Players</h2>' +
		        '<h3>Events Tab</h3>' +
		        '<p>The <strong>Events</strong> tab shows all upcoming events associated with the park. You can view events in two ways:</p>' +
		        '<ul>' +
		          '<li><strong>List view</strong> (default) — a sortable table showing event name, next date, and RSVP counts (Going and Interested)</li>' +
		          '<li><strong>Calendar view</strong> — a full monthly calendar with color-coded entries:' +
		            '<ul>' +
		              '<li>Green entries are <strong>park days</strong> (recurring meetings)</li>' +
		              '<li>Blue entries are <strong>regular events</strong> (campouts, tournaments, etc.)</li>' +
		              '<li>Red entries are <strong>fighter practices</strong></li>' +
		              '<li>Purple entries are <strong>A&amp;S days</strong></li>' +
		            '</ul>' +
		          '</li>' +
		        '</ul>' +
		        '<p>Use the <strong>Show</strong> filter buttons to toggle between <strong>Events</strong> and <strong>Park Days</strong>. Click any event in the list to go to its detail page.</p>' +
		        '<h3>Players Tab</h3>' +
		        '<p>The <strong>Players</strong> tab shows everyone who has signed in at this park. Players are grouped by how recently they attended:</p>' +
		        '<ul>' +
		          '<li>The first group shows players active in the <strong>past 6 months</strong></li>' +
		          '<li>Click <strong>Load More</strong> to reveal older groups (6-12 months ago, 12-18 months, etc.)</li>' +
		        '</ul>' +
		        '<p>You can view players in two formats:</p>' +
		        '<ul>' +
		          '<li><strong>Cards view</strong> — visual cards showing the player\'s persona, avatar/heraldry, sign-in count, last visit date, last class played, and any officer roles</li>' +
		          '<li><strong>List view</strong> — a compact sortable table with the same information</li>' +
		        '</ul>' +
		        '<p>Use the <strong>search box</strong> to quickly find a specific player by name.</p>' +
		        '<h3>Hall of Arms</h3>' +
		        '<p>If players at the park have uploaded personal heraldry, a <strong>Hall of Arms</strong> tab will appear showing a gallery of player devices (coat of arms images). Click any device to visit that player\'s profile. You can search the gallery by name.</p>' +
		        '<blockquote><strong>Tip:</strong> If you are a member of this park and haven\'t uploaded your own heraldry yet, you\'ll see a prompt encouraging you to add one on your player profile.</blockquote>'
		    },
		    {
		      id: 'managing-park',
		      title: 'Managing Your Park',
		      body: '<h2>Managing Your Park</h2>' +
		        '<p>If you are a park officer with admin permissions, you will see additional controls on the park profile. These features are only visible to authorized users.</p>' +
		        '<h3>Admin Buttons</h3>' +
		        '<p>Officers with park admin access will see these buttons in the hero header:</p>' +
		        '<ul>' +
		          '<li><strong>Enter Attendance</strong> — opens the attendance modal (see the "Recording Park Attendance" article)</li>' +
		          '<li><strong>Enter Awards</strong> — opens the award entry modal to grant awards or officer titles to players</li>' +
		          '<li><strong>Admin</strong> — opens the park administration modal</li>' +
		        '</ul>' +
		        '<h3>Park Administration Modal</h3>' +
		        '<p>The <strong>Admin</strong> button opens a modal where you can edit park details:</p>' +
		        '<ul>' +
		          '<li><strong>Park name</strong> and <strong>abbreviation</strong></li>' +
		          '<li><strong>Address</strong> — street address, city, state/province, postal code</li>' +
		          '<li><strong>Website URL</strong> and <strong>Map URL</strong></li>' +
		          '<li><strong>Description</strong> — a text description of your park (supports Markdown formatting)</li>' +
		          '<li><strong>Directions</strong> — how to find the park meeting location (supports Markdown)</li>' +
		        '</ul>' +
		        '<h3>Heraldry</h3>' +
		        '<p>To change the park\'s heraldry image, click the <strong>camera icon</strong> on the heraldry image in the hero header. You can upload a new image file to replace the current one.</p>' +
		        '<h3>Managing Officers</h3>' +
		        '<p>Click the <strong>pencil icon</strong> next to the Officers heading in the sidebar to open the officer management modal. From here you can assign players to officer roles (Monarch, Regent, Prime Minister, etc.) or vacate a position.</p>' +
		        '<h3>Managing Park Days</h3>' +
		        '<p>On the <strong>About</strong> tab, click <strong>Add Park Day</strong> to create a new recurring meeting. You can also click the pencil icon on any existing park day card to edit or delete it. When adding or editing a park day, you can set the day, time, recurrence pattern, purpose, location, and whether it\'s online.</p>' +
		        '<h3>Managing Players</h3>' +
		        '<p>Admins also have access to player management tools on the <strong>Players</strong> tab, including:</p>' +
		        '<ul>' +
		          '<li><strong>Add Player</strong> — create a new player record in this park</li>' +
		          '<li><strong>Move Player</strong> — transfer a player to a different park</li>' +
		          '<li><strong>Merge Players</strong> — combine duplicate player records into one</li>' +
		        '</ul>' +
		        '<h3>Admin Tasks Tab</h3>' +
		        '<p>Officers will see an <strong>Admin Tasks</strong> tab with additional administrative links and tools.</p>'
		    },
		    {
		      id: 'park-attendance',
		      title: 'Recording Park Attendance',
		      body: '<h2>Recording Park Attendance</h2>' +
		        '<p>Park officers use the <strong>Enter Attendance</strong> button to record who attended a park day. This is one of the most important features in the ORK, as attendance records determine player eligibility for awards, titles, and more.</p>' +
		        '<h3>Opening the Attendance Modal</h3>' +
		        '<p>Click <strong>Enter Attendance</strong> in the park hero header. The attendance modal opens with today\'s date selected. To enter attendance for a different date, click the date button at the top to open a calendar picker.</p>' +
		        '<h3>Adding Players via Search</h3>' +
		        '<p>The <strong>Search</strong> tab is the default view. To add a player:</p>' +
		        '<ol>' +
		          '<li>Start typing the player\'s persona name in the <strong>Player</strong> field. An autocomplete dropdown will appear with matching results.</li>' +
		          '<li>Select the correct player from the dropdown.</li>' +
		          '<li>Choose a <strong>Class</strong> from the dropdown (Warrior, Wizard, Archer, Scout, Healer, Monk, Barbarian, Bard, Druid, Assassin, Anti-Paladin, or Color).</li>' +
		          '<li>Set the <strong>Credits</strong> (defaults to 1). You can use half-credits (0.5) if needed.</li>' +
		          '<li>Click <strong>Add</strong> to record the entry.</li>' +
		        '</ol>' +
		        '<p>You can narrow the player search using the scope buttons:</p>' +
		        '<ul>' +
		          '<li><strong>Park</strong> — searches only players who belong to this park</li>' +
		          '<li><strong>Kingdom</strong> — searches across all parks in the kingdom</li>' +
		          '<li><strong>Global</strong> — searches all players in the ORK</li>' +
		        '</ul>' +
		        '<h3>Quick Entry via Recent Attendees</h3>' +
		        '<p>Click the <strong>Recent Park Attendees</strong> tab to see players who have signed in at this park in the last 90 days. Each row has pre-filled class and credits, making it quick to record regulars. Just click the add button next to each player.</p>' +
		        '<h3>Viewing Entered Attendance</h3>' +
		        '<p>As you add players, they appear in the <strong>Attendance</strong> section at the bottom of the modal with a running count. If you make a mistake, you can remove an entry by clicking the delete button on that row.</p>' +
		        '<p>When you\'re finished, click <strong>Done</strong> to close the modal.</p>' +
		        '<h3>Reports Tab</h3>' +
		        '<p>The park\'s <strong>Reports</strong> tab provides links to detailed attendance reports covering various time periods (past week, past month, past 6 months, past year, or all time). Additional reports include event attendance, player rosters, and more. Some reports require you to be logged in.</p>' +
		        '<blockquote><strong>Tip:</strong> Always double-check the date at the top of the attendance modal before entering records, especially if you\'re entering attendance after the fact.</blockquote>'
		    }
		  ]
		},
		{
		  id: 'kingdoms',
		  title: 'Kingdoms',
		  icon: 'fas fa-crown',
		  articles: [
		    {
		      id: 'kingdom-overview',
		      title: 'Kingdom Profile Overview',
		      body: '<h2>Kingdom Profile Overview</h2>' +
		        '<p>A <strong>kingdom</strong> is a collection of parks organized under a single regional banner. Kingdoms typically cover a geographic area (like a state, group of states, or country) and oversee the parks within their borders.</p>' +
		        '<h3>What You See on a Kingdom Profile</h3>' +
		        '<p>The top of the kingdom profile shows a <strong>hero header</strong> with:</p>' +
		        '<ul>' +
		          '<li><strong>Kingdom name</strong> and heraldry (coat of arms)</li>' +
		          '<li><strong>Entity type badge</strong> — indicates whether this is a <strong>Kingdom</strong> or a <strong>Principality</strong> (a sub-kingdom)</li>' +
		          '<li><strong>Monarch</strong> — the kingdom\'s current elected leader</li>' +
		        '</ul>' +
		        '<h3>Stats Cards</h3>' +
		        '<p>Below the hero, four stats cards summarize the kingdom at a glance:</p>' +
		        '<ul>' +
		          '<li><strong>Parks</strong> — the total number of active parks in the kingdom. Click to jump to the Parks tab.</li>' +
		          '<li><strong>Events</strong> — the number of upcoming events. Click to jump to the Events tab.</li>' +
		          '<li><strong>Avg / Week</strong> — the average number of unique player sign-ins per week across the kingdom (measured over 26 weeks)</li>' +
		          '<li><strong>Avg / Month</strong> — the average monthly player count across all parks</li>' +
		        '</ul>' +
		        '<h3>Sidebar</h3>' +
		        '<p>The sidebar on the left contains:</p>' +
		        '<ul>' +
		          '<li><strong>Officers</strong> — the kingdom\'s current officers (Monarch, Regent, Prime Minister, etc.). Kingdom admins can click the pencil icon to manage officer assignments.</li>' +
		          '<li><strong>About</strong> — the kingdom\'s description text, if one has been entered, along with a link to the kingdom website</li>' +
		          '<li><strong>Quick Links</strong> — shortcuts to search players, enter awards, view the kingdom map, browse companies and households, and find events</li>' +
		        '</ul>'
		    },
		    {
		      id: 'kingdom-parks-map',
		      title: 'Kingdom Parks & Map',
		      body: '<h2>Kingdom Parks &amp; Map</h2>' +
		        '<h3>Parks Tab</h3>' +
		        '<p>The <strong>Parks</strong> tab is the default view on a kingdom profile and shows all active parks in the kingdom. You can view parks in three formats:</p>' +
		        '<ul>' +
		          '<li><strong>Tile view</strong> (default) — visual cards showing each park\'s heraldry, name, title (Shire, Barony, etc.), and attendance statistics (average per week and per month)</li>' +
		          '<li><strong>List view</strong> — a detailed sortable table with columns for park name, type, average weekly attendance, average monthly attendance, total players (12 months), and total members</li>' +
		          '<li><strong>Map view</strong> — switches to the Map tab for a geographic view</li>' +
		        '</ul>' +
		        '<p>Click on any park tile or row to navigate to that park\'s profile page.</p>' +
		        '<blockquote><strong>Tip:</strong> If you are logged in and have a home park, it will be pinned to the first position and highlighted with a "Your Park" badge.</blockquote>' +
		        '<h3>Understanding the Stats</h3>' +
		        '<p>The park stats in the list view show:</p>' +
		        '<ul>' +
		          '<li><strong>Avg/Wk</strong> — average unique sign-ins per week over the past 26 weeks</li>' +
		          '<li><strong>Avg/Mo</strong> — average unique sign-ins per month over the past 12 months</li>' +
		          '<li><strong>Total Players</strong> — distinct players who signed in at this park in the past 12 months (players may be counted at multiple parks)</li>' +
		          '<li><strong>Total Members</strong> — of those players, how many have this park set as their home park</li>' +
		        '</ul>' +
		        '<p>The list footer shows kingdom-wide totals for all columns.</p>' +
		        '<h3>Map Tab</h3>' +
		        '<p>The <strong>Map</strong> tab shows an interactive Google Map with pins for every park that has location data on file. You can:</p>' +
		        '<ul>' +
		          '<li><strong>Click a pin</strong> to see the park\'s details in the sidebar panel (name, city, heraldry, description, and directions)</li>' +
		          '<li><strong>Navigate to the park</strong> by clicking the park name in the sidebar to visit its profile</li>' +
		          '<li><strong>Zoom and pan</strong> the map to explore the kingdom\'s geographic footprint</li>' +
		        '</ul>' +
		        '<p>If no parks have location data, the map will show a message indicating no location data is available.</p>'
		    },
		    {
		      id: 'kingdom-events',
		      title: 'Kingdom Events & Calendar',
		      body: '<h2>Kingdom Events &amp; Calendar</h2>' +
		        '<p>The <strong>Events</strong> tab shows all upcoming events across the kingdom, including both kingdom-level events and park-level events.</p>' +
		        '<h3>Views</h3>' +
		        '<p>You can switch between two views using the toolbar buttons:</p>' +
		        '<ul>' +
		          '<li><strong>List view</strong> (default) — a sortable table showing the next date, event name, host park, and RSVP counts (Going and Interested). Click any row to visit the event detail page.</li>' +
		          '<li><strong>Calendar view</strong> — a monthly calendar with color-coded entries. Blue entries are regular events; green entries are park days.</li>' +
		        '</ul>' +
		        '<h3>Filters</h3>' +
		        '<p>Use the <strong>Show</strong> filter buttons to control which events appear:</p>' +
		        '<ul>' +
		          '<li><strong>Kingdom Events</strong> — events hosted by the kingdom itself (enabled by default)</li>' +
		          '<li><strong>Park Events</strong> — events hosted by individual parks (enabled by default)</li>' +
		          '<li><strong>Park Days</strong> — recurring park meetings (hidden by default; click to show)</li>' +
		        '</ul>' +
		        '<p>Multiple filters can be active at the same time. Toggle each one on or off independently.</p>' +
		        '<h3>Calendar Subscription</h3>' +
		        '<p>Click the <strong>RSS icon</strong> button in the toolbar to subscribe to the kingdom\'s event calendar. A popup appears with three options:</p>' +
		        '<ul>' +
		          '<li><strong>Copy the URL</strong> — copies the ICS calendar feed URL to your clipboard for use in any calendar app</li>' +
		          '<li><strong>Add to Google Calendar</strong> — opens Google Calendar\'s subscription page with the URL pre-filled</li>' +
		          '<li><strong>webcal:// link</strong> — for apps that support the webcal protocol (such as Apple Calendar), click to add the feed directly</li>' +
		        '</ul>' +
		        '<blockquote><strong>Tip:</strong> When you subscribe to the calendar feed, new events will automatically appear in your personal calendar app as they are added to the ORK.</blockquote>' +
		        '<h3>Creating Events</h3>' +
		        '<p>Kingdom admins will see an <strong>Add Event</strong> button in the toolbar to create new kingdom-level events.</p>'
		    },
		    {
		      id: 'kingdom-admin',
		      title: 'Kingdom Administration',
		      body: '<h2>Kingdom Administration</h2>' +
		        '<p>Kingdom officers with admin permissions have access to additional management features. These are only visible to authorized users.</p>' +
		        '<h3>Admin Buttons</h3>' +
		        '<p>Kingdom admins will see these buttons in the hero header:</p>' +
		        '<ul>' +
		          '<li><strong>Enter Attendance</strong> — links to the kingdom-level attendance entry page</li>' +
		          '<li><strong>Enter Awards</strong> — opens a modal to grant awards or officer titles to players in the kingdom</li>' +
		          '<li><strong>Admin</strong> — opens the kingdom admin modal with management links</li>' +
		        '</ul>' +
		        '<h3>Admin Tasks Tab</h3>' +
		        '<p>The <strong>Admin Tasks</strong> tab provides quick access to common administrative actions, organized into groups:</p>' +
		        '<ul>' +
		          '<li><strong>Players</strong>' +
		            '<ul>' +
		              '<li><strong>Create Player</strong> — add a new player record to a park in the kingdom</li>' +
		              '<li><strong>Move Player</strong> — transfer a player from one park to another</li>' +
		              '<li><strong>Merge Players</strong> — combine duplicate player records</li>' +
		              '<li><strong>Suspensions</strong> — view suspended players</li>' +
		            '</ul>' +
		          '</li>' +
		          '<li><strong>Kingdom</strong>' +
		            '<ul>' +
		              '<li><strong>Admin Panel</strong> — full kingdom administration page for editing details, configuration, awards setup, and park titles</li>' +
		              '<li><strong>Roles &amp; Permissions</strong> — manage who has admin access to the kingdom</li>' +
		              '<li><strong>Claim Park</strong> — adopt an unaffiliated park into the kingdom</li>' +
		            '</ul>' +
		          '</li>' +
		        '</ul>' +
		        '<h3>Managing Parks</h3>' +
		        '<p>On the <strong>Parks</strong> tab, kingdom admins will see:</p>' +
		        '<ul>' +
		          '<li>An <strong>Add Park</strong> button to create a new park under the kingdom</li>' +
		          '<li>A <strong>pencil icon</strong> on each park row (in list view) to edit that park\'s details</li>' +
		        '</ul>' +
		        '<h3>Managing Officers</h3>' +
		        '<p>Click the <strong>pencil icon</strong> next to Officers in the sidebar to assign or vacate kingdom officer positions.</p>' +
		        '<h3>Reports Tab</h3>' +
		        '<p>The <strong>Reports</strong> tab offers an extensive library of kingdom-wide reports, organized into categories:</p>' +
		        '<ul>' +
		          '<li><strong>Players</strong> — rosters, active players, dues, waivers, reeve/corpora qualified, officer directory</li>' +
		          '<li><strong>Awards</strong> — recommendations, knights and masters, class masters, guilds, beltline explorer, custom awards</li>' +
		          '<li><strong>Attendance</strong> — reports covering various time periods, event attendance, park attendance explorer, new player tracking</li>' +
		          '<li><strong>Other</strong> — heraldry galleries and park distance matrix</li>' +
		          '<li><strong>Find</strong> — search tools for players, companies, households, events, and units</li>' +
		        '</ul>' +
		        '<blockquote><strong>Note:</strong> Some reports are only available to logged-in users. If you see a message about logging in, sign in to your ORK account to access the full report library.</blockquote>'
		    },
		    {
		      id: 'principalities',
		      title: 'Principalities',
		      body: '<h2>Principalities</h2>' +
		        '<p>A <strong>principality</strong> is a sub-kingdom that exists within a larger kingdom. Principalities are an intermediate level of organization between individual parks and the full kingdom.</p>' +
		        '<h3>What Is a Principality?</h3>' +
		        '<p>In Amtgard\'s organizational structure, some kingdoms contain principalities — groups of parks that are organized together within the kingdom\'s borders. A principality:</p>' +
		        '<ul>' +
		          '<li>Belongs to a parent kingdom</li>' +
		          '<li>Has its own set of officers (Monarch, Regent, etc.)</li>' +
		          '<li>Can manage its own awards</li>' +
		          '<li>Contains one or more parks</li>' +
		          '<li>Operates semi-independently while remaining part of the parent kingdom</li>' +
		        '</ul>' +
		        '<h3>Identifying Principalities</h3>' +
		        '<p>On a kingdom or principality profile page, you can tell whether you\'re looking at a kingdom or principality by the <strong>entity type badge</strong> in the hero header. It will read either "Kingdom" or "Principality."</p>' +
		        '<h3>Principalities Tab</h3>' +
		        '<p>If a kingdom contains principalities, a <strong>Principalities</strong> tab will appear on the kingdom profile page. This tab lists all principalities with their heraldry and name. Click on any principality to visit its profile.</p>' +
		        '<p>A principality\'s profile page looks and works the same as a kingdom profile — with parks, events, a map, players, and reports — but scoped to the parks within that principality.</p>' +
		        '<h3>How Principalities Are Created</h3>' +
		        '<p>Principalities are set up by ORK administrators and cannot be created by kingdom or park officers directly. If your kingdom is forming a new principality, contact your kingdom\'s Monarch or the ORK administrators for assistance.</p>' +
		        '<blockquote><strong>Note:</strong> The Principalities tab only appears on kingdom profiles that actually have principalities. If you don\'t see this tab, it means the kingdom has no principalities.</blockquote>'
		    }
		  ]
		},

		{
		  id: 'awards',
		  title: 'Awards & Honors',
		  icon: 'fas fa-award',
		  articles: [
		    {
		      id: 'understanding-awards',
		      title: 'Understanding Awards',
		      body: '<h2>Understanding Awards</h2>' +
		        '<p>Awards are one of the core ways Amtgard recognizes achievement, service, and excellence. The ORK tracks every award given to every player, building a permanent record of accomplishments across the game.</p>' +
		        '<h3>Ladder Awards</h3>' +
		        '<p>Ladder awards are progression-based honors that advance through <strong>ranks 1 through 10</strong>. Each rank represents a deeper level of achievement in the award\'s area. All levels must be earned consecutively. The standard ladder awards recognized across all kingdoms are:</p>' +
		        '<ul>' +
		        '<li><strong>Order of the Rose</strong> &mdash; service to the club not necessarily related to an elected office</li>' +
		        '<li><strong>Order of the Smith</strong> &mdash; organizing and running battlegames, quests, workshops, and demonstrations</li>' +
		        '<li><strong>Order of the Lion</strong> &mdash; going above and beyond the call of duty in office, or leadership outside of office</li>' +
		        '<li><strong>Order of the Crown</strong> &mdash; serving with excellence in an elected office, from local to kingdom level</li>' +
		        '<li><strong>Order of the Owl</strong> &mdash; construction sciences: weapon and armor construction, furniture, shoes, belts, and more</li>' +
		        '<li><strong>Order of the Dragon</strong> &mdash; the arts: performance, painting, sculpting, photography, cooking, writing, acting, and role-playing</li>' +
		        '<li><strong>Order of the Garber</strong> &mdash; creation of garb: tabards, pants, cloaks, gloves, sashes, pouches, and more</li>' +
		        '<li><strong>Order of the Warrior</strong> &mdash; fighting prowess, following a regimented tournament-based progression</li>' +
		        '<li><strong>Order of Battle</strong> &mdash; tactical skill and effectiveness in class battlegaming, from individual play to commanding teams</li>' +
		        '</ul>' +
		        '<h3>Masterhoods</h3>' +
		        '<p>Earning your <strong>tenth rank</strong> in a ladder award makes you eligible for a <strong>Masterhood</strong> &mdash; a title recognizing deep expertise in that field. Having the tenth rank does not automatically grant masterhood; it must be bestowed by the monarchy when you have demonstrated obvious expertise. The masterhoods are:</p>' +
		        '<ul>' +
		        '<li><strong>Master Rose</strong>, <strong>Master Smith</strong>, <strong>Master Lion</strong>, <strong>Master Crown</strong>, <strong>Master Owl</strong>, <strong>Master Dragon</strong>, <strong>Master Garber</strong></li>' +
		        '<li><strong>Warlord</strong> (Warrior masterhood) and <strong>Battlemaster</strong> (Battle masterhood)</li>' +
		        '</ul>' +
		        '<h3>Knighthood</h3>' +
		        '<p>Achieving a Masterhood makes a player <strong>eligible</strong> for Knighthood in the corresponding order. Knighthood recognizes both skill and character. The five orders of Knighthood are:</p>' +
		        '<ul>' +
		        '<li><strong>Knight of the Flame</strong> &mdash; eligible after obtaining Master Rose, Master Smith, or Master Lion</li>' +
		        '<li><strong>Knight of the Crown</strong> &mdash; eligible after obtaining Master Crown</li>' +
		        '<li><strong>Knight of the Serpent</strong> &mdash; eligible after obtaining Master Owl, Master Dragon, or Master Garber</li>' +
		        '<li><strong>Knight of the Sword</strong> &mdash; eligible after obtaining the title of Warlord</li>' +
		        '<li><strong>Knight of Battle</strong> &mdash; eligible after obtaining the title of Battlemaster</li>' +
		        '</ul>' +
		        '<h3>Title Awards</h3>' +
		        '<p>Titles reflect nobility and special status. They include ranks of the peerage such as Lord/Lady, Baron/Baroness, Duke/Duchess, and the Knighthoods above. Titles are displayed prominently on a player\'s profile.</p>' +
		        '<h3>Kingdom &amp; Park Awards</h3>' +
		        '<p>Many Amtgard kingdoms and parks have their own awards and orders that they grant based on kingdom traditions or governing documents. For example, the <strong>Order of the Mask</strong> is given for excellence in roleplaying while the <strong>Order of the Flame</strong> is given out to groups in recognition of collective service. Check with your kingdom\'s governing documents (such as the Corpora) to learn more about what awards are available in your area.</p>' +
		        '<h3>Officer Role Awards &amp; Custom Awards</h3>' +
		        '<p>When a player holds an official position (such as Champion, Prime Minister, or Sheriff), that role is recorded as an award for historical tracking. Officers do not have ranks. Kingdoms and parks can also create <strong>custom awards</strong> for one-time or unique recognitions outside the standard categories.</p>' +
		        '<blockquote><strong>Tip:</strong> The rank number on a ladder award indicates progression. A player with Order of the Rose 5 has been recognized five times for service &mdash; a significant achievement. Reaching the tenth rank is the gateway to Masterhood eligibility.</blockquote>'
		    },
		    {
		      id: 'viewing-awards',
		      title: 'Viewing Your Awards',
		      body: '<h2>Viewing Your Awards</h2>' +
		        '<p>Every player\'s profile has a complete record of their awards and honors. You can view any player\'s awards by visiting their profile page.</p>' +
		        '<h3>Awards Tab</h3>' +
		        '<p>The <strong>Awards</strong> tab on a player profile lists all awards sorted by date. Each row shows:</p>' +
		        '<ul>' +
		        '<li><strong>Award Name</strong> &mdash; the name of the award or order</li>' +
		        '<li><strong>Date</strong> &mdash; when the award was given</li>' +
		        '<li><strong>Rank</strong> &mdash; the rank level (for ladder awards)</li>' +
		        '<li><strong>Given By</strong> &mdash; the officer or monarch who bestowed it</li>' +
		        '</ul>' +
		        '<p>You can sort the table by clicking any column header, and the list is paginated if there are many awards.</p>' +
		        '<h3>Titles Tab</h3>' +
		        '<p>Title-type awards (such as Lord, Baroness, Duke, or Knight) and Masterhoods (such as Warlord or Battlemaster) appear under a separate <strong>Titles</strong> tab. This gives a quick view of a player\'s peerage and noble standing.</p>' +
		        '<h3>Class Levels</h3>' +
		        '<p>The <strong>Class Levels</strong> section shows which Amtgard classes a player has earned credits in, along with their level in each class. Players who reach the highest level in a class are recognized as a <strong>Master</strong> or <strong>Paragon</strong> of that class.</p>' +
		        '<h3>Knighthood Indicator</h3>' +
		        '<p>Players who hold a knighthood (Knight of the Flame, Crown, Serpent, Sword, or Battle) will see a special belt icon displayed on their profile hero section, making their knightly status immediately visible.</p>' +
		        '<blockquote><strong>Tip:</strong> If you believe an award is missing from your profile, contact your park or kingdom officers. They can verify the record and add any missing entries.</blockquote>'
		    },
		    {
		      id: 'giving-awards',
		      title: 'Giving Awards',
		      body: '<h2>Giving Awards</h2>' +
		        '<p>Officers with the appropriate authority can give awards to players through the ORK. This is typically done by Monarchs, Regents, and other kingdom or park leaders.</p>' +
		        '<h3>Accessing the Award Form</h3>' +
		        '<p>Navigate to the <strong>Awards</strong> page for your kingdom or park. If you have officer permissions, you will see the award entry form.</p>' +
		        '<h3>Filling Out the Form</h3>' +
		        '<ol>' +
		        '<li><strong>Award Type</strong> &mdash; Toggle between <strong>Awards</strong> (ladder, title, and custom awards) and <strong>Officers</strong> (officer role assignments). Selecting Officers hides the Rank field since officer roles do not have ranks.</li>' +
		        '<li><strong>Award</strong> &mdash; Choose from the dropdown. Awards are grouped into <em>Common Awards</em> and a full list. Select <strong>Custom Award</strong> to enter a unique award name.</li>' +
		        '<li><strong>Rank</strong> &mdash; For ladder awards, enter a rank from 1 to 10. This field is hidden for officer roles.</li>' +
		        '<li><strong>Date</strong> &mdash; The date the award was given. Uses a date picker.</li>' +
		        '<li><strong>Given To</strong> &mdash; Start typing a player\'s persona name and select from the search results.</li>' +
		        '<li><strong>Given By</strong> &mdash; The officer bestowing the award. Click into the field to see your kingdom and park Monarchs and Regents pre-loaded for quick selection, or type to search for another player.</li>' +
		        '<li><strong>Given At</strong> &mdash; Optionally search for the event or location where the award was given.</li>' +
		        '<li><strong>Given For</strong> &mdash; An optional note describing why the award was given.</li>' +
		        '</ol>' +
		        '<h3>Required Fields</h3>' +
		        '<p>Three fields are required to submit an award:</p>' +
		        '<ul>' +
		        '<li>The <strong>Award</strong> selection</li>' +
		        '<li>The <strong>Given To</strong> recipient</li>' +
		        '<li>The <strong>Given By</strong> officer</li>' +
		        '</ul>' +
		        '<p>After a successful submission, you will see a confirmation message and the form will reset for the next entry.</p>' +
		        '<blockquote><strong>Note:</strong> You must be logged in and have officer-level authority for the relevant kingdom or park to give awards.</blockquote>'
		    },
		    {
		      id: 'award-recommendations',
		      title: 'Award Recommendations',
		      body: '<h2>Award Recommendations</h2>' +
		        '<p>Any logged-in player can recommend another player for an award. Recommendations let the community highlight outstanding contributions and bring them to the attention of officers who can grant awards.</p>' +
		        '<h3>How to Recommend an Award</h3>' +
		        '<ol>' +
		        '<li>Visit the profile of the player you want to recommend.</li>' +
		        '<li>Click the <strong>Recommend Award</strong> button in their profile header.</li>' +
		        '<li>In the recommendation form, fill in:' +
		        '<ul>' +
		        '<li><strong>Award</strong> &mdash; Select the award you are recommending from the dropdown (required).</li>' +
		        '<li><strong>Rank</strong> &mdash; The rank you are recommending for the award.</li>' +
		        '<li><strong>Reason</strong> &mdash; A written explanation of why this player deserves the award. Be specific about their contributions.</li>' +
		        '</ul></li>' +
		        '<li>Click <strong>Submit Recommendation</strong>.</li>' +
		        '</ol>' +
		        '<h3>Viewing Recommendations</h3>' +
		        '<p>Recommendations appear on the player\'s profile under the <strong>Recommendations</strong> tab. The tab shows a count of open recommendations. Each entry displays the award name, recommended rank, date, who recommended it, and the reason given.</p>' +
		        '<p>Whether all players can see recommendations or only officers depends on your kingdom\'s configuration settings. You can always see your own recommendations, even if public visibility is turned off.</p>' +
		        '<h3>Acting on Recommendations (Officers)</h3>' +
		        '<p>Kingdom and park officers with the appropriate authority see additional actions next to each recommendation:</p>' +
		        '<ul>' +
		        '<li><strong>Grant</strong> &mdash; Approve the recommendation and create the actual award record for the player.</li>' +
		        '<li><strong>Delete</strong> &mdash; Remove the recommendation if it is not appropriate or has already been addressed.</li>' +
		        '</ul>' +
		        '<p>The original recommender and the player being recommended can also delete a recommendation.</p>' +
		        '<blockquote><strong>Tip:</strong> When writing a recommendation reason, include specific examples such as events attended, projects completed, or contributions made. This helps officers make informed decisions.</blockquote>'
		    }
		  ]
		},
		{
		  id: 'events',
		  title: 'Events',
		  icon: 'fas fa-calendar-alt',
		  articles: [
		    {
		      id: 'events-overview',
		      title: 'Events Overview',
		      body: '<h2>Events Overview</h2>' +
		        '<p>Events are organized gatherings in Amtgard, ranging from local park activities to large kingdom-wide campouts and wars. The ORK serves as the central calendar and record for all events.</p>' +
		        '<h3>Event Types</h3>' +
		        '<p>Events are organized by the level of group hosting them:</p>' +
		        '<ul>' +
		        '<li><strong>Kingdom Events</strong> &mdash; Large-scale events hosted by a kingdom, such as coronation events, midreigns, wars, and inter-kingdom gatherings.</li>' +
		        '<li><strong>Park Events</strong> &mdash; Events organized by a specific park, such as local tournaments, feasts, or special game days.</li>' +
		        '<li><strong>Unit Events</strong> &mdash; Events hosted by fighting companies, households, or other player units.</li>' +
		        '</ul>' +
		        '<h3>Event Details</h3>' +
		        '<p>Each event in the ORK includes:</p>' +
		        '<ul>' +
		        '<li><strong>Name</strong> &mdash; the event title</li>' +
		        '<li><strong>Description</strong> &mdash; details about the event (may include formatted text)</li>' +
		        '<li><strong>Start and End Dates</strong> &mdash; when the event takes place (with times)</li>' +
		        '<li><strong>Price</strong> &mdash; the cost to attend (displayed as "Free" if there is no charge)</li>' +
		        '<li><strong>Location</strong> &mdash; street address, city, province, and postal code, with an auto-generated map</li>' +
		        '<li><strong>Website</strong> &mdash; an optional link to an external event website or social media page</li>' +
		        '<li><strong>Heraldry</strong> &mdash; an optional event logo or image</li>' +
		        '</ul>' +
		        '<h3>Multiple Occurrences</h3>' +
		        '<p>A single event can have multiple scheduled occurrences (dates). For example, a recurring monthly tournament might be one event with multiple date entries. Each occurrence tracks its own RSVP counts and attendance separately.</p>' +
		        '<h3>Finding Events</h3>' +
		        '<p>You can find events listed on kingdom and park profile pages under the <strong>Events</strong> tab. Events are displayed with their dates, location, and RSVP status.</p>' +
		        '<blockquote><strong>Tip:</strong> Check your kingdom\'s event listings regularly to stay up to date on upcoming gatherings in your area.</blockquote>'
		    },
		    {
		      id: 'creating-events',
		      title: 'Creating Events',
		      body: '<h2>Creating Events</h2>' +
		        '<p>Officers with event management authority can create new events in the ORK. This is typically available to kingdom and park officers.</p>' +
		        '<h3>Step 1: Create the Event</h3>' +
		        '<p>Start by providing the basic information:</p>' +
		        '<ul>' +
		        '<li><strong>Event Name</strong> &mdash; A descriptive title for the event (required).</li>' +
		        '<li><strong>Level</strong> &mdash; Whether this is a kingdom-level or park-level event. This determines where it appears in listings and who can manage it.</li>' +
		        '</ul>' +
		        '<h3>Step 2: Add Event Details</h3>' +
		        '<p>Once the event is created, you can fill in the full details through the admin panel:</p>' +
		        '<ul>' +
		        '<li><strong>Date and Time</strong> &mdash; Set the start and end date/time for each occurrence of the event.</li>' +
		        '<li><strong>Price</strong> &mdash; Enter the cost to attend. Leave at $0 for free events.</li>' +
		        '<li><strong>Description</strong> &mdash; Provide details about the event. HTML formatting is allowed for rich descriptions.</li>' +
		        '<li><strong>Location</strong> &mdash; Enter the street address, city, province/state, and postal code. The system will automatically geocode the address and display it on a map.</li>' +
		        '<li><strong>Website</strong> &mdash; Add a URL and display name for an external event page (such as a Facebook event).</li>' +
		        '</ul>' +
		        '<h3>Managing Occurrences</h3>' +
		        '<p>You can add multiple date occurrences to a single event. This is useful for recurring events or multi-day events where each day has its own attendance tracking. Mark occurrences as "current" to indicate they are active and upcoming.</p>' +
		        '<h3>Editing Events</h3>' +
		        '<p>If you have management authority for an event, you will see an <strong>Admin Panel</strong> link in the navigation when viewing the event page. Use this to update any event details after creation.</p>' +
		        '<blockquote><strong>Note:</strong> You must be logged in with appropriate officer authority to create or edit events. If you do not see the creation option, contact your kingdom or park officers.</blockquote>'
		    },
		    {
		      id: 'rsvp-attendance',
		      title: 'RSVP & Event Attendance',
		      body: '<h2>RSVP & Event Attendance</h2>' +
		        '<p>The ORK allows players to indicate their plans for upcoming events and tracks actual attendance for events that have occurred.</p>' +
		        '<h3>RSVPing to Events</h3>' +
		        '<p>When viewing an event with upcoming occurrences, logged-in players can RSVP to indicate their plans:</p>' +
		        '<ul>' +
		        '<li><strong>Going</strong> &mdash; You plan to attend the event.</li>' +
		        '<li><strong>Interested</strong> &mdash; You are considering attending but have not committed.</li>' +
		        '</ul>' +
		        '<p>To RSVP, click the RSVP button on the event\'s date entry. You can change or remove your RSVP at any time by clicking the button again &mdash; it toggles on and off.</p>' +
		        '<h3>RSVP Counts</h3>' +
		        '<p>Each event occurrence displays a count of how many players are attending or interested (for example, "47 attending"). This helps the community gauge interest and helps event organizers plan accordingly.</p>' +
		        '<h3>Attendee List (Event Managers)</h3>' +
		        '<p>Officers who manage the event can see the full RSVP attendee list. This list shows each player\'s:</p>' +
		        '<ul>' +
		        '<li><strong>Persona</strong> &mdash; their Amtgard name</li>' +
		        '<li><strong>Kingdom</strong> &mdash; their home kingdom</li>' +
		        '<li><strong>Park</strong> &mdash; their home park</li>' +
		        '<li><strong>Last Class Played</strong> &mdash; the class they most recently signed in as</li>' +
		        '</ul>' +
		        '<h3>Recording Event Attendance</h3>' +
		        '<p>Event attendance is separate from RSVPs. Officers with event authority can record who actually attended the event and what class they played. Attendance sign-ins open 24 hours before the event start time, so players can be checked in as they arrive.</p>' +
		        '<p>For past events, the RSVP buttons are hidden and replaced with a static attendance count showing how many players attended.</p>' +
		        '<blockquote><strong>Tip:</strong> RSVPing helps event organizers estimate turnout for food, supplies, and site fees. Even an "Interested" RSVP is helpful information.</blockquote>'
		    }
		  ]
		},
		{
		  id: 'attendance',
		  title: 'Attendance',
		  icon: 'fas fa-clipboard-check',
		  articles: [
		    {
		      id: 'how-attendance-works',
		      title: 'How Attendance Works',
		      body: '<h2>How Attendance Works</h2>' +
		        '<p>Attendance tracking is a fundamental part of the ORK system. Every time a player participates in Amtgard &mdash; whether at a regular park day, a kingdom event, or a special gathering &mdash; that participation can be recorded as an attendance entry.</p>' +
		        '<h3>What Gets Recorded</h3>' +
		        '<p>Each attendance entry captures:</p>' +
		        '<ul>' +
		        '<li><strong>Player</strong> &mdash; who attended (selected by persona search)</li>' +
		        '<li><strong>Date</strong> &mdash; the date of attendance</li>' +
		        '<li><strong>Class Played</strong> &mdash; the Amtgard class the player participated as</li>' +
		        '<li><strong>Credits</strong> &mdash; the number of credits earned (defaults to 1)</li>' +
		        '<li><strong>Park / Kingdom</strong> &mdash; where attendance was recorded</li>' +
		        '<li><strong>Event</strong> &mdash; optionally linked to a specific event occurrence</li>' +
		        '</ul>' +
		        '<h3>Entry Points</h3>' +
		        '<p>There are three main places where attendance is recorded:</p>' +
		        '<ul>' +
		        '<li><strong>Park Attendance</strong> &mdash; The most common method. Officers enter attendance for players at regular park days. Accessible from a park\'s attendance page.</li>' +
		        '<li><strong>Kingdom Attendance</strong> &mdash; Kingdom-level officers can record attendance for kingdom-wide activities.</li>' +
		        '<li><strong>Event Attendance</strong> &mdash; Event managers can record attendance for specific event occurrences. Sign-ins open 24 hours before the event starts.</li>' +
		        '</ul>' +
		        '<h3>Why Attendance Matters</h3>' +
		        '<p>Credits earned through attendance contribute directly to your <strong>class levels</strong>. As you accumulate credits in a class, your level in that class increases, unlocking new abilities in the game. Attendance is also used to determine eligibility for certain awards and titles.</p>' +
		        '<blockquote><strong>Tip:</strong> Make sure your attendance is recorded each time you play. If you notice a missing entry, ask your park officers to add it.</blockquote>'
		    },
		    {
		      id: 'amtgard-classes',
		      title: 'Amtgard Classes',
		      body: '<h2>Amtgard Classes</h2>' +
		        '<p>When attendance is recorded, each player selects the class they played that day. The ORK tracks these class credits over time to determine your class levels. Classes in Amtgard are designed so that each one brings a unique and valuable set of skills to the field which can be used as part of a team.</p>' +
		        '<h3>Magic Users</h3>' +
		        '<p>Magic Users have access to a broad array of magical abilities. They purchase spells from a point-based system, gaining new options at each level.</p>' +
		        '<ul>' +
		        '<li><strong>Bard</strong> &mdash; battlefield control, with a focus on enhancing allies while hindering enemies</li>' +
		        '<li><strong>Druid</strong> &mdash; versatile support and fighting, with a focus on empowering allies and hindering enemies</li>' +
		        '<li><strong>Healer</strong> &mdash; support and protection, with a focus on restoring and fortifying allies</li>' +
		        '<li><strong>Wizard</strong> &mdash; powerful ranged offense and battlefield control, with a focus on damaging and disrupting enemies</li>' +
		        '</ul>' +
		        '<h3>Martial Classes</h3>' +
		        '<p>Martial classes have fewer but more focused abilities, paired with expanded equipment availability including heavier armor, shields, and a wider range of weapons.</p>' +
		        '<ul>' +
		        '<li><strong>Anti-Paladin</strong> &mdash; aggressive front-line combat, with a focus on offense and disrupting enemies (reserved class; requires 6th level in at least one other class)</li>' +
		        '<li><strong>Archer</strong> &mdash; ranged combat, with a focus on strategic use of enhanced arrows</li>' +
		        '<li><strong>Assassin</strong> &mdash; high-mobility stealth-based play, with a focus on precision and hit-and-run tactics</li>' +
		        '<li><strong>Barbarian</strong> &mdash; aggressive front-line fighting, with a focus on melee combat and endurance</li>' +
		        '<li><strong>Monk</strong> &mdash; support and skirmishing, with a focus on melee combat and supporting allies</li>' +
		        '<li><strong>Paladin</strong> &mdash; support and tank roles, with a focus on defense and healing (reserved class; requires 6th level in at least one other class)</li>' +
		        '<li><strong>Scout</strong> &mdash; versatile support and control, with a focus on mobility and disruption</li>' +
		        '<li><strong>Warrior</strong> &mdash; frontline combat and resilience, with a focus on durability and disruption</li>' +
		        '</ul>' +
		        '<h3>Other Classes</h3>' +
		        '<ul>' +
		        '<li><strong>Color</strong> &mdash; a catch-all class for members who do not participate in the combat portion of the game, but provide logistics, leadership, and support (e.g. water bearers, heralds, event organizers)</li>' +
		        '<li><strong>Monster</strong> &mdash; a special class representing creatures from imagination or legend, playable only in games where the game designer and local monarch have given permission; your level determines which monsters you may portray</li>' +
		        '<li><strong>Peasant</strong> &mdash; the default class for players who do not meet the garb requirement for any other class; limited to daggers and short weapons with no armor, shields, or abilities</li>' +
		        '<li><strong>Reeve</strong> &mdash; the judges and referees of the game who ensure rules are followed and the game is run fairly; identified by a black-and-white sash or other high-visibility garb</li>' +
		        '</ul>' +
		        '<h3>Credits and Levels</h3>' +
		        '<p>As you accumulate attendance credits in a class, your level in that class increases. Only one credit may be given on a single day. All classes gain new levels at the following rate:</p>' +
		        '<ul>' +
		        '<li><strong>1st Level</strong> &mdash; fewer than 5 credits</li>' +
		        '<li><strong>2nd Level</strong> &mdash; 5 to 11 credits</li>' +
		        '<li><strong>3rd Level</strong> &mdash; 12 to 20 credits</li>' +
		        '<li><strong>4th Level</strong> &mdash; 21 to 33 credits</li>' +
		        '<li><strong>5th Level</strong> &mdash; 34 to 52 credits</li>' +
		        '<li><strong>6th Level</strong> &mdash; 53 or more credits</li>' +
		        '</ul>' +
		        '<p>Your current class levels are visible on your player profile under the <strong>Class Levels</strong> section. Reaching the highest level in a class may qualify you for the distinction of <strong>Paragon</strong> &mdash; an award that can be bestowed on a player for consistently being an excellent example of their class in battlegames. Paragon is not automatic; it is granted by kingdom officers to players who look the part, role-play well, and are highly effective at playing their class. Paragons take the lead in teaching new players how to play their class.</p>' +
		        '<h3>Portraying a Class</h3>' +
		        '<p>While class names reflect a European-centric viewpoint, they do not define how you must portray them. You can play Barbarian or Warrior as a samurai, Healer as a necromancer, or Scout as a pirate. Your character is defined through your actions and behavior, not the name of your class. Some players choose a &ldquo;flavor&rdquo; name for their class when signing in &mdash; for example, signing in as &ldquo;Plague Doctor&rdquo; while playing Wizard. The underlying class is still tracked for credits, but the flavor name adds a personal touch to the attendance record.</p>' +
		        '<blockquote><strong>Tip:</strong> Diversifying across multiple classes can make you a more versatile player, but focusing on one class helps you reach Paragon status faster.</blockquote>'
		    },
		    {
		      id: 'attendance-reports',
		      title: 'Attendance Reports',
		      body: '<h2>Attendance Reports</h2>' +
		        '<p>The ORK provides detailed attendance reports that help officers and players understand participation trends across kingdoms, parks, and events.</p>' +
		        '<h3>Kingdom Attendance Report</h3>' +
		        '<p>The kingdom-level attendance report provides a comprehensive overview with:</p>' +
		        '<ul>' +
		        '<li><strong>Stats Cards</strong> &mdash; Quick summary numbers including Total Attendees, Total Credits, Parks Represented, and Classes Played.</li>' +
		        '<li><strong>Charts</strong> &mdash; Visual breakdowns of attendees by park and by class, making it easy to spot trends at a glance.</li>' +
		        '<li><strong>Sortable Table</strong> &mdash; A detailed list of all attendance entries that you can sort by any column. Use the <strong>Export</strong> options to download the data as CSV or print it for your records.</li>' +
		        '</ul>' +
		        '<h3>Park Attendance</h3>' +
		        '<p>Park-level attendance pages show who attended on a given date. Officers use this view to:</p>' +
		        '<ul>' +
		        '<li>See all players who signed in for a specific day</li>' +
		        '<li>Add new attendance entries for players</li>' +
		        '<li>Edit or remove incorrect entries</li>' +
		        '<li>Browse attendance by date to review historical records</li>' +
		        '</ul>' +
		        '<p>The park attendance explorer lets you navigate through dates to review trends in park activity over time.</p>' +
		        '<h3>Event Attendance Report</h3>' +
		        '<p>Each event occurrence has its own attendance view showing all players who were checked in. Event managers can see the full list and add or remove entries as needed.</p>' +
		        '<h3>New Player Attendance</h3>' +
		        '<p>The system tracks new players within a <strong>90-day window</strong>, helping parks and kingdoms understand how many newcomers are participating and measure retention and growth efforts.</p>' +
		        '<h3>Player Profile Attendance</h3>' +
		        '<p>On any player\'s profile, the <strong>Attendance</strong> tab shows their complete personal attendance history with dates, parks, and classes played.</p>' +
		        '<blockquote><strong>Tip:</strong> Officers can use the CSV export to create custom reports or share attendance data with kingdom leadership for planning purposes.</blockquote>'
		    }
		  ]
		},

		{
		  id: 'tournaments',
		  title: 'Tournaments',
		  icon: 'fas fa-trophy',
		  articles: [
		    {
		      id: 'tournaments-overview',
		      title: 'Tournaments Overview',
		      body: '<div style="background:#fff3cd;border:1px solid #ffc107;border-radius:6px;padding:12px 16px;margin-bottom:16px;display:flex;align-items:center;gap:10px;"><span style="font-size:1.4em;">&#x1F6A7;</span><span style="color:#856404;"><strong>The Tournament Module is under construction!</strong> There is basic functionality today, but keep an eye out for even more capabilities in a future release.</span></div>' +
		        '<h2>Tournaments Overview</h2>' +
		        '<p>Tournaments in the ORK are bracket-style competitions that can be associated with a <strong>kingdom</strong>, a <strong>park</strong>, or an <strong>event</strong>. They provide a structured way to organize and record competitive play at any level of Amtgard.</p>' +
		        '<h3>How Tournaments Are Structured</h3>' +
		        '<p>Every tournament has three layers:</p>' +
		        '<ul>' +
		        '<li><strong>Tournament</strong> &mdash; The top-level record. It has a name, description, date, and an optional association with a kingdom, park, or event.</li>' +
		        '<li><strong>Brackets</strong> &mdash; Divisions or categories within the tournament (for example, &ldquo;Sword &amp; Board&rdquo; or &ldquo;Florentine&rdquo;). Each bracket has its own settings for competition style and participants.</li>' +
		        '<li><strong>Participants</strong> &mdash; The individual players or teams entered into a bracket.</li>' +
		        '</ul>' +
		        '<h3>Bracket Settings</h3>' +
		        '<p>Each bracket is configured with several options:</p>' +
		        '<ul>' +
		        '<li><strong>Style</strong> &mdash; The competition format, such as single elimination or round robin.</li>' +
		        '<li><strong>Method</strong> &mdash; How participants are seeded into the bracket.</li>' +
		        '<li><strong>Rings</strong> &mdash; The number of simultaneous competition areas (rings or fields) used for that bracket.</li>' +
		        '<li><strong>Seeding</strong> &mdash; Whether participant ordering is manual, random, or automatic.</li>' +
		        '</ul>' +
		        '<blockquote>Tournaments are visible on kingdom, park, and event profile pages under the <strong>Tournaments</strong> tab, so players can see upcoming and past competitions.</blockquote>'
		    },
		    {
		      id: 'creating-tournament',
		      title: 'Creating a Tournament',
		      body: '<h2>Creating a Tournament</h2>' +
		        '<p>Officers with edit-level authorization for a kingdom, park, or event can create and manage tournaments. Here is the typical workflow.</p>' +
		        '<h3>Step 1: Create the Tournament</h3>' +
		        '<p>Navigate to the tournament creation page. Fill in the basic details:</p>' +
		        '<ul>' +
		        '<li><strong>Name</strong> (required) &mdash; A descriptive title for the tournament.</li>' +
		        '<li><strong>Description</strong> &mdash; Additional details such as rules or format notes.</li>' +
		        '<li><strong>URL</strong> &mdash; An optional link to external information.</li>' +
		        '<li><strong>When</strong> &mdash; Use the date/time picker to set the tournament date.</li>' +
		        '</ul>' +
		        '<h3>Step 2: Add Brackets</h3>' +
		        '<p>After the tournament is created, add one or more brackets. For each bracket, configure:</p>' +
		        '<ul>' +
		        '<li><strong>Style</strong> &mdash; Single elimination, round robin, or other supported format.</li>' +
		        '<li><strong>Method</strong> &mdash; The seeding method for participant placement.</li>' +
		        '<li><strong>Rings</strong> &mdash; How many fields or rings will run simultaneously.</li>' +
		        '<li><strong>Participants</strong> &mdash; The expected number of entrants.</li>' +
		        '<li><strong>Seeding</strong> &mdash; Manual, random, or automatic ordering.</li>' +
		        '</ul>' +
		        '<blockquote>To save time when creating similar divisions, use the <strong>Copy Bracket</strong> feature. It duplicates all settings and participants from an existing bracket into a new one that you can then adjust.</blockquote>' +
		        '<h3>Step 3: Add Participants</h3>' +
		        '<p>Participants can be added one at a time by searching for a player, or copied from another bracket. Each participant is linked to their ORK player record so results are tracked automatically.</p>' +
		        '<h3>Managing an Existing Tournament</h3>' +
		        '<p>Officers can edit tournament details, add or remove brackets, and modify participants at any time. If a tournament is no longer needed, it can be deleted by an authorized officer. Deleting a tournament removes all of its brackets and participant records.</p>'
		    }
		  ]
		},
		{
		  id: 'units',
		  title: 'Companies & Households',
		  icon: 'fas fa-shield-alt',
		  articles: [
		    {
		      id: 'understanding-units',
		      title: 'Understanding Units',
		      body: '<h2>Understanding Units</h2>' +
		        '<p>Units are player-created groups that exist independently of the park and kingdom structure. They represent fighting companies, households, and event-organizing teams.</p>' +
		        '<h3>Types of Units</h3>' +
		        '<ul>' +
		        '<li><strong>Company</strong> &mdash; A military or social fighting group. When you create a company, you automatically become its <strong>Captain</strong>. Your player record is linked to the company as your primary unit affiliation.</li>' +
		        '<li><strong>Household</strong> &mdash; A social group or family structure. The creator becomes the <strong>Lord</strong> of the household.</li>' +
		        '<li><strong>Event Unit</strong> &mdash; A group created specifically for organizing events. The creator becomes the <strong>Organizer</strong>.</li>' +
		        '</ul>' +
		        '<h3>Unit Information</h3>' +
		        '<p>Each unit has a profile page displaying:</p>' +
		        '<ul>' +
		        '<li><strong>Name</strong> &mdash; The unit&rsquo;s display name.</li>' +
		        '<li><strong>Type</strong> &mdash; Company, Household, or Event.</li>' +
		        '<li><strong>Description</strong> &mdash; A summary of the unit&rsquo;s purpose or theme.</li>' +
		        '<li><strong>History</strong> &mdash; Background and lore for the unit.</li>' +
		        '<li><strong>URL</strong> &mdash; An optional link to the unit&rsquo;s website or social media.</li>' +
		        '<li><strong>Heraldry</strong> &mdash; An uploaded image representing the unit&rsquo;s arms or logo.</li>' +
		        '</ul>' +
		        '<h3>Membership</h3>' +
		        '<p>Unit members each have a <strong>role</strong> (such as captain, lord, member, or officer) and an optional <strong>title</strong> (for example, &ldquo;Founder&rdquo;). Members can be active or retired. Units are separate from your park and kingdom membership &mdash; you can belong to a unit regardless of which park you are in.</p>'
		    },
		    {
		      id: 'managing-units',
		      title: 'Managing Units',
		      body: '<h2>Managing Units</h2>' +
		        '<p>If you have management authorization for a unit, you can administer its details and membership from the unit admin panel.</p>' +
		        '<h3>Creating a Unit</h3>' +
		        '<p>Any logged-in player can create a new unit. Provide a <strong>Name</strong>, select the <strong>Type</strong> (Company, Household, or Event), and optionally fill in a description, history, URL, and heraldry image. You will automatically be added as the first member with the appropriate leadership role and the &ldquo;Founder&rdquo; title.</p>' +
		        '<h3>Editing Unit Details</h3>' +
		        '<p>From the admin panel, you can update the unit&rsquo;s name, description, history, URL, and heraldry image at any time.</p>' +
		        '<h3>Managing Members</h3>' +
		        '<ul>' +
		        '<li><strong>Add a member</strong> &mdash; Search for a player by persona name, then assign them a role (captain, lord, member, officer, or organizer) and an optional title.</li>' +
		        '<li><strong>Edit a member</strong> &mdash; Change an existing member&rsquo;s role or title.</li>' +
		        '<li><strong>Retire a member</strong> &mdash; Marks the member as retired. They remain on the roster for historical purposes, but their management authorization for the unit is removed. Members can also retire themselves.</li>' +
		        '<li><strong>Remove a member</strong> &mdash; Completely deletes the membership record and removes any unit authorization.</li>' +
		        '</ul>' +
		        '<h3>Converting Unit Type</h3>' +
		        '<p>A Company can be converted to a Household, and vice versa. This action is available to the unit&rsquo;s managing officer or to kingdom-level officers. The conversion changes the unit type but preserves all members and history.</p>' +
		        '<h3>Merging Units</h3>' +
		        '<p>Administrators can merge two units by selecting a <strong>source</strong> unit and a <strong>destination</strong> unit. All members, awards, authorizations, and event records from the source are transferred to the destination, and the source unit is deleted.</p>' +
		        '<blockquote>Merging units is permanent and cannot be undone. Double-check the source and destination before confirming.</blockquote>'
		    }
		  ]
		},
		{
		  id: 'reports',
		  title: 'Reports',
		  icon: 'fas fa-chart-bar',
		  articles: [
		    {
		      id: 'reports-overview',
		      title: 'Reports Overview',
		      body: '<h2>Reports Overview</h2>' +
		        '<p>The ORK includes a comprehensive reporting system that lets you view attendance trends, player rosters, award standings, and more. Most reports are accessed from the <strong>Reports</strong> tab on a kingdom or park profile page.</p>' +
		        '<h3>Where to Find Reports</h3>' +
		        '<ul>' +
		        '<li><strong>Kingdom profile &rarr; Reports tab</strong> &mdash; Kingdom-wide reports covering all parks.</li>' +
		        '<li><strong>Park profile &rarr; Reports tab</strong> &mdash; Reports scoped to a single park.</li>' +
		        '</ul>' +
		        '<h3>Report Categories</h3>' +
		        '<ul>' +
		        '<li><strong>Attendance</strong> &mdash; Attendance summaries, trends, new player tracking, and the Park Attendance Explorer.</li>' +
		        '<li><strong>Rosters</strong> &mdash; Active, inactive, waivered, unwaivered, and suspended player lists.</li>' +
		        '<li><strong>Awards</strong> &mdash; Knights, Masters, Ladder Grid, custom awards, and class masters/paragons.</li>' +
		        '<li><strong>Specialty</strong> &mdash; Reeve qualified, Corpora qualified, Beltline Explorer, dues paid, and officer directories.</li>' +
		        '<li><strong>Heraldry</strong> &mdash; Visual galleries of player, park, unit, kingdom, and event heraldry.</li>' +
		        '<li><strong>Events</strong> &mdash; Event attendance summaries by kingdom or park.</li>' +
		        '<li><strong>Geographic</strong> &mdash; Closest parks and park distance tools.</li>' +
		        '</ul>' +
		        '<h3>Public vs. Restricted Reports</h3>' +
		        '<p>Some reports are available to all visitors (roster, knights &amp; masters, attendance, suspended). Others require you to be logged in and may be limited to officers or administrators depending on the data involved.</p>' +
		        '<blockquote>If a report you expect to see is missing, make sure you are logged in and have the appropriate officer role for that kingdom or park.</blockquote>'
		    },
		    {
		      id: 'attendance-roster-reports',
		      title: 'Attendance & Roster Reports',
		      body: '<h2>Attendance &amp; Roster Reports</h2>' +
		        '<p>These reports help officers track who is playing, how often, and whether they meet activity requirements.</p>' +
		        '<h3>Attendance Summary</h3>' +
		        '<p>Shows total attendance counts for a kingdom or park over a configurable time period. Trend indicators compare the current period to the previous one so you can see whether activity is growing or declining.</p>' +
		        '<h3>Park Attendance Explorer</h3>' +
		        '<p>An interactive report that lets you dig into attendance patterns. Choose a time range and a grouping period (weekly, monthly, quarterly, or annually). In <strong>All Parks</strong> mode, you see one row per park with sign-in totals, unique players, and member thresholds. In <strong>Single Park</strong> mode, you see a player-by-period pivot table showing exactly when each person attended. Options include filtering to local players only and setting a minimum sign-in count.</p>' +
		        '<h3>New Player Attendance</h3>' +
		        '<p>Tracks players who first appeared in the system within a configurable date window (default 90 days). Useful for measuring new-player retention by showing how many of those newcomers returned for additional visits.</p>' +
		        '<h3>Event Attendance</h3>' +
		        '<p>Lists events hosted by a kingdom or park along with their attendance counts, making it easy to compare event turnout.</p>' +
		        '<h3>Active Player Roster</h3>' +
		        '<p>Lists all players who meet the minimum attendance requirement set in your kingdom&rsquo;s configuration. Includes persona, park, waiver status, and dues status columns.</p>' +
		        '<h3>Inactive Player Roster</h3>' +
		        '<p>Players who have not met the attendance threshold. Helpful for identifying members who may have moved away or stopped playing.</p>' +
		        '<h3>Other Roster Variants</h3>' +
		        '<ul>' +
		        '<li><strong>Waivered / Unwaivered</strong> &mdash; Filters the roster by waiver status.</li>' +
		        '<li><strong>Suspended</strong> &mdash; Shows players who are currently under suspension, including dates and reason.</li>' +
		        '<li><strong>Dues Paid</strong> &mdash; Players whose dues are recorded as current.</li>' +
		        '</ul>'
		    },
		    {
		      id: 'award-specialty-reports',
		      title: 'Award & Specialty Reports',
		      body: '<h2>Award &amp; Specialty Reports</h2>' +
		        '<p>These reports cover awards, qualifications, and specialized data that officers and players frequently reference.</p>' +
		        '<h3>Knights &amp; Masters Lists</h3>' +
		        '<p>View all knighted or mastered players for a kingdom or park. Available as separate lists (Knights List, Masters List) or combined (Knights &amp; Masters). These reports are publicly accessible.</p>' +
		        '<h3>Ladder Grid</h3>' +
		        '<p>A comprehensive matrix showing every player&rsquo;s current rank in each ladder award for a kingdom or park. Columns represent individual awards; rows represent players. This is the quickest way to see who is close to their next rank.</p>' +
		        '<h3>Class Masters &amp; Paragons</h3>' +
		        '<p>Lists players who have reached Master or Paragon status in any Amtgard class, based on accumulated credits.</p>' +
		        '<h3>Custom Awards</h3>' +
		        '<p>Shows awards that do not fall into standard ladder categories, such as kingdom-specific honors or special recognitions.</p>' +
		        '<h3>Award Recommendations</h3>' +
		        '<p>An admin-only report that identifies players who may qualify for awards based on their attendance and existing award history. Useful for monarchs preparing their award lists.</p>' +
		        '<h3>Beltline Explorer</h3>' +
		        '<p>Visualizes mentorship and peerage chains within a kingdom. See which knights have belted which squires, and trace the lineage across generations of players.</p>' +
		        '<h3>Reeve &amp; Corpora Qualified</h3>' +
		        '<p>Lists players who meet the qualification requirements for Reeve or Corpora certification based on their recorded credits and attendance.</p>' +
		        '<h3>Kingdom Officer Directory</h3>' +
		        '<p>A consolidated list of all current park-level officers across an entire kingdom, making it easy to find contact points for any chapter.</p>' +
		        '<h3>Other Specialty Reports</h3>' +
		        '<ul>' +
		        '<li><strong>Guild Report</strong> &mdash; Guild membership and activity data by kingdom or park.</li>' +
		        '<li><strong>Heraldry Galleries</strong> &mdash; Browse uploaded heraldry images for players, parks, units, kingdoms, or events.</li>' +
		        '<li><strong>Closest Parks</strong> &mdash; Find the nearest parks to a given location.</li>' +
		        '</ul>'
		    }
		  ]
		},
		{
		  id: 'administration',
		  title: 'Administration',
		  icon: 'fas fa-cogs',
		  articles: [
		    {
		      id: 'admin-dashboard',
		      title: 'Admin Dashboard',
		      body: '<h2>Admin Dashboard</h2>' +
		        '<p>The Admin Dashboard provides a high-level overview of the ORK&rsquo;s health and activity. It is the landing page for administrators and authorized officers.</p>' +
		        '<h3>What the Dashboard Shows</h3>' +
		        '<ul>' +
		        '<li><strong>Active Kingdoms Summary</strong> &mdash; A snapshot of every active kingdom with recent attendance and player counts.</li>' +
		        '<li><strong>Total Active Players</strong> &mdash; The number of distinct players who have signed in within the last six months.</li>' +
		        '<li><strong>Year-over-Year Trends</strong> &mdash; Comparison cards for awards entered, attendance records, distinct active players, and award recommendations between this year and last year.</li>' +
		        '</ul>' +
		        '<h3>Who Can Access It</h3>' +
		        '<ul>' +
		        '<li><strong>ORK Administrators</strong> &mdash; Full access to every function in the admin panel, including global player management, kingdom creation, and system-wide merges.</li>' +
		        '<li><strong>Kingdom Officers</strong> &mdash; Access to admin functions scoped to their kingdom (player management, park management, reports).</li>' +
		        '<li><strong>Park Officers</strong> &mdash; Access to admin functions scoped to their park (attendance entry, player creation, awards).</li>' +
		        '</ul>' +
		        '<blockquote>The dashboard is only visible when you are logged in. If you do not see it, you may not have an officer role assigned. Contact your kingdom&rsquo;s Monarch or Prime Minister for assistance.</blockquote>'
		    },
		    {
		      id: 'player-admin',
		      title: 'Player Administration',
		      body: '<h2>Player Administration</h2>' +
		        '<p>Officers with the appropriate authorization can create, edit, and manage player accounts through the admin panel.</p>' +
		        '<h3>Creating a Player</h3>' +
		        '<p>To create a new player account, fill in these fields:</p>' +
		        '<ul>' +
		        '<li><strong>Persona</strong> &mdash; The player&rsquo;s Amtgard character name.</li>' +
		        '<li><strong>Username</strong> &mdash; Their login name.</li>' +
		        '<li><strong>Password</strong> &mdash; An initial password (the player should change it after first login).</li>' +
		        '<li><strong>Email</strong> &mdash; Contact email for account recovery.</li>' +
		        '<li><strong>Park</strong> &mdash; The player&rsquo;s home park.</li>' +
		        '<li><strong>Heraldry &amp; Waiver</strong> (optional) &mdash; Upload a heraldry image or a scanned waiver document.</li>' +
		        '</ul>' +
		        '<h3>Merging Duplicate Players</h3>' +
		        '<p>If a player has two accounts, you can merge them by selecting a <strong>From</strong> (source) player and a <strong>To</strong> (destination) player. All attendance, awards, authorizations, and other records from the source are transferred to the destination. The source account is then removed.</p>' +
		        '<blockquote>Merging players is permanent and cannot be reversed. Verify both accounts carefully before proceeding.</blockquote>' +
		        '<h3>Moving Players Between Parks</h3>' +
		        '<p>Use the <strong>Move Player</strong> or <strong>Claim Player</strong> function to transfer a player to a different park. This updates their home park record without affecting their award or attendance history.</p>' +
		        '<h3>Suspending a Player</h3>' +
		        '<p>Officers can suspend a player for a defined period. A suspension requires:</p>' +
		        '<ul>' +
		        '<li><strong>Suspended From / Until</strong> &mdash; The date range of the suspension.</li>' +
		        '<li><strong>Reason</strong> &mdash; A description of why the suspension was issued.</li>' +
		        '</ul>' +
		        '<p>Suspensions automatically lift when the &ldquo;Until&rdquo; date passes. They can also be removed manually.</p>' +
		        '<h3>Banning a Player</h3>' +
		        '<p>Banning is a more severe action that permanently blocks a player from logging in. Unlike suspension, a ban has no automatic end date. It can be reversed by an administrator if circumstances change. Banned players appear on the banned players list.</p>'
		    },
		    {
		      id: 'permissions',
		      title: 'Permissions & Authorization',
		      body: '<h2>Permissions &amp; Authorization</h2>' +
		        '<p>The ORK uses a three-part authorization model to control who can do what. Understanding this model helps officers and administrators manage access effectively.</p>' +
		        '<h3>The Three Parts</h3>' +
		        '<ul>' +
		        '<li><strong>Type</strong> &mdash; The kind of entity the authorization applies to: Kingdom, Park, Event, Unit, or Admin (system-wide).</li>' +
		        '<li><strong>ID</strong> &mdash; Which specific entity the authorization is for (for example, a particular kingdom or park). For Admin-level authorization, no specific ID is needed.</li>' +
		        '<li><strong>Role</strong> &mdash; The level of access granted:' +
		        '<ul>' +
		        '<li><strong>Create</strong> &mdash; Full management rights. Can add and remove members, grant awards, modify settings, and manage other authorizations for that entity.</li>' +
		        '<li><strong>Edit</strong> &mdash; Limited modification rights. Can update records and enter data but cannot manage authorizations or perform destructive actions.</li>' +
		        '<li><strong>Admin</strong> &mdash; System-wide override. Grants access to all ORK functions regardless of entity.</li>' +
		        '</ul>' +
		        '</li>' +
		        '</ul>' +
		        '<h3>How Authorization Is Assigned</h3>' +
		        '<p>When a player is elected or appointed as an officer, an administrator grants them the appropriate authorization. Officers automatically receive authorization for the entity they serve.</p>' +
		        '<h3>Authorization Hierarchy</h3>' +
		        '<p>Authorization cascades through the organizational structure:</p>' +
		        '<ul>' +
		        '<li><strong>Kingdom authorization</strong> cascades down to all parks within that kingdom.</li>' +
		        '<li><strong>Park authorization</strong> cascades to events hosted by that park.</li>' +
		        '<li><strong>Unit authorization</strong> can also be granted by kingdom-level officers.</li>' +
		        '</ul>' +
		        '<h3>Viewing &amp; Managing Authorizations</h3>' +
		        '<p>Administrators can view, add, and remove authorizations from the admin panel. Each authorization entry shows the player, entity type, entity name, and role. To add a new authorization, search for the player by persona and select the appropriate type, entity, and role.</p>' +
		        '<blockquote>If an officer steps down or is replaced, remember to remove their old authorization so they no longer have management access to that entity.</blockquote>'
		    }
		  ]
		}

	]
};

/* ========== ORK Documentation Logic ========== */
(function() {
	var _overlay  = document.getElementById('orkdoc-overlay');
	var _sidebar  = document.getElementById('orkdoc-sidebar');
	var _nav      = document.getElementById('orkdoc-nav');
	var _main     = document.getElementById('orkdoc-main');
	var _search   = document.getElementById('orkdoc-search');

	var _currentSectionId = null;
	var _currentArticleId = null;
	var _expandedSections = {};

	/* --- Render sidebar navigation --- */
	function orkDocRenderNav(filterTerm) {
		var term = (filterTerm || '').toLowerCase().trim();
		var html = '';
		var matchCount = 0;

		ORKDOC_DATA.sections.forEach(function(section) {
			var sectionMatches = !term || section.title.toLowerCase().indexOf(term) !== -1;
			var matchingArticles = [];

			section.articles.forEach(function(article) {
				if (!term || sectionMatches || article.title.toLowerCase().indexOf(term) !== -1 || article.body.replace(/<[^>]*>/g, '').toLowerCase().indexOf(term) !== -1) {
					matchingArticles.push(article);
				}
			});

			if (matchingArticles.length === 0) return;
			matchCount += matchingArticles.length;

			var isExpanded = term || _expandedSections[section.id];
			var isActive = section.id === _currentSectionId;

			html += '<div class="orkdoc-section" data-section-id="' + section.id + '">';
			html += '<button class="orkdoc-section-btn' +
				(isActive ? ' orkdoc-section-active' : '') +
				(isExpanded ? ' orkdoc-section-expanded' : '') +
				'" onclick="orkDocToggleSection(\'' + section.id + '\')">';
			html += '<span class="orkdoc-section-icon"><i class="' + section.icon + '"></i></span>';
			html += '<span>' + orkDocHighlight(section.title, term) + '</span>';
			html += '<span class="orkdoc-section-chevron"><i class="fas fa-chevron-right"></i></span>';
			html += '</button>';
			html += '<ul class="orkdoc-article-list' + (isExpanded ? ' orkdoc-articles-open' : '') + '">';

			matchingArticles.forEach(function(article) {
				var artActive = (section.id === _currentSectionId && article.id === _currentArticleId);
				html += '<li><a class="orkdoc-article-link' + (artActive ? ' orkdoc-article-active' : '') +
					'" onclick="orkDocNavigate(\'' + section.id + '\',\'' + article.id + '\')">' +
					orkDocHighlight(article.title, term) + '</a></li>';
			});

			html += '</ul></div>';
		});

		if (matchCount === 0 && term) {
			html = '<div class="orkdoc-no-results"><i class="fas fa-search" style="margin-bottom:6px;display:block;font-size:18px;"></i>No results for "' + orkDocEsc(term) + '"</div>';
		}

		_nav.innerHTML = html;
	}

	/* --- Highlight search term in text --- */
	function orkDocHighlight(text, term) {
		if (!term) return orkDocEsc(text);
		var safe = orkDocEsc(text);
		var re = new RegExp('(' + term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi');
		return safe.replace(re, '<mark style="background:#fefcbf;padding:0 1px;border-radius:2px;">$1</mark>');
	}

	/* --- Escape HTML --- */
	function orkDocEsc(str) {
		var div = document.createElement('div');
		div.appendChild(document.createTextNode(str || ''));
		return div.innerHTML;
	}

	/* --- Toggle section expand/collapse --- */
	window.orkDocToggleSection = function(sectionId) {
		_expandedSections[sectionId] = !_expandedSections[sectionId];
		orkDocRenderNav(_search.value);
	};

	/* --- Navigate to article --- */
	window.orkDocNavigate = function(sectionId, articleId) {
		var section = null;
		var article = null;

		ORKDOC_DATA.sections.forEach(function(s) {
			if (s.id === sectionId) {
				section = s;
				s.articles.forEach(function(a) {
					if (a.id === articleId) article = a;
				});
			}
		});

		if (!section || !article) return;

		_currentSectionId = sectionId;
		_currentArticleId = articleId;
		_expandedSections[sectionId] = true;

		// Render main content
		var html = '';
		html += '<div class="orkdoc-breadcrumb">';
		html += '<a class="orkdoc-breadcrumb-link" onclick="orkDocShowWelcome()">Documentation</a>';
		html += '<span class="orkdoc-breadcrumb-sep"><i class="fas fa-chevron-right"></i></span>';
		html += '<a class="orkdoc-breadcrumb-link" onclick="orkDocExpandSection(\'' + sectionId + '\')">' + orkDocEsc(section.title) + '</a>';
		html += '<span class="orkdoc-breadcrumb-sep"><i class="fas fa-chevron-right"></i></span>';
		html += '<span class="orkdoc-breadcrumb-current">' + orkDocEsc(article.title) + '</span>';
		html += '</div>';
		html += '<div class="orkdoc-content">';
		html += '<h1 class="orkdoc-article-title">' + orkDocEsc(article.title) + '</h1>';
		html += '<div class="orkdoc-article-body">' + article.body + '</div>';
		html += '</div>';

		_main.innerHTML = html;
		_main.scrollTop = 0;

		// Update sidebar
		orkDocRenderNav(_search.value);

		// Close mobile sidebar
		_sidebar.classList.remove('orkdoc-sidebar-open');
	};

	/* --- Expand section (from breadcrumb) --- */
	window.orkDocExpandSection = function(sectionId) {
		_expandedSections[sectionId] = true;
		_currentSectionId = null;
		_currentArticleId = null;
		orkDocShowWelcome();
		orkDocRenderNav(_search.value);
	};

	/* --- Show welcome/landing --- */
	window.orkDocShowWelcome = function() {
		_currentSectionId = null;
		_currentArticleId = null;

		var html = '';
		html += '<div class="orkdoc-welcome">';
		html += '<div class="orkdoc-welcome-icon"><i class="fas fa-book-open"></i></div>';
		html += '<div class="orkdoc-welcome-title">ORK Documentation</div>';
		html += '<div class="orkdoc-welcome-sub">Select a topic from the sidebar to get started, or use the search to find what you need.</div>';
		html += '</div>';

		_main.innerHTML = html;
		orkDocRenderNav(_search.value);
	};

	/* --- Toggle mobile sidebar --- */
	window.orkDocToggleSidebar = function() {
		_sidebar.classList.toggle('orkdoc-sidebar-open');
	};

	/* --- Open/Close --- */
	window.orkDocOpen = function() {
		_overlay.classList.add('orkdoc-open');
		document.body.style.overflow = 'hidden';
		_search.value = '';
		orkDocShowWelcome();
		// Focus search after open
		setTimeout(function() { _search.focus(); }, 100);
	};

	window.orkDocClose = function() {
		_overlay.classList.remove('orkdoc-open');
		document.body.style.overflow = '';
		_sidebar.classList.remove('orkdoc-sidebar-open');
	};

	/* --- Search input --- */
	var _searchTimer = null;
	_search.addEventListener('input', function() {
		clearTimeout(_searchTimer);
		_searchTimer = setTimeout(function() {
			orkDocRenderNav(_search.value);
		}, 150);
	});

	/* --- Keyboard support --- */
	document.addEventListener('keydown', function(e) {
		if (e.key === 'Escape' && _overlay.classList.contains('orkdoc-open')) {
			orkDocClose();
		}
	});

	/* --- Click overlay backdrop to close --- */
	_overlay.addEventListener('click', function(e) {
		if (e.target === _overlay) orkDocClose();
	});
})();
</script>
