<?php
	// ---- Normalize data ----
	$info      = $EventInfo   ?? [];
	$cd        = $EventDetail ?? [];
	$eventId   = (int)($event_id  ?? 0);
	$detailId  = (int)($detail_id ?? 0);
	$loggedIn  = $LoggedIn ?? false;

	$eventName   = htmlspecialchars($info['Name'] ?? 'Event');
	$hasHeraldry = !empty($info['HasHeraldry']);
	$heraldryUrl = $hasHeraldry
		? HTTP_EVENT_HERALDRY . Common::resolve_image_ext(DIR_EVENT_HERALDRY, sprintf('%05d', $eventId))
		: HTTP_EVENT_HERALDRY . '00000.jpg';

	$kingdomId   = (int)($info['KingdomId'] ?? 0);
	$kingdomName = htmlspecialchars($info['KingdomName'] ?? '');
	$parkId      = (int)($info['ParkId']    ?? 0);
	$parkName    = htmlspecialchars($info['ParkName']    ?? '');
	$atParkId    = (int)($cd['AtParkId']   ?? 0);
	$atParkName  = htmlspecialchars($AtParkName         ?? '');
	$unitId      = (int)($info['UnitId']    ?? 0);
	$unitName    = htmlspecialchars($info['Unit']        ?? '');
	$mundaneId   = (int)($info['MundaneId'] ?? 0);
	$persona     = htmlspecialchars($info['Persona']     ?? '');

	$isUpcoming    = $IsUpcoming     ?? false;
	$attendeeCount = $AttendanceCount ?? 0;
	$mapLink       = $MapLink        ?? '';

	$eventStart  = $cd['EventStart']  ?? null;
	$eventEnd    = $cd['EventEnd']    ?? null;
	$price       = (float)($cd['Price'] ?? 0);
	$eventFees   = $EventFees ?? [];
	$description = $cd['Description'] ?? '';
	$hasDescription = !empty(trim($description));
	$websiteUrl  = $cd['Url']     ?? '';
	$websiteName = $cd['UrlName'] ?? '';
	$mapUrlName  = $cd['MapUrlName'] ?? '';
	$mapUrl      = $cd['MapUrl']     ?? '';
	$address    = $cd['Address']    ?? '';
	$city       = $cd['City']       ?? '';
	$province   = $cd['Province']   ?? '';
	$postalCode = $cd['PostalCode'] ?? '';
	$country    = $cd['Country']    ?? '';
	$locationDisplay = implode(', ', array_filter([$address, $city, $province, $country]));
	$mapQueryAddress = implode(', ', array_filter([$address, $city, $province, $postalCode, $country]));

	// Park address fallback (used when event has no address)
	$atParkAddress    = trim($AtParkAddress    ?? '');
	$atParkCity       = trim($AtParkCity       ?? '');
	$atParkProvince   = trim($AtParkProvince   ?? '');
	$atParkPostalCode = trim($AtParkPostalCode ?? '');
	$locationFallback = (!$locationDisplay && ($atParkCity || $atParkProvince))
		? implode(', ', array_filter([$atParkCity, $atParkProvince])) : '';

	// Park map link fallback: parse park location JSON when event has no map link
	if (!$mapLink && $locationFallback) {
		$_parkLoc = @json_decode(stripslashes((string)($AtParkLocation ?? '')));
		if ($_parkLoc) {
			$_parkPt = isset($_parkLoc->location) ? $_parkLoc->location
				: (isset($_parkLoc->bounds->northeast) ? $_parkLoc->bounds->northeast : null);
			if ($_parkPt && is_numeric($_parkPt->lat ?? null))
				$mapLink = 'https://maps.google.com/maps?q=@' . $_parkPt->lat . ',' . $_parkPt->lng;
		}
	}

	// Duration
	$durationLabel = '';
	if ( $eventStart && $eventEnd ) {
		$startTs = strtotime($eventStart);
		$endTs   = strtotime($eventEnd);
		if ( $endTs > $startTs ) {
			$days = (int)ceil(($endTs - $startTs) / 86400);
			$durationLabel = $days . ' day' . ($days == 1 ? '' : 's');
		}
	}

	// [TOURNAMENTS HIDDEN]
	$tournaments  = [];
	$tourneyCount = 0;
	$attendanceList = $AttendanceReport['Attendance'] ?? [];
	$checkedInIds   = array_flip(array_column($attendanceList, 'MundaneId'));
	$attendanceForm = $Attendance_event ?? [];

	$defaultKingdomName = $DefaultKingdomName       ?? '';
	$defaultKingdomId   = $DefaultKingdomId         ?? 0;
	$defaultParkName    = $DefaultParkName          ?? '';
	$defaultParkId      = $DefaultParkId            ?? 0;
	$defaultCredits     = $DefaultAttendanceCredits ?? 1;

	$rsvpCount     = (int)($RsvpCount     ?? 0);
	$userAttending = (bool)($UserAttending ?? false);
	$rsvpList      = $RsvpList ?? [];
	$scheduleList  = $ScheduleList ?? [];
	$scheduleCount = count($scheduleList);
	$mealList  = $MealList ?? [];
	$mealCount = count($mealList);
	$canManage           = $CanManageEvent ?? false;
	$canManageAttendance = $CanManageAttendance ?? false;
	$canManageSchedule   = $CanManageSchedule ?? false;
	$canManageFeast      = $CanManageFeast ?? false;
	$canManageStaff = $canManage || $canManageAttendance;
	$canDelete           = ($attendeeCount === 0 && $rsvpCount === 0);

	// Date badge label
	$startLabel = $eventStart ? date('M j, Y', strtotime($eventStart)) : '';
	$endLabel   = $eventEnd   ? date('M j, Y', strtotime($eventEnd))   : '';
	$dateBadgeText = $startLabel;
	if ( $endLabel && $endLabel !== $startLabel ) $dateBadgeText .= ' – ' . $endLabel;

	// Past-event check (date only, ignoring time)
	$_refDateStr  = $eventEnd ?: $eventStart;
	$isPastEvent  = $_refDateStr && (strtotime(date('Y-m-d', strtotime($_refDateStr))) < strtotime(date('Y-m-d')));
?>

<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">
<style>
.ev-modal-btn-delete {
	background: #fff0f0; border: 1px solid #fc8181; color: #c53030;
	padding: 8px 14px; border-radius: 5px; font-size: 13px; font-weight: 600;
	cursor: pointer; transition: background .15s, border-color .15s;
}
.ev-modal-btn-delete:hover:not(:disabled) { background: #fed7d7; border-color: #e53e3e; }
.ev-modal-btn-delete-disabled { opacity: .45; cursor: not-allowed; }
.ev-del-detail-wrap { position: relative; display: inline-block; }
.ev-del-detail-tooltip {
	display: none; position: fixed; background: #1a202c; color: #fff; font-size: 12px;
	padding: 6px 11px; border-radius: 4px; white-space: nowrap;
	pointer-events: none; z-index: 9999; box-shadow: 0 2px 8px rgba(0,0,0,.25);
	transform: translateX(0) translateY(calc(-100% - 8px));
}
.ev-del-detail-tooltip::after {
	content: ''; position: absolute; top: 100%; left: 14px;
	border: 5px solid transparent; border-top-color: #1a202c;
}
.ev-del-detail-wrap:hover .ev-del-detail-tooltip { display: block; }
/* Heraldry edit overlay */
.ev-heraldry-edit-wrap { position: relative; display: inline-block; cursor: pointer; }
.ev-heraldry-edit-overlay {
	position: absolute; inset: 0; background: rgba(0,0,0,0); border-radius: 6px;
	display: flex; align-items: center; justify-content: center; transition: background .2s;
}
.ev-heraldry-edit-wrap:hover .ev-heraldry-edit-overlay { background: rgba(0,0,0,0.45); }
.ev-heraldry-edit-icon { color: #fff; font-size: 22px; opacity: 0; transition: opacity .2s; }
.ev-heraldry-edit-wrap:hover .ev-heraldry-edit-icon { opacity: 1; }
/* Image upload modal */
.ev-img-overlay {
	display: none; position: fixed; inset: 0; background: rgba(0,0,0,.55);
	z-index: 1500; align-items: center; justify-content: center;
}
.ev-img-overlay.ev-open { display: flex; }
.ev-img-modal {
	background: #fff; border-radius: 10px; width: min(520px, 96vw);
	box-shadow: 0 8px 32px rgba(0,0,0,.22); overflow: hidden;
}
.ev-img-modal-header {
	display: flex; align-items: center; justify-content: space-between;
	padding: 14px 18px; border-bottom: 1px solid #e2e8f0; background: #f7fafc;
}
.ev-img-modal-title { font-size: 15px; font-weight: 700; color: #2d3748; margin: 0; }
.ev-img-close-btn { background: none; border: none; font-size: 20px; color: #718096; cursor: pointer; padding: 0 4px; }
.ev-img-modal-body { padding: 20px 22px; }
.ev-upload-area {
	display: flex; flex-direction: column; align-items: center; gap: 8px;
	border: 2px dashed #cbd5e0; border-radius: 8px; padding: 28px 20px;
	cursor: pointer; color: #4a5568; font-size: 14px; text-align: center;
	transition: border-color .15s, background .15s;
}
.ev-upload-area:hover { border-color: #4299e1; background: #ebf8ff; }
.ev-upload-icon { font-size: 32px; color: #a0aec0; }
.ev-upload-area small { font-size: 12px; color: #a0aec0; }
.ev-img-step-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 14px; }
.ev-crop-wrap { overflow: auto; max-height: 360px; display: flex; justify-content: center; }
.ev-img-form-error { background: #fff5f5; border: 1px solid #feb2b2; color: #c53030; padding: 8px 12px; border-radius: 5px; font-size: 13px; margin-top: 8px; }
.ev-sched-pill {
	display: inline-flex; align-items: center; padding: 4px 11px;
	border-radius: 20px; font-size: 12px; font-weight: 600; cursor: pointer;
	transition: opacity .15s, background .15s, border-color .15s;
	white-space: nowrap; border-width: 1px; border-style: solid;
}
.ev-sched-pill-inactive {
	background: #fff !important; border-color: #ddd !important;
	color: #bbb !important; opacity: 0.6;
}
.ev-sched-pill-inactive i { color: #ccc !important; }
.ev-sched-day-header {
	font-weight: 700; font-size: 15px; color: #2d3748;
	margin: 18px 0 6px; padding-bottom: 5px;
	border-bottom: 2px solid #e2e8f0;
}
.ev-sched-day-section:first-child .ev-sched-day-header { margin-top: 4px; }
.ev-sched-day-section + .ev-sched-day-section { margin-top: 10px; }
.ev-sched-table { table-layout: fixed; width: 100%; }
.ev-fp-title { background: #2b6cb0; color: #fff; font-size: 12px; font-weight: 700; padding: 6px 12px; text-align: center; letter-spacing: .04em; }
.ev-meal-card {
	border: 1px solid #f7d9c4; border-radius: 8px; background: #fff8f5;
	margin-bottom: 12px; overflow: hidden;
}
.ev-meal-card-header {
	display: flex; align-items: center; justify-content: space-between;
	padding: 10px 14px; background: #fff3ec; border-bottom: 1px solid #f7d9c4;
}
.ev-meal-title { font-weight: 700; font-size: 15px; color: #2d3748; }
.ev-meal-cost { font-size: 14px; color: #4a5568; }
.ev-meal-menu {
	padding: 10px 14px; font-size: 14px; color: #4a5568;
	white-space: pre-line; line-height: 1.6;
}
.ev-meal-footer {
	padding: 8px 14px 10px; display: flex; flex-wrap: wrap; gap: 6px;
	border-top: 1px solid #f7d9c4;
}
.ev-meal-tag {
	display: inline-flex; align-items: center; gap: 4px;
	font-size: 11px; font-weight: 600; padding: 3px 8px; border-radius: 20px;
	white-space: nowrap;
}
.ev-meal-tag-dietary { background: #c6f6d5; color: #276749; }
.ev-meal-tag-allergen { background: #feebc8; color: #7b341e; }
.ev-meal-cb-group { display: flex; flex-wrap: wrap; gap: 6px 16px; margin-top: 4px; }
.ev-meal-cb-group label { display: flex; align-items: center; gap: 5px; font-size: 13px; font-weight: 400; cursor: pointer; }
.ev-meal-cb-group input[type=checkbox] { margin: 0; cursor: pointer; }
.ev-edit-btn { background: none; border: none; cursor: pointer; color: #718096; font-size: 15px; padding: 0; line-height: 1; }
.ev-edit-btn:hover { color: #2b6cb0; }
</style>

<?php // ---- HERO ---- ?>
<div class="ev-hero" id="ev-hero">
	<div class="ev-hero-bg"
		<?php if ($heraldryUrl): ?>
			style="background-image: url('<?= htmlspecialchars($heraldryUrl) ?>')"
		<?php endif; ?>
	></div>
	<div class="ev-hero-content">

		<div class="ev-heraldry-frame<?= $canManage ? ' ev-heraldry-edit-wrap' : '' ?>"<?= $canManage ? ' onclick="evOpenImgModal()" title="Change heraldry"' : '' ?>>
			<img id="ev-heraldry-img"
				src="<?= htmlspecialchars($heraldryUrl) ?>"
				onerror="this.src='<?= HTTP_EVENT_HERALDRY ?>00000.jpg'"
				alt="<?= $eventName ?> heraldry"
				crossorigin="anonymous">
			<?php if ($canManage): ?>
			<div class="ev-heraldry-edit-overlay"><i class="fas fa-camera ev-heraldry-edit-icon"></i></div>
			<?php endif; ?>
		</div>

		<div class="ev-hero-info">
			<h1 class="ev-event-name"><?= $eventName ?></h1>
			<div class="ev-badges">
				<?php if ($dateBadgeText): ?>
				<span class="ev-badge <?= $isUpcoming ? 'ev-badge-green' : 'ev-badge-gray' ?>">
					<i class="fas fa-calendar-alt"></i> <?= htmlspecialchars($dateBadgeText) ?>
				</span>
				<?php endif; ?>
				<span class="ev-badge <?= $isUpcoming ? 'ev-badge-green' : 'ev-badge-gray' ?>">
					<?= $isUpcoming ? '<i class="fas fa-clock"></i> Upcoming' : '<i class="fas fa-history"></i> Past' ?>
				</span>
			</div>
			<div class="ev-owner-inline">
				<i class="fas fa-layer-group" style="font-size:10px;opacity:0.6;margin-right:4px"></i>
				<?= $eventName ?>
				<?php if ($kingdomId): ?>
					<span class="ev-owner-sep">›</span>
					<a href="<?= UIR ?>Kingdom/profile/<?= $kingdomId ?>"><?= $kingdomName ?></a>
				<?php endif; ?>
				<?php
					$breadcrumbParkId   = $atParkId   ?: $parkId;
					$breadcrumbParkName = $atParkId ? $atParkName : $parkName;
				?>
				<?php if ($breadcrumbParkId): ?>
					<span class="ev-owner-sep">›</span>
					<a href="<?= UIR ?>Park/profile/<?= $breadcrumbParkId ?>"><?= $breadcrumbParkName ?></a>
				<?php endif; ?>
			</div>
		</div>

		<div class="ev-hero-actions">
			<a class="ev-btn ev-btn-white"
				href="<?= UIR ?>Reports/attendance/Event/<?= $eventId ?>/All">
				<i class="fas fa-list-alt"></i> Attendance Report
			</a>
			<?php if ($CanManageEvent ?? false): ?>
			<button class="ev-btn ev-btn-outline" type="button" onclick="evOpenEditModal()">
				<i class="fas fa-pencil-alt"></i> Edit Details
			</button>
			<?php endif; ?>
			<?php if ($loggedIn && $isUpcoming): ?>
			<form method="post" action="<?= UIR ?>Event/detail/<?= $eventId ?>/<?= $detailId ?>/rsvp" style="margin:0">
				<button type="submit" class="ev-btn <?= $userAttending ? 'ev-btn-secondary' : 'ev-btn-outline' ?>"
					onclick="gtag('event','event_rsvp',{action:'<?= $userAttending ? 'cancel' : 'confirm' ?>'})">
					<i class="fas <?= $userAttending ? 'fa-times-circle' : 'fa-check-circle' ?>"></i>
					<?= $userAttending ? 'Cancel RSVP' : 'RSVP' ?>
				</button>
			</form>
			<?php endif; ?>

		</div>

	</div>
</div>

<?php // ---- STATS ROW ---- ?>
<div class="ev-stats-row">
	<div class="ev-stat-card">
		<div class="ev-stat-icon"><i class="fas fa-calendar-alt"></i></div>
		<div class="ev-stat-value" style="font-size:15px;padding-top:3px">
			<?= $startLabel ?: '<span style="color:#a0aec0">TBD</span>' ?>
		</div>
		<div class="ev-stat-label">Date</div>
	</div>
	<div class="ev-stat-card">
		<div class="ev-stat-icon"><i class="fas fa-clock"></i></div>
		<div class="ev-stat-value" style="font-size:15px;padding-top:3px">
			<?= $eventStart ? date('g:i A', strtotime($eventStart)) : '<span style="color:#a0aec0">TBD</span>' ?>
		</div>
		<div class="ev-stat-label">Starts At</div>
	</div>
	<?php $hasMapTab = (bool)($locationDisplay ?: $locationFallback); ?>
	<?php if (!$locationDisplay && $mapUrl): ?>
	<a href="<?= htmlspecialchars($mapUrl) ?>" target="_blank" class="ev-stat-card ev-stat-card-link" style="cursor:pointer;text-decoration:none;color:inherit">
		<div class="ev-stat-icon"><i class="fas fa-map-marker-alt"></i></div>
		<div class="ev-stat-value" style="font-size:14px;padding-top:3px;color:#4a90d9"><?= htmlspecialchars($mapUrlName ?: 'View Map') ?></div>
		<div class="ev-stat-label">Location</div>
	</a>
	<?php else: ?>
	<div class="ev-stat-card<?= $hasMapTab ? ' ev-stat-card-link' : '' ?>"<?= $hasMapTab ? ' onclick="evShowTab(document.querySelector(\'[data-tab=ev-tab-map]\'),\'ev-tab-map\')" title="View map"' : '' ?> style="<?= $hasMapTab ? 'cursor:pointer' : '' ?>">
		<div class="ev-stat-icon"><i class="fas fa-map-marker-alt"></i></div>
		<div class="ev-stat-value" style="font-size:14px;padding-top:3px">
			<?php $_dispLoc = $locationDisplay ?: $locationFallback; ?>
			<?= $_dispLoc ? htmlspecialchars($_dispLoc) : '<span style="color:#a0aec0">TBD</span>' ?>
		</div>
		<div class="ev-stat-label">Location</div>
	</div>
	<?php endif; ?>
	<div class="ev-stat-card">
		<div class="ev-stat-icon"><i class="fas fa-users"></i></div>
		<div class="ev-stat-value"><?= $isUpcoming ? $rsvpCount : $attendeeCount ?></div>
		<div class="ev-stat-label"><?= $isUpcoming ? 'RSVPs' : 'Attendees' ?></div>
	</div>
</div>

<?php // ---- LAYOUT ---- ?>
<div class="ev-layout">

	<?php // ---- SIDEBAR ---- ?>
	<div class="ev-sidebar">

		<?php if ($canManage): ?>
		<div class="ev-heraldry-edit-wrap" onclick="evOpenImgModal()" title="Change heraldry">
			<img class="ev-heraldry-large"
				src="<?= htmlspecialchars($heraldryUrl) ?>"
				onerror="this.src='<?= HTTP_EVENT_HERALDRY ?>00000.jpg'"
				alt="">
			<div class="ev-heraldry-edit-overlay"><i class="fas fa-camera ev-heraldry-edit-icon"></i></div>
		</div>
		<?php else: ?>
		<img class="ev-heraldry-large"
			src="<?= htmlspecialchars($heraldryUrl) ?>"
			onerror="this.src='<?= HTTP_EVENT_HERALDRY ?>00000.jpg'"
			alt="">
		<?php endif; ?>

		<?php // Event Dates card ?>
		<div class="ev-card">
			<h4><i class="fas fa-calendar" style="margin-right:5px"></i>Event Dates</h4>
			<?php if ($eventStart): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Start</span>
				<span class="ev-detail-value"><?= date('M j, Y', strtotime($eventStart)) ?></span>
			</div>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Time</span>
				<span class="ev-detail-value"><?= date('g:i A', strtotime($eventStart)) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($eventEnd): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">End</span>
				<span class="ev-detail-value"><?= date('M j, Y', strtotime($eventEnd)) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($durationLabel): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Duration</span>
				<span class="ev-detail-value"><?= $durationLabel ?></span>
			</div>
			<?php endif; ?>
		</div>

		<?php
			$_showAddress  = $address  ?: $atParkAddress;
			$_showCity     = $city     ?: $atParkCity;
			$_showProvince = $province ?: $atParkProvince;
			$_fromPark     = !($address || $city || $province) && ($atParkCity || $atParkProvince || $atParkAddress);
		?>
		<?php if ($locationDisplay || $locationFallback || $mapLink): ?>
		<?php // Location card ?>
		<div class="ev-card">
			<h4><i class="fas fa-map-marker-alt" style="margin-right:5px"></i>Location<?php if ($_fromPark): ?> <span style="font-size:11px;font-weight:400;color:#718096;margin-left:4px">(park address)</span><?php endif; ?></h4>
			<?php if ($_showAddress): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Address</span>
				<span class="ev-detail-value"><?= htmlspecialchars($_showAddress) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($_showCity): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">City</span>
				<span class="ev-detail-value"><?= htmlspecialchars($_showCity) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($_showProvince): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Region</span>
				<span class="ev-detail-value"><?= htmlspecialchars($_showProvince) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($postalCode): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Postal Code</span>
				<span class="ev-detail-value"><?= htmlspecialchars($postalCode) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($country): ?>
			<div class="ev-detail-row">
				<span class="ev-detail-label">Country</span>
				<span class="ev-detail-value"><?= htmlspecialchars($country) ?></span>
			</div>
			<?php endif; ?>
			<?php if ($mapLink): ?>
			<a href="<?= htmlspecialchars($mapLink) ?>" target="_blank" class="ev-map-btn">
				<i class="fas fa-map"></i> Google Maps
			</a>
			<?php endif; ?>
			<?php if ($mapUrl && $mapUrlName): ?>
			<a href="<?= htmlspecialchars($mapUrl) ?>" target="_blank" class="ev-map-btn" style="margin-top:6px;background:#f0fff4;border-color:#9ae6b4;">
				<i class="fas fa-map-signs"></i> <?= htmlspecialchars($mapUrlName) ?>
			</a>
			<?php endif; ?>
		</div>
		<?php endif; ?>


	</div><!-- /.ev-sidebar -->

	<?php // ---- MAIN CONTENT ---- ?>
	<div class="ev-main">

		<?php if (!empty($Error)): ?>
		<div class="ev-error"><i class="fas fa-exclamation-triangle" style="margin-right:6px"></i><?= $Error ?></div>
		<?php endif; ?>

		<div class="ev-tabs">

			<ul class="ev-tab-nav" id="ev-tab-nav">
				<li class="ev-tab-active" data-tab="ev-tab-details" onclick="evShowTab(this,'ev-tab-details')">
					<i class="fas fa-align-left"></i><span class="ev-tab-label"> Details</span>
				</li>
				<li data-tab="ev-tab-schedule" onclick="evShowTab(this,'ev-tab-schedule')">
					<i class="fas fa-clock"></i><span class="ev-tab-label"> Schedule</span>
					<span class="ev-tab-count"><?= $scheduleCount ?></span>
				</li>
				<li data-tab="ev-tab-feast" onclick="evShowTab(this,'ev-tab-feast')">
					<i class="fas fa-utensils"></i><span class="ev-tab-label"> Feast</span>
					<span class="ev-tab-count"><?= $mealCount ?></span>
				</li>
				<li data-tab="ev-tab-attendance" onclick="evShowTab(this,'ev-tab-attendance')">
					<i class="fas fa-clipboard-list"></i><span class="ev-tab-label"> Attendance</span>
					<span class="ev-tab-count"><?= $attendeeCount ?></span>
				</li>
				<?php /* [TOURNAMENTS HIDDEN] tab */ ?>
				<li data-tab="ev-tab-rsvp" onclick="evShowTab(this,'ev-tab-rsvp')">
					<i class="fas fa-calendar-check"></i><span class="ev-tab-label"> RSVPs</span>
					<span class="ev-tab-count"><?= $rsvpCount ?></span>
				</li>
				<li data-tab="ev-tab-staff" onclick="evShowTab(this,'ev-tab-staff')">
					<i class="fas fa-id-badge"></i><span class="ev-tab-label"> Staff</span>
					<span class="ev-tab-count"><?= count($StaffList ?? []) ?></span>
				</li>
				<?php if ($hasMapTab): ?>
				<li data-tab="ev-tab-map" onclick="evShowTab(this,'ev-tab-map')">
					<i class="fas fa-map-marked-alt"></i><span class="ev-tab-label"> Map</span>
				</li>
				<?php endif; ?>
				<?php if ($canManage): ?>
				<li data-tab="ev-tab-admin" onclick="evShowTab(this,'ev-tab-admin')">
					<i class="fas fa-cog"></i><span class="ev-tab-label"> Admin Tasks</span>
				</li>
				<?php endif; ?>
			</ul>

			<?php // ---- Details Tab ---- ?>
			<div class="ev-tab-panel ev-tab-visible" id="ev-tab-details">
				<div style="display:flex;gap:20px;align-items:flex-start">
					<div style="flex:1;min-width:0">
						<?php if ($hasDescription): ?>
							<div class="ev-description"><?= nl2br(htmlspecialchars(rawurldecode($description))) ?></div>
						<?php else: ?>
							<div class="ev-empty">
								<i class="fas fa-file-alt" style="margin-right:6px"></i>No description provided
							</div>
						<?php endif; ?>
					</div>
					<?php if (!empty($eventFees)): ?>
					<div style="flex:0 0 220px">
						<div class="ev-card" style="margin-bottom:0">
							<h4><i class="fas fa-ticket-alt" style="margin-right:5px"></i>Admission &amp; Fees</h4>
							<?php foreach ($eventFees as $fee): ?>
							<div class="ev-detail-row">
								<span class="ev-detail-label"><?= htmlspecialchars($fee['AdmissionType']) ?></span>
								<span class="ev-detail-value"><?= (float)$fee['Cost'] == 0 ? '<span style="color:#276749">Free</span>' : '$' . number_format((float)$fee['Cost'], 2) ?></span>
							</div>
							<?php endforeach; ?>
						</div>
					</div>
					<?php endif; ?>
				</div>
			</div>

			<?php // ---- Attendance Tab ---- ?>
			<div class="ev-tab-panel" id="ev-tab-schedule">

				<?php if ($canManageSchedule): ?>
				<div style="margin-bottom:14px">
					<button type="button" class="ev-submit-btn" style="float:right" onclick="evOpenScheduleModal()">
						<i class="fas fa-plus"></i> Add Schedule Item
					</button>
				</div>
				<?php endif; ?>

				<?php
			$evSchedCategories = [
				'Administrative'    => ['icon' => 'fa-clipboard-list', 'color' => '#546e7a', 'bg' => '#eceff1'],
				'Tournament'        => ['icon' => 'fa-trophy',          'color' => '#b8860b', 'bg' => '#fffde7'],
				'Battlegame'        => ['icon' => 'fa-shield-alt',      'color' => '#c0392b', 'bg' => '#fdecea'],
				'Arts and Sciences' => ['icon' => 'fa-palette',         'color' => '#7b1fa2', 'bg' => '#f3e5f5'],
				'Class'             => ['icon' => 'fa-graduation-cap',  'color' => '#1565c0', 'bg' => '#e3f2fd'],
				'Feast and Food'    => ['icon' => 'fa-utensils',        'color' => '#e65100', 'bg' => '#fff3e0'],
				'Court'             => ['icon' => 'fa-crown',           'color' => '#4e342e', 'bg' => '#efebe9'],
				'Other'             => ['icon' => 'fa-star',            'color' => '#757575', 'bg' => '#fafafa'],
			];
			?>
			<div id="ev-sched-filters" style="display:none;flex-wrap:wrap;gap:6px;margin-bottom:14px"></div>
			<div id="ev-schedule-container">
			<?php
			$scheduleByDay = [];
			foreach ($scheduleList as $item) {
				$dayKey = date('Ymd', strtotime($item['StartTime']));
				$scheduleByDay[$dayKey][] = $item;
			}
			foreach ($scheduleByDay as $dayKey => $dayItems):
				$dayTs = strtotime($dayItems[0]['StartTime']);
			?>
			<div class="ev-sched-day-section" data-date="<?= date('Y-m-d', $dayTs) ?>">
				<div class="ev-sched-day-header"><?= date('l, F j, Y', $dayTs) ?></div>
				<table class="ev-table ev-sched-table" id="ev-schedule-table-<?= $dayKey ?>">
					<colgroup>
						<col style="width:90px">
						<col style="width:90px">
						<col style="width:22%">
						<col style="width:15%">
						<col style="width:18%">
						<col>
						<?php if ($canManageSchedule): ?><col style="width:56px"><?php endif; ?>
					</colgroup>
					<thead>
						<tr>
							<th>Start</th>
							<th>End</th>
							<th>Title</th>
							<th>Location</th>
							<th>Lead(s)</th>
							<th>Description</th>
							<?php if ($canManageSchedule): ?><th class="ev-del-cell"></th><?php endif; ?>
						</tr>
					</thead>
					<tbody id="ev-schedule-tbody-<?= $dayKey ?>">
						<?php foreach ($dayItems as $item): ?>
						<?php $evCat = $item['Category'] ?? 'Other'; $evCatCfg = $evSchedCategories[$evCat] ?? $evSchedCategories['Other']; ?>
						<tr id="ev-schedule-row-<?= (int)$item['EventScheduleId'] ?>" data-title="<?= htmlspecialchars($item['Title'], ENT_QUOTES) ?>" data-start="<?= date('Y-m-d\TH:i', strtotime($item['StartTime'])) ?>" data-end="<?= date('Y-m-d\TH:i', strtotime($item['EndTime'])) ?>" data-location="<?= htmlspecialchars($item['Location'], ENT_QUOTES) ?>" data-description="<?= htmlspecialchars($item['Description'], ENT_QUOTES) ?>" data-category="<?= htmlspecialchars($evCat, ENT_QUOTES) ?>" data-leads="<?= htmlspecialchars(json_encode($item['Leads'] ?? []), ENT_QUOTES) ?>" style="background:<?= $evCatCfg['bg'] ?>">
							<td style="white-space:nowrap"><?= date('g:ia', strtotime($item['StartTime'])) ?></td>
							<td style="white-space:nowrap"><?= date('g:ia', strtotime($item['EndTime'])) ?></td>
							<td><i class="fas <?= $evCatCfg['icon'] ?>" style="color:<?= $evCatCfg['color'] ?>;margin-right:5px" title="<?= htmlspecialchars($evCat) ?>"></i><?= htmlspecialchars($item['Title']) ?></td>
							<td><?= htmlspecialchars($item['Location']) ?></td>
							<td><?php foreach ($item['Leads'] ?? [] as $li => $lead) { if ($li > 0) echo ', '; echo '<a href="' . UIR . 'Playernew/index/' . (int)$lead['MundaneId'] . '">' . htmlspecialchars($lead['Persona']) . '</a>'; } ?></td>
							<td><?= htmlspecialchars($item['Description']) ?></td>
							<?php if ($canManageSchedule): ?>
							<td class="ev-del-cell">
								<button class="ev-edit-link" title="Edit" onclick="evOpenScheduleEditModal(<?= (int)$item['EventScheduleId'] ?>, this)" style="background:none;border:none;cursor:pointer;color:#666;font-size:13px;padding:0 5px 0 0">
									<i class="fas fa-pencil-alt"></i>
								</button>
								<button class="ev-del-link" title="Remove"
									onclick="evRemoveSchedule(this, <?= (int)$item['EventScheduleId'] ?>)"
									style="background:none;border:none;cursor:pointer;color:#e53e3e;font-size:16px;padding:0">
									&times;
								</button>
							</td>
							<?php endif; ?>
						</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
			</div>
			<?php endforeach; ?>
			</div><!-- /#ev-schedule-container -->
			<div class="ev-empty" id="ev-schedule-empty"<?= empty($scheduleList) ? '' : ' style="display:none"' ?>>
				<i class="fas fa-clock" style="margin-right:6px"></i>No schedule items yet
			</div>

			</div><!-- /.ev-tab-panel (schedule) -->

			<?php // ---- Feast Tab ---- ?>
			<div class="ev-tab-panel" id="ev-tab-feast">

				<?php if ($canManageFeast): ?>
				<div style="margin-bottom:14px">
					<button type="button" class="ev-submit-btn" style="float:right" onclick="evOpenMealModal()">
						<i class="fas fa-plus"></i> Add Meal
					</button>
				</div>
				<?php endif; ?>

				<div id="ev-meal-list">
				<?php if (!empty($mealList)): ?>
				<?php foreach ($mealList as $meal): ?>
				<div class="ev-meal-card" id="ev-meal-card-<?= (int)$meal['EventMealId'] ?>">
					<div class="ev-meal-card-header">
						<span class="ev-meal-title"><i class="fas fa-utensils" style="color:#e65100;margin-right:7px"></i><?= htmlspecialchars($meal['Title']) ?></span>
						<span style="display:flex;align-items:center;gap:10px">
							<?php if ($meal['Cost'] !== null): ?>
							<span class="ev-meal-cost"><?= (float)$meal['Cost'] == 0 ? '<span style="color:#276749;font-weight:600">Free</span>' : '<span style="font-weight:600">$' . number_format((float)$meal['Cost'], 2) . '</span>' ?></span>
							<?php endif; ?>
							<?php if ($canManageFeast): ?>
							<button class="ev-edit-btn" title="Edit meal"
								onclick='evOpenEditMealModal(<?= htmlspecialchars(json_encode(["EventMealId"=>(int)$meal["EventMealId"],"Title"=>$meal["Title"],"Cost"=>$meal["Cost"],"Menu"=>$meal["Menu"]??"","Dietary"=>$meal["Dietary"]??"","Allergens"=>$meal["Allergens"]??""]), ENT_QUOTES) ?>)'>
								<i class="fas fa-pencil-alt"></i></button>
							<button class="ev-del-link" title="Remove meal" style="background:none;border:none;cursor:pointer;color:#e53e3e;font-size:18px;padding:0;line-height:1"
								onclick="evRemoveMeal(this, <?= (int)$meal['EventMealId'] ?>)">&times;</button>
							<?php endif; ?>
						</span>
					</div>
					<?php if (!empty(trim($meal['Menu'] ?? ''))): ?>
					<div class="ev-meal-menu"><?= htmlspecialchars($meal['Menu']) ?></div>
					<?php endif; ?>
					<?php
						$_mDietary   = array_filter(array_map('trim', explode(',', $meal['Dietary']   ?? '')));
						$_mAllergens = array_filter(array_map('trim', explode(',', $meal['Allergens'] ?? '')));
					?>
					<?php if (!empty($_mDietary) || !empty($_mAllergens)): ?>
					<div class="ev-meal-footer">
						<?php foreach ($_mDietary as $_tag): ?>
						<span class="ev-meal-tag ev-meal-tag-dietary"><i class="fas fa-leaf"></i><?= htmlspecialchars($_tag) ?></span>
						<?php endforeach; ?>
						<?php foreach ($_mAllergens as $_tag): ?>
						<span class="ev-meal-tag ev-meal-tag-allergen"><i class="fas fa-exclamation-triangle"></i><?= htmlspecialchars($_tag) ?></span>
						<?php endforeach; ?>
					</div>
					<?php endif; ?>
				</div>
				<?php endforeach; ?>
				<?php endif; ?>
				</div><!-- /#ev-meal-list -->

				<div class="ev-empty" id="ev-meal-empty"<?= empty($mealList) ? '' : ' style="display:none"' ?>>
					<i class="fas fa-utensils" style="margin-right:6px"></i>No meals added yet
				</div>

			</div><!-- /.ev-tab-panel (feast) -->

			<div class="ev-tab-panel" id="ev-tab-attendance">

				<?php if ($canManageAttendance): ?>
				<div class="ev-att-form">
					<h4><i class="fas fa-plus-circle" style="margin-right:6px;color:#276749"></i>Add Attendance</h4>
					<form method="post" id="ev-attendance-form" action="<?= UIR ?>EventAjax/add_attendance/<?= $eventId ?>/<?= $detailId ?>" onsubmit="evHandleAttendanceSubmit(this); return false;">
						<div class="ev-form-row">
							<div class="ev-form-field">
								<label>Player</label>
								<input type="text" id="ev-PlayerName" name="PlayerName" style="width:200px"
									value="<?= htmlspecialchars($attendanceForm['PlayerName'] ?? '') ?>"
									autocomplete="off" placeholder="Search players…">
								<input type="hidden" id="ev-MundaneId" name="MundaneId"
									value="<?= (int)($attendanceForm['MundaneId'] ?? 0) ?>">
							</div>
							<div class="ev-form-field">
								<label>Class</label>
								<select id="ev-ClassId" name="ClassId" style="width:120px">
									<option value="">— select —</option>
									<?php foreach ($Classes ?? [] as $class): ?>
									<option value="<?= (int)$class['ClassId'] ?>"
										<?= ($attendanceForm['ClassId'] ?? '') == $class['ClassId'] ? 'selected' : '' ?>>
										<?= htmlspecialchars($class['Name']) ?>
									</option>
									<?php endforeach; ?>
								</select>
							</div>
							<div class="ev-form-field">
								<label>Credits</label>
								<input type="text" id="ev-Credits" name="Credits" style="width:55px"
									value="<?= (float)($attendanceForm['Credits'] ?? $defaultCredits) ?>">
							</div>
							<div class="ev-form-field" style="justify-content:flex-end">
								<label>&nbsp;</label>
								<button type="submit" class="ev-submit-btn">
									<i class="fas fa-plus"></i> Add
								</button>
							</div>
						</div>
						<input type="hidden" id="ev-AttendanceDate" name="AttendanceDate"
							value="<?= $eventStart ? date('Y-m-d', strtotime($eventStart)) : date('Y-m-d') ?>">
					</form>
				</div>
				<?php endif; ?>

				<?php if (count($attendanceList) > 0): ?>
				<table class="display" id="ev-attendance-table" style="width:100%">
					<thead>
						<tr>
							<th>Player</th>
							<th>Kingdom</th>
							<th>Park</th>
							<th>Class</th>
							<th>Credits</th>
							<?php if ($canManageAttendance): ?>
							<th class="ev-del-cell"></th>
							<?php endif; ?>
						</tr>
					</thead>
					<tbody>
						<?php foreach ($attendanceList as $att): ?>
						<tr data-att-id="<?= (int)$att['AttendanceId'] ?>">
							<td><a href="<?= UIR ?>Player/profile/<?= (int)$att['MundaneId'] ?>"><?= htmlspecialchars($att['Persona']) ?></a></td>
							<td><?php if (!empty($att['KingdomId'])): ?><a href="<?= UIR ?>Kingdom/profile/<?= (int)$att['KingdomId'] ?>"><?= htmlspecialchars($att['KingdomName']) ?></a><?php else: ?><?= htmlspecialchars($att['KingdomName'] ?? '') ?><?php endif; ?></td>
							<td><?php if (!empty($att['ParkId'])): ?><a href="<?= UIR ?>Park/profile/<?= (int)$att['ParkId'] ?>"><?= htmlspecialchars($att['ParkName']) ?></a><?php else: ?><?= htmlspecialchars($att['ParkName'] ?? '') ?><?php endif; ?></td>
							<td><?= htmlspecialchars($att['ClassName']) ?></td>
							<td><?= htmlspecialchars($att['Credits']) ?></td>
							<?php if ($canManageAttendance): ?>
							<td class="ev-del-cell">
								<a class="ev-del-link" title="Remove" href="#"
									data-del-url="<?= UIR ?>AttendanceAjax/attendance/<?= (int)$att['AttendanceId'] ?>/delete"
									onclick="evConfirmAttDelete(event, this)">×</a>
							</td>
							<?php endif; ?>
						</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
				<?php else: ?>
				<div class="ev-empty">
					<i class="fas fa-clipboard" style="margin-right:6px"></i>No attendance recorded yet
				</div>
				<?php endif; ?>

			</div><!-- /.ev-tab-panel -->

			<?php /* [TOURNAMENTS HIDDEN] tab panel */ ?>

			<?php // ---- RSVPs Tab ---- ?>
			<div class="ev-tab-panel" id="ev-tab-rsvp">
				<p style="font-size:.95em;color:#4a5568;margin:0 0 12px">
					<i class="fas fa-users" style="margin-right:5px;color:#276749"></i>
					<strong><?= $rsvpCount ?></strong> <?= $rsvpCount === 1 ? 'RSVP' : 'RSVPs' ?>
				</p>
				<?php if ($canManageAttendance): ?>
					<?php if (count($rsvpList) > 0): ?>
					<table class="ev-table">
						<thead>
							<tr><th>Player</th><th></th></tr>
						</thead>
						<tbody>
							<?php foreach ($rsvpList as $attendee): ?>
							<tr>
								<td><a href="<?= UIR ?>Player/profile/<?= $attendee['MundaneId'] ?>"><?= htmlspecialchars($attendee['Persona']) ?></a></td>
								<td style="text-align:right;white-space:nowrap">
									<button class="ev-checkin-btn<?= isset($checkedInIds[$attendee['MundaneId']]) ? ' ev-checkin-done' : '' ?>" type="button" data-mundane="<?= (int)$attendee['MundaneId'] ?>"
										<?php if (!isset($checkedInIds[$attendee['MundaneId']])): ?>
										onclick="evOpenCheckinModal(<?= (int)$attendee['MundaneId'] ?>, <?= htmlspecialchars(json_encode($attendee['Persona']), ENT_QUOTES) ?>)"
										<?php else: ?>disabled<?php endif; ?>>
										<i class="fas fa-user-check"></i> <?= isset($checkedInIds[$attendee['MundaneId']]) ? 'Checked In' : 'Check In' ?>
									</button>
									<button class="ev-rsvp-del-btn" type="button"
										onclick="evDeleteRsvp(this, <?= (int)$attendee['MundaneId'] ?>)" title="Remove RSVP">
										<i class="fas fa-times"></i>
									</button>
								</td>
							</tr>
							<?php endforeach; ?>
						</tbody>
					</table>
					<?php else: ?>
					<div class="ev-empty">
						<i class="fas fa-calendar-check" style="margin-right:6px"></i><?php echo $isPastEvent ? 'No RSVPs' : 'No RSVPs yet' ?>
					</div>
					<?php endif; ?>
				<?php elseif ($rsvpCount === 0): ?>
				<div class="ev-empty">
					<i class="fas fa-calendar-check" style="margin-right:6px"></i><?php echo $isPastEvent ? 'No RSVPs' : 'No RSVPs yet' ?>
				</div>
				<?php endif; ?>
			</div><!-- /.ev-tab-panel -->

			<?php // ---- Staff Tab ---- ?>
			<div class="ev-tab-panel" id="ev-tab-staff">

				<?php if ($canManageStaff): ?>
				<div style="margin-bottom:14px">
					<button type="button" class="ev-submit-btn" style="float:right" onclick="evOpenStaffModal()">
						<i class="fas fa-plus"></i> Add Staff
					</button>
				</div>
				<?php endif; ?>

				<?php if (!empty($StaffList)): ?>
				<table class="ev-table" id="ev-staff-table">
					<thead>
						<tr>
							<th>Player</th>
							<th>Role</th>
							<th>Can Manage</th>
							<th>Attendance</th>
							<th>Schedule</th>
							<th>Feast</th>
							<?php if ($canManageStaff): ?><th class="ev-del-cell">&times;</th><?php endif; ?>
						</tr>
					</thead>
					<tbody id="ev-staff-tbody">
						<?php foreach ($StaffList as $staff): ?>
						<tr id="ev-staff-row-<?= (int)$staff['EventStaffId'] ?>">
							<td><a href="<?= UIR ?>Player/profile/<?= (int)$staff['MundaneId'] ?>"><?= htmlspecialchars($staff['Persona']) ?></a></td>
							<td><?= htmlspecialchars($staff['RoleName']) ?></td>
							<td><?= $staff['CanManage'] ? '<i class="fas fa-check" style="color:#276749"></i>' : '<i class="fas fa-times" style="color:#a0aec0"></i>' ?></td>
							<td><?= $staff['CanAttendance'] ? '<i class="fas fa-check" style="color:#276749"></i>' : '<i class="fas fa-times" style="color:#a0aec0"></i>' ?></td>
							<td><?= $staff['CanSchedule'] ? '<i class="fas fa-check" style="color:#276749"></i>' : '<i class="fas fa-times" style="color:#a0aec0"></i>' ?></td>
							<td><?= $staff['CanFeast'] ? '<i class="fas fa-check" style="color:#276749"></i>' : '<i class="fas fa-times" style="color:#a0aec0"></i>' ?></td>
							<?php if ($canManageStaff): ?>
							<td class="ev-del-cell">
								<button class="ev-del-link" title="Remove"
									onclick="evRemoveStaff(this, <?= (int)$staff['EventStaffId'] ?>)"
									style="background:none;border:none;cursor:pointer;color:#e53e3e;font-size:16px;padding:0">
									&times;
								</button>
							</td>
							<?php endif; ?>
						</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
				<?php else: ?>
				<div class="ev-empty" id="ev-staff-empty">
					<i class="fas fa-id-badge" style="margin-right:6px"></i>No staff assigned yet
				</div>
				<?php endif; ?>

			</div><!-- /.ev-tab-panel (staff) -->

			<?php if ($hasMapTab): ?>
			<?php
				$mapOpenUrl  = $mapLink ?: null;
				$mapQuery    = urlencode($mapQueryAddress);
				if ($mapLink && strpos($mapLink, 'q=@') !== false) {
					// lat/lng link — strip @ for embed (Google Maps embed doesn't accept @)
					$mapEmbedUrl = str_replace('?q=@', '?q=', $mapLink) . '&output=embed&z=14';
				} else {
					$mapEmbedUrl = 'https://maps.google.com/maps?q=' . $mapQuery . '&output=embed';
				}
				if (!$mapOpenUrl) $mapOpenUrl = 'https://maps.google.com/maps?q=' . $mapQuery;
			?>
			<?php // ---- Map Tab ---- ?>
			<div class="ev-tab-panel" id="ev-tab-map">
				<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
					<a href="<?= htmlspecialchars($mapOpenUrl) ?>" target="_blank" class="pk-btn pk-btn-secondary" style="font-size:13px;padding:6px 14px;text-decoration:none">
						<i class="fas fa-external-link-alt" style="margin-right:6px"></i>Open in Maps
					</a>
				</div>
				<div style="width:100%;border-radius:8px;overflow:hidden;border:1px solid #e2e8f0">
					<iframe
						src="<?= htmlspecialchars($mapEmbedUrl) ?>"
						width="100%"
						height="400"
						style="border:0;display:block"
						allowfullscreen=""
						loading="lazy"
						referrerpolicy="no-referrer-when-downgrade"
					></iframe>
				</div>
			</div><!-- /.ev-tab-panel -->
			<?php endif; ?>

			<?php if ($canManage): ?>
			<div class="ev-tab-panel" id="ev-tab-admin">
				<ul style="margin:0;padding:0;list-style:none;display:flex;flex-wrap:wrap;gap:8px">
					<li>
						<a href="<?= UIR ?>Admin/permissions/Event/<?= $eventId ?>/<?= $detailId ?>" style="display:inline-flex;align-items:center;gap:7px;padding:7px 14px;background:#f0faf4;border:1px solid #c6e8d4;border-radius:6px;font-size:13px;font-weight:600;color:#276749;text-decoration:none">
							<i class="fas fa-key"></i> Roles &amp; Permissions
						</a>
					</li>
				</ul>
			</div><!-- /.ev-tab-panel -->
			<?php endif; ?>

		</div><!-- /.ev-tabs -->
	</div><!-- /.ev-main -->

</div><!-- /.ev-layout -->

<?php if ($CanManageEvent ?? false): ?>
<div class="ev-modal-overlay" id="ev-edit-modal">
	<div class="ev-modal">
		<div class="ev-modal-header">
			<h3><i class="fas fa-pencil-alt" style="margin-right:8px"></i>Edit Event Details</h3>
			<button class="ev-modal-close" type="button" onclick="evCloseEditModal()">&times;</button>
		</div>
		<form method="post" id="ev-edit-form" action="<?= UIR ?>Event/detail/<?= $eventId ?>/<?= $detailId ?>/edit">
			<div class="ev-modal-body">

				<?php if ($isPastEvent): ?>
				<div class="ev-modal-warning-box">
					<i class="fas fa-exclamation-triangle" style="margin-right:6px;flex-shrink:0;margin-top:2px"></i>
					<span><strong>Stop!</strong> You are editing a past event. This can impact data for the event including attendance credit assignment. Use caution before proceeding.</span>
				</div>
				<?php endif; ?>

				<div class="ev-modal-section">
					<h4>Event Name</h4>
					<div class="ev-modal-row">
						<div class="ev-modal-field ev-field-full">
							<label>Name</label>
							<input type="text" name="EventName" value="<?= htmlspecialchars($info['Name'] ?? '') ?>" required>
						</div>
					</div>
				</div>

				<div class="ev-modal-section">
					<h4>Dates</h4>
					<div class="ev-modal-row">
						<div class="ev-modal-field">
							<label>Start Date &amp; Time</label>
							<input type="text" name="StartDate" id="ev-fp-start" autocomplete="off"
								value="<?php $sTs = $eventStart ? strtotime($eventStart) : 0; echo ($sTs > 0) ? date('Y-m-d\TH:i', $sTs) : ''; ?>">
						</div>
						<div class="ev-modal-field">
							<label>End Date &amp; Time</label>
							<input type="text" name="EndDate" id="ev-fp-end" autocomplete="off"
								value="<?php $eTs = $eventEnd ? strtotime($eventEnd) : 0; echo ($eTs > 0) ? date('Y-m-d\TH:i', $eTs) : ''; ?>">
						</div>
					</div>
				</div>

				<div class="ev-modal-section" id="ev-fees-section">
					<h4>Admission &amp; Fees</h4>
					<div id="ev-fees-list" style="margin-bottom:8px"></div>
					<button type="button" onclick="evFeesAdd()" style="background:#ebf8ff;border:1px solid #90cdf4;color:#2b6cb0;border-radius:4px;padding:4px 10px;font-size:12px;cursor:pointer">
						<i class="fas fa-plus"></i> Add Fee
					</button>
					<input type="hidden" name="Fees" id="ev-fees-json">
				</div>

				<div class="ev-modal-section">
					<h4>Description</h4>
					<div class="ev-modal-row">
						<div class="ev-modal-field ev-field-full">
							<label>Description</label>
							<textarea name="Description" rows="5"><?= htmlspecialchars(rawurldecode($description)) ?></textarea>
						</div>
					</div>
				</div>

				<div class="ev-modal-section">
					<h4>Website Link</h4>
					<div class="ev-modal-row">
						<div class="ev-modal-field">
							<label>URL</label>
							<input type="text" name="Url"
								value="<?= htmlspecialchars($websiteUrl) ?>" placeholder="https://…">
						</div>
						<div class="ev-modal-field">
							<label>Link Text</label>
							<input type="text" name="UrlName"
								value="<?= htmlspecialchars($websiteName) ?>" placeholder="Event Website">
						</div>
					</div>
				</div>

				<div class="ev-modal-section">
					<h4>Location</h4>
					<?php if ($parkId > 0 || $atParkId > 0): ?>
					<div class="ev-modal-info-box"><i class="fas fa-info-circle"></i> If no address is provided, the park address will be used.</div>
					<?php endif; ?>
					<div class="ev-modal-row">
						<div class="ev-modal-field ev-field-full">
							<label>Address</label>
							<input type="text" name="Address"
								value="<?= htmlspecialchars($cd['Address'] ?? '') ?>">
						</div>
					</div>
					<div class="ev-modal-row">
						<div class="ev-modal-field">
							<label>City</label>
							<input type="text" name="City" value="<?= htmlspecialchars($city) ?>">
						</div>
						<div class="ev-modal-field">
							<label>Province / State</label>
							<input type="text" name="Province" value="<?= htmlspecialchars($province) ?>">
						</div>
						<div class="ev-modal-field" style="max-width:120px">
							<label>Postal Code</label>
							<input type="text" name="PostalCode"
								value="<?= htmlspecialchars($cd['PostalCode'] ?? '') ?>">
						</div>
						<div class="ev-modal-field" style="max-width:120px">
							<label>Country</label>
							<input type="text" name="Country" value="<?= htmlspecialchars($country) ?>">
						</div>
					</div>
				</div>

				<div class="ev-modal-section">
					<h4>Map Link</h4>
					<div class="ev-modal-row">
						<div class="ev-modal-field">
							<label>Map URL</label>
							<input type="text" name="MapUrl"
								value="<?= htmlspecialchars($mapUrl) ?>" placeholder="https://maps.google.com/…">
						</div>
						<div class="ev-modal-field">
							<label>Map Link Text</label>
							<input type="text" name="MapUrlName"
								value="<?= htmlspecialchars($mapUrlName) ?>" placeholder="Campsite Map">
						</div>
					</div>
				</div>

			</div><!-- /.ev-modal-body -->
		</form>
		<div class="ev-modal-footer" style="justify-content:space-between;align-items:center;display:flex">
			<div>
<?php if ($canDelete): ?>
				<form method="post" action="<?= UIR ?>Event/detail/<?= $eventId ?>/<?= $detailId ?>/deletedetail" style="margin:0" onsubmit="evConfirmDeleteOccurrence(event, this)">
					<button type="submit" class="ev-modal-btn-delete">
						<i class="fas fa-trash-alt" style="margin-right:5px"></i>Delete Occurrence
					</button>
				</form>
<?php else: ?>
				<span class="ev-del-detail-wrap" onmouseenter="evPositionDelTooltip(this)" onmouseleave="">
					<button type="button" class="ev-modal-btn-delete ev-modal-btn-delete-disabled" disabled>
						<i class="fas fa-trash-alt" style="margin-right:5px"></i>Delete Occurrence
					</button>
					<span class="ev-del-detail-tooltip">You cannot delete an event that has associated attendance or RSVP data.</span>
				</span>
<?php endif; ?>
			</div>
			<div style="display:flex;gap:8px">
				<button type="button" class="ev-modal-btn-cancel" onclick="evCloseEditModal()">Cancel</button>
				<button type="submit" form="ev-edit-form" class="ev-modal-btn-save">
					<i class="fas fa-save" style="margin-right:5px"></i>Save Changes
				</button>
			</div>
		</div>
	</div>
</div><!-- /.ev-edit-modal -->

<div class="ev-modal-overlay" id="ev-checkin-modal">
	<div class="ev-modal">
		<div class="ev-modal-header">
			<h3><i class="fas fa-user-check" style="margin-right:8px"></i>Check In <span id="ev-checkin-name"></span></h3>
			<button class="ev-modal-close" type="button" onclick="evCloseCheckinModal()">&times;</button>
		</div>
		<form id="ev-checkin-form"
			action="<?= UIR ?>EventAjax/add_attendance/<?= $eventId ?>/<?= $detailId ?>"
			onsubmit="evHandleCheckinSubmit(this); return false;">
			<input type="hidden" name="MundaneId" id="ev-checkin-mundane-id">
			<input type="hidden" name="AttendanceDate" value="<?= date('Y-m-d') ?>">
			<div class="ev-modal-body">
				<div class="ev-modal-row">
					<div class="ev-modal-field">
						<label>Class</label>
						<select name="ClassId">
							<?php foreach ($Classes ?? [] as $class): ?>
							<option value="<?= (int)$class['ClassId'] ?>"><?= htmlspecialchars($class['Name']) ?></option>
							<?php endforeach; ?>
						</select>
					</div>
					<div class="ev-modal-field" style="max-width:100px">
						<label>Credits</label>
						<input type="number" name="Credits" value="1" min="0.25" step="0.25">
					</div>
				</div>
			</div>
			<div class="ev-modal-footer">
				<button type="button" class="ev-modal-btn-cancel" onclick="evCloseCheckinModal()">Cancel</button>
				<button type="submit" class="ev-modal-btn-save">
					<i class="fas fa-user-check" style="margin-right:5px"></i>Check In
				</button>
			</div>
		</form>
	</div>
</div><!-- /.ev-checkin-modal -->
<?php endif; ?>

<script>
function evPositionDelTooltip(wrap) {
	var btn = wrap.querySelector('button');
	var tip = wrap.querySelector('.ev-del-detail-tooltip');
	if (!btn || !tip) return;
	var r = btn.getBoundingClientRect();
	tip.style.left = r.left + 'px';
	tip.style.top  = (r.top + window.scrollY) + 'px';
}

var EvConfig = {
	uir:        '<?= UIR ?>',
	httpService:'<?= HTTP_SERVICE ?>',
	canManage:         <?= !empty($canManage) ? 'true' : 'false' ?>,
	canManageSchedule: <?= !empty($canManageSchedule) ? 'true' : 'false' ?>,
	canManageFeast:    <?= !empty($canManageFeast) ? 'true' : 'false' ?>,
	canManageStaff:    <?= !empty($canManageStaff) ? 'true' : 'false' ?>,
	kingdomId:  <?= $kingdomId ?>,
	eventId:    <?= $eventId ?>,
	detailId:   <?= $detailId ?>,
	eventStart: '<?= $eventStart ? date('Y-m-d\TH:i', strtotime($eventStart)) : '' ?>',
	eventEnd:   '<?= $eventEnd   ? date('Y-m-d\TH:i', strtotime($eventEnd))   : '' ?>',
	staffList:  <?= json_encode(array_map(function($s) { return ['MundaneId' => (int)$s['MundaneId'], 'Persona' => $s['Persona']]; }, $StaffList ?? [])) ?>,
	hasFees:    true,
	fees:       <?= json_encode(array_map(function($f) { return ['AdmissionType' => $f['AdmissionType'], 'Cost' => (float)$f['Cost']]; }, $eventFees)) ?>
};
</script>
<?php if ($canManageStaff): ?>
<!-- Staff Modal -->
<div class="ev-modal-overlay" id="ev-staff-modal">
	<div class="ev-modal">
		<div class="ev-modal-header">
			<h3><i class="fas fa-id-badge" style="margin-right:8px"></i>Add Staff Member</h3>
			<button class="ev-modal-close" type="button" onclick="evCloseStaffModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Role</label>
					<input type="text" id="ev-staff-role" placeholder="Autocrat, Gate Staff, etc..." autocomplete="off" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full" style="position:relative">
					<label>Player</label>
					<input type="text" id="ev-staff-player-name" placeholder="Search players..." autocomplete="off" style="width:100%">
					<input type="hidden" id="ev-staff-player-id">
					<div id="ev-staff-ac" class="ev-ac-results" style="display:none"></div>
				</div>
			</div>
			<div class="ev-modal-row" style="margin-top:12px">
				<div class="ev-modal-field">
					<label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-weight:normal">
						<input type="checkbox" id="ev-staff-can-manage" style="width:auto;margin:0">
						Can manage event details
					</label>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field">
					<label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-weight:normal">
						<input type="checkbox" id="ev-staff-can-attendance" style="width:auto;margin:0">
						Can manage attendance
					</label>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field">
					<label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-weight:normal">
						<input type="checkbox" id="ev-staff-can-schedule" style="width:auto;margin:0">
						Can manage schedule
					</label>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field">
					<label style="display:flex;align-items:center;gap:8px;cursor:pointer;font-weight:normal">
						<input type="checkbox" id="ev-staff-can-feast" style="width:auto;margin:0">
						Can manage feast
					</label>
				</div>
			</div>
			<div id="ev-staff-error" class="ev-img-form-error" style="display:none;margin-top:10px"></div>
		</div><!-- /.ev-modal-body -->
		<div class="ev-modal-footer">
			<button type="button" class="ev-modal-btn-cancel" onclick="evCloseStaffModal()">Cancel</button>
			<button type="button" class="ev-modal-btn-save" id="ev-staff-save-btn" onclick="evSubmitStaff()">
				<i class="fas fa-plus" style="margin-right:5px"></i>Add Staff
			</button>
		</div>
	</div>
</div><!-- /.ev-staff-modal -->
<?php endif; ?>

<?php if ($canManage): ?>
<!-- Event Heraldry Upload Modal -->
<div class="ev-img-overlay" id="ev-img-overlay">
	<div class="ev-img-modal">
		<div class="ev-img-modal-header">
			<span class="ev-img-modal-title"><i class="fas fa-image" style="margin-right:8px;color:#2c5282"></i>Update Event Heraldry</span>
			<button class="ev-img-close-btn" id="ev-img-close-btn" aria-label="Close">&times;</button>
		</div>
		<div class="ev-img-modal-body" id="ev-img-step-select">
			<label class="ev-upload-area" for="ev-img-file-input">
				<i class="fas fa-cloud-upload-alt ev-upload-icon"></i>
				Click to choose an image
				<small>JPG, GIF, PNG &middot; Max 340&nbsp;KB (larger images auto-resized)</small>
			</label>
			<input type="file" id="ev-img-file-input" accept=".jpg,.jpeg,.gif,.png,image/jpeg,image/gif,image/png" style="display:none;" />
			<div id="ev-img-resize-notice" style="font-size:12px;color:#888;min-height:16px;margin-top:6px;"></div>
			<div class="ev-img-form-error" id="ev-img-error" style="display:none;"></div>
			<div style="text-align:center;margin-top:10px">
				<button class="ev-btn ev-btn-outline" id="ev-img-remove-btn" type="button" style="font-size:12px;padding:4px 14px;border-color:#feb2b2;color:#e53e3e;"><i class="fas fa-trash"></i> Remove Heraldry</button>
			</div>
		</div>
		<div class="ev-img-modal-body" id="ev-img-step-crop" style="display:none;">
			<p style="margin:0 0 10px;font-size:13px;color:#718096;">Drag inside the crop box to reposition it, or drag the corner handles to resize.</p>
			<div class="ev-crop-wrap"><canvas id="ev-img-canvas"></canvas></div>
			<div class="ev-img-step-actions">
				<button class="ev-btn ev-btn-outline" id="ev-img-back-btn"><i class="fas fa-arrow-left"></i> Choose Different</button>
				<button class="ev-btn ev-btn-white" id="ev-img-upload-btn"><i class="fas fa-upload"></i> Upload</button>
			</div>
		</div>
		<div class="ev-img-modal-body" id="ev-img-step-uploading" style="display:none;text-align:center;padding:40px 20px;">
			<i class="fas fa-spinner fa-spin" style="font-size:32px;color:#4299e1;"></i>
			<p style="margin-top:12px;color:#718096;">Uploading&hellip;</p>
		</div>
		<div class="ev-img-modal-body" id="ev-img-step-success" style="display:none;text-align:center;padding:40px 20px;">
			<i class="fas fa-check-circle" style="font-size:32px;color:#48bb78;"></i>
			<p style="margin-top:12px;color:#48bb78;font-weight:600;">Updated! Refreshing&hellip;</p>
		</div>
	</div>
</div>
<?php endif; ?>
<?php if ($canManageFeast): ?>
<!-- Feast Meal Modal -->
<div class="ev-modal-overlay" id="ev-meal-modal">
	<div class="ev-modal">
		<div class="ev-modal-header">
			<h3><i class="fas fa-utensils" style="margin-right:8px;color:#e65100"></i>Add Meal</h3>
			<button class="ev-modal-close" type="button" onclick="evCloseMealModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Title <span style="color:#e53e3e">*</span></label>
					<input type="text" id="ev-meal-title" placeholder="Evening Feast, Potluck Lunch, etc." autocomplete="off" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field" style="max-width:160px">
					<label>Cost <span style="font-size:11px;color:#718096;font-weight:400">(optional)</span></label>
					<input type="number" id="ev-meal-cost" min="0" step="0.01" placeholder="0.00" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Menu <span style="font-size:11px;color:#718096;font-weight:400">(optional)</span></label>
					<textarea id="ev-meal-menu" rows="5" placeholder="List dishes, courses, dietary notes..." style="width:100%;resize:vertical"></textarea>
				</div>
			</div>
				<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label style="margin-bottom:6px;display:block">Dietary <span style="font-size:11px;color:#718096;font-weight:400">(optional)</span></label>
					<div class="ev-meal-cb-group">
						<label><input type="checkbox" class="ev-meal-dietary-cb" value="Vegetarian Option"> Vegetarian Option</label>
						<label><input type="checkbox" class="ev-meal-dietary-cb" value="Vegan Option"> Vegan Option</label>
						<label><input type="checkbox" class="ev-meal-dietary-cb" value="Kosher"> Kosher</label>
						<label><input type="checkbox" class="ev-meal-dietary-cb" value="Halal"> Halal</label>
					</div>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label style="margin-bottom:6px;display:block">Contains Allergens <span style="font-size:11px;color:#718096;font-weight:400">(optional)</span></label>
					<div class="ev-meal-cb-group">
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Dairy"> Dairy</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Eggs"> Eggs</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Fish"> Fish</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Shellfish"> Shellfish</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Tree Nuts"> Tree Nuts</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Peanuts"> Peanuts</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Wheat"> Wheat</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Soy"> Soy</label>
						<label><input type="checkbox" class="ev-meal-allergen-cb" value="Sesame"> Sesame</label>
					</div>
				</div>
			</div>
		<div class="ev-modal-error" id="ev-meal-error" style="display:none"></div>
		</div>
		<div class="ev-modal-footer">
			<button class="ev-btn ev-btn-outline" type="button" onclick="evCloseMealModal()">Cancel</button>
			<button class="ev-submit-btn" type="button" id="ev-meal-save-btn" onclick="evSubmitMeal()">
				<i class="fas fa-save"></i> Save Meal
			</button>
		</div>
	</div>
</div>
<?php endif; ?>
<?php if ($canManageSchedule): ?>
<!-- Schedule Modal -->
<div class="ev-modal-overlay" id="ev-schedule-modal">
	<div class="ev-modal">
		<div class="ev-modal-header">
			<h3><i class="fas fa-clock" style="margin-right:8px"></i><span id="ev-sched-modal-title">Add Schedule Item</span></h3>
			<button class="ev-modal-close" type="button" onclick="evCloseScheduleModal()">&times;</button>
		</div>
		<div class="ev-modal-body">
			<div class="ev-modal-row">
				<div class="ev-modal-field">
					<label>Category</label>
					<select id="ev-sched-category" style="width:100%">
						<option value="Administrative">Administrative</option>
						<option value="Tournament">Tournament</option>
						<option value="Battlegame">Battlegame</option>
						<option value="Arts and Sciences">Arts and Sciences</option>
						<option value="Class">Class</option>
						<option value="Feast and Food">Feast and Food</option>
						<option value="Court">Court</option>
						<option value="Other" selected>Other</option>
					</select>
				</div>
				<div class="ev-modal-field">
					<label>Title <span style="color:#e53e3e">*</span></label>
					<input type="text" id="ev-sched-title" placeholder="Evening Feast, Battlegame, etc." autocomplete="off" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field">
					<label>Start Time <span style="color:#e53e3e">*</span></label>
					<input type="datetime-local" id="ev-sched-start" style="width:100%">
				</div>
				<div class="ev-modal-field">
					<label>End Time <span style="color:#e53e3e">*</span></label>
					<input type="datetime-local" id="ev-sched-end" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Location</label>
					<input type="text" id="ev-sched-location" placeholder="Main field, Feast hall, etc." autocomplete="off" style="width:100%">
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Item Lead(s)</label>
					<div id="ev-sched-leads-list" style="display:flex;flex-wrap:wrap;gap:6px;min-height:26px;margin-bottom:8px;align-items:center"></div>
					<div style="position:relative">
						<input type="text" id="ev-sched-lead-input" placeholder="Search players to add as lead..." autocomplete="off" style="width:100%">
						<div id="ev-sched-lead-ac" class="kn-ac-results" style="display:none"></div>
					</div>
				</div>
			</div>
			<div class="ev-modal-row" id="ev-sched-staff-quickadd-row" style="display:none">
				<div class="ev-modal-field ev-field-full">
					<button type="button" onclick="evToggleStaffQuickAdd()" style="background:none;border:none;cursor:pointer;color:#4a5568;font-size:12px;padding:0;display:flex;align-items:center;gap:5px;margin-bottom:6px">
						<i id="ev-sched-staff-qa-chevron" class="fas fa-chevron-right" style="font-size:10px;transition:transform .15s"></i>
						<span>Add from Event Staff</span>
					</button>
					<div id="ev-sched-staff-qa-list" style="display:none;border:1px solid #e2e8f0;border-radius:6px;overflow:hidden;max-height:160px;overflow-y:auto"></div>
				</div>
			</div>
			<div class="ev-modal-row">
				<div class="ev-modal-field ev-field-full">
					<label>Description</label>
					<textarea id="ev-sched-description" rows="3" placeholder="Optional details..." style="width:100%;resize:vertical"></textarea>
				</div>
			</div>
			<div class="ev-modal-error" id="ev-sched-error" style="display:none"></div>
		</div>
		<div class="ev-modal-footer">
			<button class="ev-btn ev-btn-outline" type="button" onclick="evCloseScheduleModal()">Cancel</button>
			<input type="hidden" id="ev-sched-mode" value="add">
			<input type="hidden" id="ev-sched-id" value="">
			<button class="ev-submit-btn" type="button" id="ev-sched-save-btn" onclick="evSubmitSchedule()">
				<i class="fas fa-save"></i> <span id="ev-sched-save-label">Save</span>
			</button>
		</div>
	</div>
</div>
<?php endif; ?>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/script/revised.js?v=<?= filemtime(__DIR__ . '/script/revised.js') ?>"></script>
<script>
(function() {
    var hash = location.hash.replace('#', '');
    if (hash) {
        var li = document.querySelector('[data-tab="' + hash + '"]');
        if (li && typeof evShowTab === 'function') evShowTab(li, hash);
    }
})();
<?php if (count($attendanceList) > 0): ?>
$(function() {
	$('#ev-attendance-table').DataTable({
		dom: 'lfrtip',
		order: [[0, 'asc']],
		columnDefs: [
<?php if ($canManageAttendance): ?>
			{ targets: [-1], orderable: false, searchable: false }
<?php endif; ?>
		],
		pageLength: 25
	});
});
<?php endif; ?>
<?php if ($canManage && ($CalendarDetailCount ?? 1) > 1): ?>
(function() {
	var form = document.getElementById('ev-edit-form');
	if (!form) return;
	var originalName = <?= json_encode($info['Name'] ?? '') ?>;
	var detailCount  = <?= (int)($CalendarDetailCount ?? 1) ?>;
	form.addEventListener('submit', function(e) {
		var newName = (form.querySelector('[name="EventName"]') || {}).value || '';
		if (newName && newName !== originalName) {
			e.preventDefault();
			pnConfirm({
				title: 'Rename Event?',
				message: 'This event has ' + detailCount + ' scheduled dates. Renaming it will update the name for all ' + detailCount + ' occurrences.',
				confirmText: 'Rename',
				danger: true
			}, function() { form.submit(); });
		}
	});
})();
<?php endif; ?>

function evConfirmAttDelete(e, link) {
	e.preventDefault();
	var url = link.dataset.delUrl;
	if (!url) return;
	pnConfirm({ title: 'Remove Attendance?', message: 'Remove this attendance record? This cannot be undone.', confirmText: 'Remove', danger: true }, function() {
		link.textContent = '…';
		fetch(url, { method: 'POST' })
			.then(function(r) { return r.json(); })
			.then(function(data) {
				if (data.status === 0) {
					var row = link.closest('tr');
					if (row) row.remove();
					var tabCount = document.querySelector('[data-tab="ev-tab-attendance"] .ev-tab-count');
					if (tabCount) { tabCount.textContent = Math.max(0, parseInt(tabCount.textContent || '0') - 1); }
				} else {
					link.textContent = '×';
					alert(data.error || 'Could not remove attendance.');
				}
			})
			.catch(function() { link.textContent = '×'; alert('Request failed.'); });
	});
}
function evConfirmDeleteOccurrence(e, form) {
	e.preventDefault();
	pnConfirm({ title: 'Delete Occurrence?', message: 'Delete this event occurrence? This cannot be undone.', confirmText: 'Delete', danger: true }, function() {
		form.submit();
	});
}

// Flatpickr for event edit modal date fields
function fpAddTitle(label, calEl) {
	var title = document.createElement('div');
	title.className = 'ev-fp-title';
	title.textContent = label;
	calEl.insertBefore(title, calEl.firstChild);
}
var _fpOpts = {
	enableTime: true,
	dateFormat: 'Y-m-d\\TH:i',
	altInput: true,
	altFormat: 'F j, Y  h:i K',
	minuteIncrement: 10,
	time_24hr: false
};
var _prevStartDate = null;
var _fpStart = flatpickr('#ev-fp-start', Object.assign({}, _fpOpts, {
	onReady: function(sel, str, fp) {
		fpAddTitle('Start Date & Time', fp.calendarContainer);
		_prevStartDate = sel[0] || null;
	},
	onChange: function(sel) {
		if (!sel[0]) return;
		var endDates = _fpEnd.selectedDates;
		if (endDates[0] && _prevStartDate) {
			var offset = endDates[0].getTime() - _prevStartDate.getTime();
			_fpEnd.setDate(new Date(sel[0].getTime() + offset), true);
		} else if (!endDates[0]) {
			_fpEnd.setDate(new Date(sel[0].getTime() + 60 * 60 * 1000), true);
		}
		_prevStartDate = sel[0];
	}
}));
var _fpEnd = flatpickr('#ev-fp-end', Object.assign({}, _fpOpts, {
	onReady: function(sel, str, fp) { fpAddTitle('End Date & Time', fp.calendarContainer); }
}));

<?php if ($canManageFeast): ?>
var _evEditingMealId = null;
function evOpenMealModal() {
	_evEditingMealId = null;
	document.querySelector('#ev-meal-modal .ev-modal-header h3').innerHTML = '<i class="fas fa-utensils" style="margin-right:8px;color:#e65100"></i>Add Meal';
	document.getElementById('ev-meal-title').value = '';
	document.getElementById('ev-meal-cost').value = '';
	document.getElementById('ev-meal-menu').value = '';
	document.querySelectorAll('.ev-meal-dietary-cb, .ev-meal-allergen-cb').forEach(function(cb) { cb.checked = false; });
	var err = document.getElementById('ev-meal-error');
	if (err) { err.style.display = 'none'; err.textContent = ''; }
	document.getElementById('ev-meal-modal').classList.add('ev-modal-open');
	document.body.style.overflow = 'hidden';
}
function evOpenEditMealModal(meal) {
	_evEditingMealId = meal.EventMealId;
	document.querySelector('#ev-meal-modal .ev-modal-header h3').innerHTML = '<i class="fas fa-utensils" style="margin-right:8px;color:#e65100"></i>Edit Meal';
	document.getElementById('ev-meal-title').value = meal.Title || '';
	document.getElementById('ev-meal-cost').value  = meal.Cost !== null && meal.Cost !== undefined ? meal.Cost : '';
	document.getElementById('ev-meal-menu').value  = meal.Menu || '';
	var dietary   = (meal.Dietary   || '').split(',').map(function(s){return s.trim();});
	var allergens = (meal.Allergens || '').split(',').map(function(s){return s.trim();});
	document.querySelectorAll('.ev-meal-dietary-cb').forEach(function(cb)  { cb.checked = dietary.indexOf(cb.value)   >= 0; });
	document.querySelectorAll('.ev-meal-allergen-cb').forEach(function(cb) { cb.checked = allergens.indexOf(cb.value) >= 0; });
	var err = document.getElementById('ev-meal-error');
	if (err) { err.style.display = 'none'; err.textContent = ''; }
	document.getElementById('ev-meal-modal').classList.add('ev-modal-open');
	document.body.style.overflow = 'hidden';
}
function evCloseMealModal() {
	document.getElementById('ev-meal-modal').classList.remove('ev-modal-open');
	document.body.style.overflow = '';
}
document.getElementById('ev-meal-modal').addEventListener('click', function(e) {
	if (e.target === this) evCloseMealModal();
});
function evSubmitMeal() {
	var title = document.getElementById('ev-meal-title').value.trim();
	var cost  = document.getElementById('ev-meal-cost').value.trim();
	var menu  = document.getElementById('ev-meal-menu').value.trim();
	var err   = document.getElementById('ev-meal-error');
	err.style.display = 'none'; err.textContent = '';

	if (!title) { err.textContent = 'A title is required.'; err.style.display = 'block'; return; }

	var btn = document.getElementById('ev-meal-save-btn');
	btn.disabled = true;

	var dietary   = Array.from(document.querySelectorAll('.ev-meal-dietary-cb:checked')).map(function(c) { return c.value; }).join(',');
	var allergens = Array.from(document.querySelectorAll('.ev-meal-allergen-cb:checked')).map(function(c) { return c.value; }).join(',');
	var fd = new FormData();
	fd.append('Title', title);
	if (cost !== '') fd.append('Cost', cost);
	fd.append('Menu', menu);
	fd.append('Dietary',   dietary);
	fd.append('Allergens', allergens);

	var url = _evEditingMealId
		? EvConfig.uir + 'EventAjax/edit_meal/' + EvConfig.eventId + '/' + EvConfig.detailId
		: EvConfig.uir + 'EventAjax/add_meal/'  + EvConfig.eventId + '/' + EvConfig.detailId;
	if (_evEditingMealId) fd.append('MealId', _evEditingMealId);
	fetch(url, { method: 'POST', body: fd })
	.then(function(r) { return r.json(); })
	.then(function(data) {
		btn.disabled = false;
		if (data.status !== 0) { err.textContent = data.error || 'Error saving meal.'; err.style.display = 'block'; return; }
		evCloseMealModal();
		if (_evEditingMealId) {
			evReplaceMealCard(_evEditingMealId, data.meal);
		} else {
			evAppendMealCard(data.meal);
			document.getElementById('ev-meal-empty').style.display = 'none';
			var tab = document.querySelector('[data-tab="ev-tab-feast"] .ev-tab-count');
			if (tab) tab.textContent = parseInt(tab.textContent || '0') + 1;
		}
	})
	.catch(function() { btn.disabled = false; err.textContent = 'Network error.'; err.style.display = 'block'; });
}
function evAppendMealCard(meal) {
	var costHtml = '';
	if (meal.Cost !== null && meal.Cost !== undefined) {
		costHtml = '<span class="ev-meal-cost">' + (parseFloat(meal.Cost) === 0
			? '<span style="color:#276749;font-weight:600">Free</span>'
			: '<span style="font-weight:600">$' + parseFloat(meal.Cost).toFixed(2) + '</span>') + '</span>';
	}
	var menuHtml = meal.Menu ? '<div class="ev-meal-menu">' + meal.Menu.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</div>' : '';
	var editBtn = '<button class="ev-edit-btn" title="Edit meal" onclick="evOpenEditMealModal(' + JSON.stringify(meal).replace(/"/g, '&quot;') + ')"><i class="fas fa-pencil-alt"></i></button>';
	var delBtn  = '<button class="ev-del-link" title="Remove meal" style="background:none;border:none;cursor:pointer;color:#e53e3e;font-size:18px;padding:0;line-height:1" onclick="evRemoveMeal(this,' + meal.EventMealId + ')">&times;</button>';
	var footerHtml = '';
	var dietaryArr  = meal.Dietary   ? meal.Dietary.split(',').map(function(s){return s.trim();}).filter(Boolean) : [];
	var allergenArr = meal.Allergens ? meal.Allergens.split(',').map(function(s){return s.trim();}).filter(Boolean) : [];
	if (dietaryArr.length || allergenArr.length) {
		var tags = dietaryArr.map(function(s) { return '<span class="ev-meal-tag ev-meal-tag-dietary"><i class="fas fa-leaf"></i>' + s.replace(/&/g,'&amp;') + '</span>'; })
			.concat(allergenArr.map(function(s) { return '<span class="ev-meal-tag ev-meal-tag-allergen"><i class="fas fa-exclamation-triangle"></i>' + s.replace(/&/g,'&amp;') + '</span>'; }));
		footerHtml = '<div class="ev-meal-footer">' + tags.join('') + '</div>';
	}
	var html = '<div class="ev-meal-card" id="ev-meal-card-' + meal.EventMealId + '">'
		+ '<div class="ev-meal-card-header">'
		+ '<span class="ev-meal-title"><i class="fas fa-utensils" style="color:#e65100;margin-right:7px"></i>' + meal.Title.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</span>'
		+ '<span style="display:flex;align-items:center;gap:10px">' + costHtml + editBtn + delBtn + '</span>'
		+ '</div>' + menuHtml + footerHtml + '</div>';
	document.getElementById('ev-meal-list').insertAdjacentHTML('beforeend', html);
}
function evReplaceMealCard(mealId, meal) {
	var old = document.getElementById('ev-meal-card-' + mealId);
	if (!old) return;
	var tmp = document.createElement('div');
	var costHtml = '';
	if (meal.Cost !== null && meal.Cost !== undefined) {
		costHtml = '<span class="ev-meal-cost">' + (parseFloat(meal.Cost) === 0
			? '<span style="color:#276749;font-weight:600">Free</span>'
			: '<span style="font-weight:600">$' + parseFloat(meal.Cost).toFixed(2) + '</span>') + '</span>';
	}
	var menuHtml = meal.Menu ? '<div class="ev-meal-menu">' + meal.Menu.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</div>' : '';
	var editBtn  = '<button class="ev-edit-btn" title="Edit meal" onclick="evOpenEditMealModal(' + JSON.stringify(meal).replace(/"/g, '&quot;') + ')"><i class="fas fa-pencil-alt"></i></button>';
	var delBtn   = '<button class="ev-del-link" title="Remove meal" style="background:none;border:none;cursor:pointer;color:#e53e3e;font-size:18px;padding:0;line-height:1" onclick="evRemoveMeal(this,' + meal.EventMealId + ')">&times;</button>';
	var footerHtml = '';
	var dietaryArr  = meal.Dietary   ? meal.Dietary.split(',').map(function(s){return s.trim();}).filter(Boolean) : [];
	var allergenArr = meal.Allergens ? meal.Allergens.split(',').map(function(s){return s.trim();}).filter(Boolean) : [];
	if (dietaryArr.length || allergenArr.length) {
		var tags = dietaryArr.map(function(s) { return '<span class="ev-meal-tag ev-meal-tag-dietary"><i class="fas fa-leaf"></i>' + s.replace(/&/g,'&amp;') + '</span>'; })
			.concat(allergenArr.map(function(s) { return '<span class="ev-meal-tag ev-meal-tag-allergen"><i class="fas fa-exclamation-triangle"></i>' + s.replace(/&/g,'&amp;') + '</span>'; }));
		footerHtml = '<div class="ev-meal-footer">' + tags.join('') + '</div>';
	}
	var html = '<div class="ev-meal-card" id="ev-meal-card-' + meal.EventMealId + '">'
		+ '<div class="ev-meal-card-header">'
		+ '<span class="ev-meal-title"><i class="fas fa-utensils" style="color:#e65100;margin-right:7px"></i>' + meal.Title.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;') + '</span>'
		+ '<span style="display:flex;align-items:center;gap:10px">' + costHtml + editBtn + delBtn + '</span>'
		+ '</div>' + menuHtml + footerHtml + '</div>';
	tmp.innerHTML = html;
	old.parentNode.replaceChild(tmp.firstChild, old);
}
function evRemoveMeal(btn, mealId) {
	pnConfirm({ title: 'Remove Meal?', message: 'Remove this meal from the event?', confirmText: 'Remove', danger: true }, function() {
		btn.disabled = true;
		var fd = new FormData();
		fd.append('MealId', mealId);
		fetch(EvConfig.uir + 'EventAjax/remove_meal/' + EvConfig.eventId + '/' + EvConfig.detailId, {
			method: 'POST', body: fd
		})
		.then(function(r) { return r.json(); })
		.then(function(data) {
			if (data.status !== 0) { btn.disabled = false; return; }
			var card = document.getElementById('ev-meal-card-' + mealId);
			if (card) card.remove();
			var tab = document.querySelector('[data-tab="ev-tab-feast"] .ev-tab-count');
			if (tab) tab.textContent = Math.max(0, parseInt(tab.textContent || '0') - 1);
			var list = document.getElementById('ev-meal-list');
			if (list && !list.querySelector('.ev-meal-card')) {
				document.getElementById('ev-meal-empty').style.display = '';
			}
		})
		.catch(function() { btn.disabled = false; });
	});
}
<?php endif; ?>
</script>
