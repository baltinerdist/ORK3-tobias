<?php /* Tournament Report — rp- shell (header / context / stats) + tabbed detail views */ ?>
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">
<?php
	$T          = $this->data['ProgramStats']['Totals'] ?? [];
	$scopeType  = $this->data['ScopeType'];                       // 'kingdom' | 'park' | ''
	$scopeName  = $this->data['ScopeName'] ?? '';
	$scopeIcon  = $this->data['ScopeIcon'] ?? 'fa-globe';
	$scopeLink  = $this->data['ScopeLink'] ?? '';
	$scopeNoun  = $scopeType === 'park' ? 'park' : ($scopeType === 'kingdom' ? 'kingdom' : 'scope');
	$dateFrom   = $this->data['DateFrom'];
	$dateTo     = $this->data['DateTo'];
	$fmtDate    = function($d){ return $d ? date('M j, Y', strtotime($d)) : ''; };
	$periodLbl  = '';
	if ($dateFrom && $dateTo)      $periodLbl = $fmtDate($dateFrom) . ' – ' . $fmtDate($dateTo);
	elseif ($dateFrom)             $periodLbl = 'Since ' . $fmtDate($dateFrom);
	elseif ($dateTo)               $periodLbl = 'Through ' . $fmtDate($dateTo);
	$scopeParam = $scopeType === 'park' ? 'ParkId' : 'KingdomId';
?>
<div class="rp-root" id="tnr-report" data-scope="<?=htmlspecialchars($scopeType)?>" data-id="<?=(int)$this->data['ScopeId']?>">

	<!-- Header -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-trophy rp-header-icon"></i>
				<h1 class="rp-header-title">Tournament Report</h1>
<?php if ($periodLbl): ?>
				<span style="display:inline-flex;align-items:center;background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.25);border-radius:20px;padding:3px 11px;font-size:0.78rem;font-weight:600;color:rgba(255,255,255,0.9);white-space:nowrap;"><?=htmlspecialchars($periodLbl)?></span>
<?php endif; ?>
			</div>
<?php if ($scopeName): ?>
			<div class="rp-header-scope">
				<span class="rp-scope-chip-label">Scope:</span>
<?php if ($scopeLink): ?>
				<a href="<?=$scopeLink?>" class="rp-scope-chip"><i class="fas <?=htmlspecialchars($scopeIcon)?>"></i> <?=htmlspecialchars($scopeName)?></a>
<?php else: ?>
				<span class="rp-scope-chip"><i class="fas <?=htmlspecialchars($scopeIcon)?>"></i> <?=htmlspecialchars($scopeName)?></span>
<?php endif; ?>
			</div>
<?php endif; ?>
		</div>
		<div class="rp-header-actions">
			<form class="tnr-filter" method="get" id="tnr-filter">
				<input type="hidden" name="<?=$scopeParam?>" value="<?=(int)$this->data['ScopeId']?>">
				<input type="text" class="tnr-date" name="DateFrom" placeholder="From" value="<?=htmlspecialchars($dateFrom)?>">
				<input type="text" class="tnr-date" name="DateTo" placeholder="To" value="<?=htmlspecialchars($dateTo)?>">
				<button type="submit" class="rp-btn-ghost"><i class="fas fa-filter"></i> Apply</button>
<?php if ($dateFrom || $dateTo): ?>
				<a class="rp-btn-ghost" href="<?=UIR?>Reports/tournaments&<?=$scopeParam?>=<?=(int)$this->data['ScopeId']?>&AllTime=1"><i class="fas fa-times"></i> All time</a>
<?php endif; ?>
			</form>
		</div>
	</div>

	<!-- Context strip -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Tournament results<?php if ($scopeNoun !== 'scope'): ?> for this <?=$scopeNoun?><?php endif; ?><?php if ($periodLbl): ?> over the selected date range<?php endif; ?>. Championships count per-bracket wins; <strong>Warrior level</strong> (0–12) reflects each fighter's Order of the Warrior ranking. Upsets are wins over opponents ranked 3+ Warrior levels higher.</span>
	</div>

	<!-- Stats row -->
	<div class="rp-stats-row">
		<div class="rp-stat-card">
			<div class="rp-stat-tip"><span class="rp-stat-tip-icon" data-tip="Total tournaments held in this scope and date range.">?</span></div>
			<div class="rp-stat-icon"><i class="fas fa-trophy"></i></div>
			<div class="rp-stat-number"><?=(int)($T['Total']??0)?></div>
			<div class="rp-stat-label">Tournaments</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-tip"><span class="rp-stat-tip-icon" data-tip="Distinct players who competed.">?</span></div>
			<div class="rp-stat-icon"><i class="fas fa-users"></i></div>
			<div class="rp-stat-number"><?=number_format((int)($T['UniqueParticipants']??0))?></div>
			<div class="rp-stat-label">Unique Fighters</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-tip"><span class="rp-stat-tip-icon" data-tip="Share of tournaments marked complete.">?</span></div>
			<div class="rp-stat-icon"><i class="fas fa-flag-checkered"></i></div>
			<div class="rp-stat-number"><?=(int)($T['CompletionRate']??0)?>%</div>
			<div class="rp-stat-label">Completion Rate</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-tip"><span class="rp-stat-tip-icon" data-tip="Average Order-of-the-Warrior level (0–12) of participants at time of competition.">?</span></div>
			<div class="rp-stat-icon"><i class="fas fa-khanda"></i></div>
			<div class="rp-stat-number"><?=htmlspecialchars($T['AvgWarriorLevel']??0)?></div>
			<div class="rp-stat-label">Avg Warrior Level</div>
		</div>
	</div>

	<!-- Tabs -->
	<nav class="tnr-tabs" role="tablist">
		<button class="tnr-tab tnr-active" data-tnrtab="overview"><i class="fas fa-chart-line"></i> Overview</button>
		<button class="tnr-tab" data-tnrtab="fighters"><i class="fas fa-khanda"></i> Fighters</button>
		<button class="tnr-tab" data-tnrtab="awards"><i class="fas fa-medal"></i> Awards</button>
<?php if ($scopeType === 'kingdom'): ?>
		<button class="tnr-tab" data-tnrtab="parks"><i class="fas fa-map-marked-alt"></i> Parks</button>
<?php endif; ?>
	</nav>

	<!-- Overview: breakdowns + trend -->
	<div class="tnr-panel tnr-active" id="tnr-tab-overview">
		<div class="tnr-grid2">
			<div class="tnr-card"><h4 class="tnr-h">By Style</h4>
<?php foreach (($this->data['ProgramStats']['ByStyle']??[]) as $s): ?>
				<div class="tnr-bar-row"><span><?=htmlspecialchars($s['Key'])?></span><b><?=(int)$s['Count']?></b></div>
<?php endforeach; ?>
<?php if (empty($this->data['ProgramStats']['ByStyle'])): ?><div class="tnr-empty">No tournaments in range.</div><?php endif; ?>
			</div>
			<div class="tnr-card"><h4 class="tnr-h">By Method</h4>
<?php foreach (($this->data['ProgramStats']['ByMethod']??[]) as $s): ?>
				<div class="tnr-bar-row"><span><?=htmlspecialchars($s['Key'])?></span><b><?=(int)$s['Count']?></b></div>
<?php endforeach; ?>
<?php if (empty($this->data['ProgramStats']['ByMethod'])): ?><div class="tnr-empty">No tournaments in range.</div><?php endif; ?>
			</div>
		</div>
		<div class="tnr-card"><h4 class="tnr-h">Activity Over Time</h4>
			<svg id="tnr-trend" class="tnr-trend" viewBox="0 0 600 160" preserveAspectRatio="none"></svg>
			<div class="tnr-legend"><span class="tnr-key tnr-key-t"></span> Tournaments &nbsp; <span class="tnr-key tnr-key-p"></span> Participants</div>
		</div>
		<script>window.__tnrTrend = <?=json_encode($this->data['ProgramStats']['Trend'] ?? [])?>;</script>
	</div>

	<!-- Fighters leaderboard -->
	<div class="tnr-panel" id="tnr-tab-fighters">
		<table class="tnr-table tnr-sortable" id="tnr-fighters">
			<thead><tr>
				<th data-sort="text">Fighter</th>
				<th data-sort="num" data-tip="Order of the Warrior 0-12">Warrior</th>
				<th data-sort="num">Tournaments</th>
				<th data-sort="num">W</th><th data-sort="num">L</th><th data-sort="num">Win %</th>
				<th data-sort="num">Championships</th><th data-sort="num">Podiums</th>
				<th data-sort="num">Streak</th><th data-sort="num" data-tip="Wins vs fighters 3+ Warrior levels higher">Upsets</th>
			</tr></thead>
			<tbody>
<?php foreach (($this->data['Leaderboard']['Fighters']??[]) as $f): ?>
				<tr>
					<td><a href="<?=UIR?>Player/profile/<?=(int)$f['MundaneId']?>"><?=htmlspecialchars($f['Persona'])?></a></td>
					<td><?=(int)$f['WarriorLevel']?></td>
					<td><?=(int)$f['TournamentsEntered']?></td>
					<td><?=(int)$f['Wins']?></td><td><?=(int)$f['Losses']?></td><td><?=(int)$f['WinPct']?>%</td>
					<td><?=(int)$f['Championships']?></td><td><?=(int)$f['Podiums']?></td>
					<td><?=(int)$f['MaxStreak']?></td><td><?=(int)$f['UpsetWins']?></td>
				</tr>
<?php endforeach; ?>
			</tbody>
		</table>
<?php if (empty($this->data['Leaderboard']['Fighters'])): ?><div class="tnr-empty">No individual-bracket results in range.</div><?php endif; ?>
	</div>

	<!-- Award candidates -->
	<div class="tnr-panel" id="tnr-tab-awards">
<?php foreach (($this->data['AwardCandidates']['Candidates']??[]) as $c): ?>
		<div class="tnr-cand <?=$c['OotWCandidate'] ? 'tnr-cand-ootw' : ''?>">
			<div class="tnr-cand-main">
				<a class="tnr-cand-name" href="<?=UIR?>Player/profile/<?=(int)$c['MundaneId']?>"><?=htmlspecialchars($c['Persona'])?></a>
				<span class="tnr-cand-wl">Warrior <?=(int)$c['WarriorLevel']?></span>
<?php if ($c['OotWCandidate']): ?><span class="tnr-pill">Order of the Warrior candidate</span><?php endif; ?>
				<div class="tnr-cand-note"><?=htmlspecialchars($c['EvidenceNote'])?></div>
			</div>
			<a class="rp-btn-ghost tnr-cand-btn" href="<?=UIR?>Player/profile/<?=(int)$c['MundaneId']?>" data-tip="Open this fighter's profile to make an award recommendation"><i class="fas fa-star"></i> Recommend</a>
		</div>
<?php endforeach; ?>
<?php if (empty($this->data['AwardCandidates']['Candidates'])): ?><div class="tnr-empty">No recognition candidates meet the thresholds in range.</div><?php endif; ?>
	</div>

<?php if ($scopeType === 'kingdom'): ?>
	<!-- Park comparison -->
	<div class="tnr-panel" id="tnr-tab-parks">
		<table class="tnr-table tnr-sortable" id="tnr-parks">
			<thead><tr><th data-sort="text">Park</th><th data-sort="num">Tournaments Hosted</th><th data-sort="num">Participants</th><th data-sort="num">Championships</th><th data-sort="num">Avg Warrior</th></tr></thead>
			<tbody>
<?php foreach (($this->data['ParkComparison']['Parks']??[]) as $p): ?>
				<tr>
					<td><a href="<?=UIR?>Park/profile/<?=(int)$p['ParkId']?>"><?=htmlspecialchars($p['ParkName'])?></a></td>
					<td><?=(int)$p['TournamentsHosted']?></td><td><?=(int)$p['Participants']?></td>
					<td><?=(int)$p['Championships']?></td><td><?=htmlspecialchars($p['AvgWarriorLevel'])?></td>
				</tr>
<?php endforeach; ?>
			</tbody>
		</table>
<?php if (empty($this->data['ParkComparison']['Parks'])): ?><div class="tnr-empty">No park-hosted tournaments in range.</div><?php endif; ?>
	</div>
<?php endif; ?>

</div>
<script>
(function(){
  var root = document.getElementById('tnr-report'); if(!root) return;
  root.querySelectorAll('.tnr-tab').forEach(function(btn){
    btn.addEventListener('click', function(){
      root.querySelectorAll('.tnr-tab').forEach(t=>t.classList.remove('tnr-active'));
      root.querySelectorAll('.tnr-panel').forEach(p=>p.classList.remove('tnr-active'));
      btn.classList.add('tnr-active');
      var panel = document.getElementById('tnr-tab-'+btn.dataset.tnrtab);
      if(panel) panel.classList.add('tnr-active');
    });
  });
  root.querySelectorAll('.tnr-sortable th[data-sort]').forEach(function(th){
    th.style.cursor='pointer';
    th.addEventListener('click', function(){
      var table=th.closest('table'), tbody=table.tBodies[0], idx=Array.from(th.parentNode.children).indexOf(th);
      var num=th.dataset.sort==='num', dir=th.__asc=!th.__asc?1:-1;
      Array.from(tbody.rows).sort(function(a,b){
        var x=a.cells[idx].textContent.trim(), y=b.cells[idx].textContent.trim();
        if(num){ x=parseFloat(x)||0; y=parseFloat(y)||0; return (x-y)*dir; }
        return x.localeCompare(y)*dir;
      }).forEach(function(r){tbody.appendChild(r);});
    });
  });
  if(window.flatpickr){
    root.querySelectorAll('.tnr-date').forEach(function(el){
      flatpickr(el,{altInput:true,altFormat:'F j, Y',dateFormat:'Y-m-d'});
    });
  }
  var data=window.__tnrTrend||[], svg=document.getElementById('tnr-trend');
  if(svg && data.length){
    var W=600,H=160,pad=20,n=data.length,bw=(W-pad*2)/n;
    var maxT=Math.max.apply(null,data.map(d=>d.Tournaments).concat([1]));
    var maxP=Math.max.apply(null,data.map(d=>d.Participants).concat([1]));
    var html='';
    data.forEach(function(d,i){
      var x=pad+i*bw;
      var th=(H-pad)*d.Tournaments/maxT, ph=(H-pad)*d.Participants/maxP;
      html+='<rect x="'+(x+2)+'" y="'+(H-th)+'" width="'+(bw/2-3)+'" height="'+th+'" class="tnr-bar-t"></rect>';
      html+='<rect x="'+(x+bw/2)+'" y="'+(H-ph)+'" width="'+(bw/2-3)+'" height="'+ph+'" class="tnr-bar-p"></rect>';
    });
    svg.innerHTML=html;
  }
})();
</script>
