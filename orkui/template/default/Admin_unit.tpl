<script type='text/javascript'>

	$(document).ready(function() {
		$( "#ManageMembers #PlayerName" ).autocomplete({
			source: function( request, response ) {
				$.getJSON(
					"<?=HTTP_SERVICE ?>Search/SearchService.php",
					{
						Action: 'Search/Player',
						type: 'all',
						search: request.term,
                        limit: 8
					},
					function( data ) {
						var suggestions = [];
						$.each(data, function(i, val) {
							suggestions.push({label: val.Persona, value: val.MundaneId });
						});
						response(suggestions);
					}
				);
			},
			focus: function( event, ui ) {
				return showLabel($(this), ui);
			}, 
			delay: 500,
			select: function (e, ui) {
				showLabel("#ManageMembers #PlayerName", ui);
				$("#MemberMundaneId").val(ui.item.value);
				return false;
			},
			change: function (e, ui) {
				if (ui.item == null) {
					showLabel("#ManageMembers #PlayerName",null);
					$("#MemberMundaneId").val(null);
				}
				return false;
			}
		}).focus(function() {
			if (this.value == "")
				$(this).trigger('keydown.autocomplete');
		});		
		$( "#ManagerForm #PlayerName" ).autocomplete({
			source: function( request, response ) {
				park_id = $('#ParkId').val();
				$.getJSON(
					"<?=HTTP_SERVICE ?>Search/SearchService.php",
					{
						Action: 'Search/Player',
						type: 'all',
						search: request.term,
                        limit: 8
					},
					function( data ) {
						var suggestions = [];
						$.each(data, function(i, val) {
							suggestions.push({label: val.Persona, value: val.MundaneId });
						});
						response(suggestions);
					}
				);
			},
			focus: function( event, ui ) {
				return showLabel('#ManagerForm #PlayerName', ui);
			}, 
			delay: 500,
			select: function (e, ui) {
				showLabel('#ManagerForm #PlayerName', ui);
				$('#ManagerMundaneId').val(ui.item.value);
				return false;
			},
			change: function (e, ui) {
				if (ui.item == null) {
					showLabel('#ManagerForm #PlayerName',null);
					$('#ManagerMundaneId').val(null);
				}
				return false;
			}
		}).focus(function() {
			if (this.value == "")
				$(this).trigger('keydown.autocomplete');
		});
	});
	
</script>

<div class='info-container'>
	<h3><?=$Unit['Details']['Unit']['Name'] ?></h3>
<?php if (strlen($Error) > 0) : ?>
	<div class='error-message'><?=$Error ?></div>
<?php endif; ?>
	<form class='form-container' method='post' action='<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=details' enctype='multipart/form-data'>
		<div>
			<span>Heraldry:</span>
			<span>
				<img class='heraldry-img' src='<?=($Unit['Details']['Unit']['HasHeraldry']?$Unit_heraldryurl['Url']:(HTTP_UNIT_HERALDRY.'00000.jpg')) . '?t=' . time() ?>' />
				<input type='file' class='restricted-image-type' name='Heraldry' id='Heraldry' />
			</span>
		</div>
		<div>
			<span>Name:</span>
			<span><input type='text' class='name-field required-field' value='<?=htmlentities($Unit['Details']['Unit']['Name'], ENT_QUOTES) ?>' name='Name' /></span>
		</div>
		<div>
			<span>Type:</span>
			<?php if ($Unit['Details']['Unit']['Type'] == 'Company') : ?>
				<span class='form-informational-field'><?=$Unit['Details']['Unit']['Type'] ?><a style='float: right; display: inline-block; padding: 3px; border: 1px solid #900; background-color: #fcd' href='<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=giveup'>Convert to Household</a></span>
			<?php else: ?>
				<span class='form-informational-field'><?=$Unit['Details']['Unit']['Type'] ?><a style='float: right; display: inline-block; padding: 3px; border: 1px solid #900; background-color: #fcd' href='<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=tocompany'>Convert to Company</a></span>
			<?php endif; ?>
		</div>
		<div>
			<span>URL:</span>
			<span><input type='text' class='name-field' value='<?=htmlentities($Unit['Details']['Unit']['Url'], ENT_QUOTES) ?>' name='Url' /></span>
		</div>
		<div>
			<span>Description:</span>
			<span class='form-informational-field'><textarea name='Description' rows=10 cols=50><?=$Unit['Details']['Unit']['Description'] ?></textarea></span>
		</div>
		<div>
			<span>History:</span>
			<span class='form-informational-field'><textarea name='History' rows=10 cols=50><?=$Unit['Details']['Unit']['History'] ?></textarea></span>
		</div>
		<div>
			<span></span>
			<span><input type='submit' value='Edit <?=$Unit['Details']['Unit']['Type'] ?>' name='EditUnit' /></span>
		</div>
	</form>
</div>

<div class='info-container'>
	<h3>Managers</h3>
	<form method='post' id='ManagerForm' class='form-container' action='<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=addauth'>
		<table class='information-table action-table'>
			<thead>
				<tr>
					<th>UserName</th>
					<th>Persona</th>
					<th class='deletion'>&times;</th>
				</tr>
			</thead>
			<tbody>
<?php foreach ($Unit['Authorizations']['Authorizations'] as $k => $auth) : ?>
				<tr onClick="javascript:document.location.href='<?=UIR ?>Player/profile/<?=$auth['MundaneId'] ?>'">
					<td><?=$auth['UserName'] ?></td>
					<td><?=$auth['Persona'] ?></td>
					<td class='deletion'><a href='<?=UIR . 'Admin/unit/' . $Unit['Details']['Unit']['UnitId'] . '&Action=deleteauth&AuthorizationId=' . $auth['AuthorizationId'] ?>'>&times;</a></td>
				</tr>
<?php endforeach; ?>
				<tr>
					<td colspan='3'><input class='name-field' type='text' name='PlayerName' id='PlayerName' /></td>
				</tr>
				<tr>
					<td colspan='3'><input type='submit' value='Add Player' /></td>
				</tr>
			</tbody>
		</table>
		<input type='hidden' name='MundaneId' id='ManagerMundaneId' />
	</form>
</div>
<script type='text/javascript'>
	$(document).ready(function() {
		$('#MemberCancelEdit').hide();
	});
	function EditMember(el, mundane_id) {
		$('#MemberCancelEdit').show();
		$('#MembersEditBox #PlayerName').attr('disabled','disabled');
		$('#MembersEditBox #PlayerName').val((el.children(":nth-child(1)").text()));
		$('#MembersEditBox #Role').val((el.children(":nth-child(2)").text().toLowerCase()));
		$('#MembersEditBox #Title').val((el.children(":nth-child(3)").text()));
		$('#MemberMundaneId').val(mundane_id);
		$('#MemberSubmit').val('Edit');
		$('#ManageMembers').attr('action','<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=editmember');
	}
	function HideEdit() {
		$('#MembersEditBox #PlayerName').removeAttr('disabled');
		$('#MembersEditBox #PlayerName').val('');
		$('#MembersEditBox #Role').val('');
		$('#MembersEditBox #Title').val('');
		$('#MemberMundaneId').val('');
		$('#MemberCancelEdit').hide();
		$('#MemberSubmit').val('Add');
		$('#ManageMembers').attr('action','<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=addmember');
	}
</script>
<div class='info-container'>
	<h3>Members</h3>
	<form method='post' id='ManageMembers' class='form-container' action='<?=UIR ?>Admin/unit/<?=$Unit['Details']['Unit']['UnitId'] ?>&Action=addmember'>
		<table class='information-table action-table'>
			<thead>
				<tr>
					<th>Member</th>
					<th>Role</th>
					<th>Title</th>
					<th>Quit</th>
					<th class='deletion'>&times;</th>
				</tr>
			</thead>
			<tbody>
<?php foreach ($Unit['Members']['Roster'] as $k => $member) : ?>
				<tr onClick="javascript:EditMember($(this), <?=$member['UnitMundaneId'] ?>)">
					<td><a href='<?=UIR ?>Player/profile/<?=$member['MundaneId'] ?>'><?=$member['Persona'] ?></a></td>
					<td><?=ucfirst($member['UnitRole']) ?></td>
					<td><?=$member['UnitTitle'] ?></td>
					<td><a href='<?=UIR . 'Admin/unit/' . $Unit['Details']['Unit']['UnitId'] . '&Action=retire&UnitMundaneId=' . $member['UnitMundaneId'] ?>'>Quit</a></td>
					<td class='deletion'><a href='<?=UIR . 'Admin/unit/' . $Unit['Details']['Unit']['UnitId'] . '&Action=remove&UnitMundaneId=' . $member['UnitMundaneId'] ?>'>&times;</a></td>
				</tr>
<?php endforeach; ?>
				<tr id='MembersEditBox'>
					<td><input type='text' name='PlayerName' id='PlayerName' /></td>
					<td>
						<select name='Role' id="Role">
							<option value='member'>Member</option>
							<option value='lord'>Lord</option>
							<option value='captain'>Captain</option>
							<option value='organizer'>Organizer</option>
						</select>
					</td>
					<td><input type='text' name='Title' id='Title' /></td>
					<td colspan='2'><button type='button' id='MemberCancelEdit' onClick='javscript:HideEdit()'>Cancel</button><input type='submit' value='Add' id='MemberSubmit' /></td>
				</tr>
			</tbody>
		</table>
		<input type='hidden' name='MundaneId' id='MemberMundaneId' />
	</form>
</div>

<div class='info-container'>
	<h3>Unit Operations for <?=$Unit['Details']['Unit']['Name'] ?></h3>
	<ul>
		<li>Events
			<ul>
				<li><a href='<?=UIR ?>Admin/createevent&UnitId=<?=$Unit['Details']['Unit']['UnitId'] ?>'>Schedule an Event</a></li>
				</ul>
		</li>
	</ul>
</div>

<?php $slStub = $ShortlinkStub ?? ''; $slDefault = $ShortlinkDefault ?? ''; $slCanEdit = !empty($ShortlinkCanEdit); $slUnitId = (int)($ShortlinkUnitId ?? 0); ?>
<div class="info-container" id="sl-card-unit">
    <h3 style="background:transparent;border:none;padding:0;text-shadow:none;border-radius:0;">Shortcut Link</h3>
    <p>Unit link:
        <code id="sl-url-unit">ork.amtgard.com/me/<?= $slStub !== '' ? htmlspecialchars($slStub, ENT_QUOTES) : htmlspecialchars($slDefault, ENT_QUOTES) ?></code>
        <button type="button" id="sl-copy-unit">Copy</button>
    </p>
    <?php if ($slCanEdit): ?>
    <div>
        <span>ork.amtgard.com/me/</span>
        <input type="text" id="sl-input-unit" maxlength="30" placeholder="custom-name"
               value="<?= htmlspecialchars($slStub, ENT_QUOTES) ?>">
    </div>
    <div id="sl-feedback-unit" style="font-size:12px;min-height:16px;margin-top:6px;"></div>
    <button type="button" id="sl-save-unit" disabled>Save shortcut</button>
    <button type="button" id="sl-reset-unit">Reset to default</button>
    <?php endif; ?>
</div>
<?php if ($slCanEdit): ?>
<script>
$(document).ready(function () {
    (function () {
        var ROOT = '<?= UIR ?>', TYPE = 'unit', ID = <?= $slUnitId ?>;
        var PREFIX = 'ork.amtgard.com/me/', CUR = <?= json_encode($slStub) ?>;
        var input = document.getElementById('sl-input-unit'),
            fb = document.getElementById('sl-feedback-unit'),
            saveBtn = document.getElementById('sl-save-unit'),
            resetBtn = document.getElementById('sl-reset-unit'),
            urlEl = document.getElementById('sl-url-unit');
        var timer, lastChecked = '', lastAvailable = false;
        function fbk(c, m) { fb.style.color = (c === 'ok' ? '#2f855a' : c === 'bad' ? '#c53030' : ''); fb.textContent = m; }
        input.addEventListener('input', function () {
            clearTimeout(timer);
            var slug = this.value.trim().toLowerCase();
            saveBtn.disabled = true;
            if (!slug) { fbk('', ''); return; }
            if (slug === CUR) { fbk('ok', 'Current shortcut.'); return; }
            fbk('', 'Checking…');
            timer = setTimeout(function () {
                fetch(ROOT + 'ShortLinkAjax/check', { method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
                    body: 'type=' + TYPE + '&id=' + ID + '&slug=' + encodeURIComponent(slug) })
                  .then(function (r) { return r.json(); }).then(function (d) {
                    lastChecked = slug; lastAvailable = !!d.available;
                    fbk(d.available ? 'ok' : 'bad', (d.available ? '✓ ' : '✗ ') + (d.reason || ''));
                    saveBtn.disabled = !d.available;
                }).catch(function () { fbk('bad', 'Could not check.'); });
            }, 250);
        });
        saveBtn.addEventListener('click', function () {
            var slug = input.value.trim().toLowerCase();
            if (slug !== lastChecked || !lastAvailable) { return; }
            saveBtn.disabled = true;
            fetch(ROOT + 'ShortLinkAjax/save', { method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
                body: 'type=' + TYPE + '&id=' + ID + '&slug=' + encodeURIComponent(slug) })
              .then(function (r) { return r.json(); }).then(function (d) {
                if (d.status === 0) { CUR = d.stub; urlEl.textContent = PREFIX + d.stub; fbk('ok', 'Saved!'); }
                else { fbk('bad', d.error || 'Could not save.'); saveBtn.disabled = false; }
            }).catch(function () { fbk('bad', 'Could not save.'); saveBtn.disabled = false; });
        });
        resetBtn.addEventListener('click', function () {
            fetch(ROOT + 'ShortLinkAjax/save', { method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin',
                body: 'type=' + TYPE + '&id=' + ID + '&slug=' })
              .then(function (r) { return r.json(); }).then(function (d) {
                if (d.status === 0) { CUR = ''; input.value = ''; urlEl.textContent = PREFIX + d.stub; fbk('ok', 'Reset to default.'); }
            }).catch(function () { fbk('bad', 'Could not reset.'); });
        });
    })();
});
</script>
<?php endif; ?>
<script>
(function () {
    var copyBtn = document.getElementById('sl-copy-unit');
    var urlEl = document.getElementById('sl-url-unit');
    if (!copyBtn || !urlEl) { return; }
    copyBtn.addEventListener('click', function () {
        var url = urlEl.textContent, orig = copyBtn.textContent;
        function done(ok) { copyBtn.textContent = ok ? 'Copied!' : 'Copy failed'; setTimeout(function () { copyBtn.textContent = orig; }, 1400); }
        if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(url).then(function () { done(true); }, function () { done(false); }); }
        else { var ta = document.createElement('textarea'); ta.value = url; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); var ok = false; try { ok = document.execCommand('copy'); } catch (e) {} document.body.removeChild(ta); done(ok); }
    });
})();
</script>
