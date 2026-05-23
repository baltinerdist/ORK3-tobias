<?php /* Tournament Report — rp- shell (header / context / stats) + tabbed detail views */ ?>
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">
<?php
	$T          = $ProgramStats['Totals'] ?? [];
	$scopeType  = $ScopeType;                       // 'kingdom' | 'park' | ''
	$scopeName  = $ScopeName ?? '';
	$scopeIcon  = $ScopeIcon ?? 'fa-globe';
	$scopeLink  = $ScopeLink ?? '';
	$scopeNoun  = $scopeType === 'park' ? 'park' : ($scopeType === 'kingdom' ? 'kingdom' : 'scope');
	$dateFrom   = $DateFrom;
	$dateTo     = $DateTo;
	$fmtDate    = function($d){ return $d ? date('M j, Y', strtotime($d)) : ''; };
	$periodLbl  = '';
	if ($dateFrom && $dateTo)      $periodLbl = $fmtDate($dateFrom) . ' – ' . $fmtDate($dateTo);
	elseif ($dateFrom)             $periodLbl = 'Since ' . $fmtDate($dateFrom);
	elseif ($dateTo)               $periodLbl = 'Through ' . $fmtDate($dateTo);
	$scopeParam = $scopeType === 'park' ? 'ParkId' : 'KingdomId';
?>
<div class="rp-root" id="tnr-report" data-scope="<?=htmlspecialchars($scopeType)?>" data-id="<?=(int)$ScopeId?>">

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
				<input type="hidden" name="<?=$scopeParam?>" value="<?=(int)$ScopeId?>">
				<input type="text" class="tnr-date" name="DateFrom" placeholder="From" value="<?=htmlspecialchars($dateFrom)?>">
				<input type="text" class="tnr-date" name="DateTo" placeholder="To" value="<?=htmlspecialchars($dateTo)?>">
				<button type="submit" class="rp-btn-ghost"><i class="fas fa-filter"></i> Apply</button>
<?php if ($dateFrom || $dateTo): ?>
				<a class="rp-btn-ghost" href="<?=UIR?>Reports/tournaments&<?=$scopeParam?>=<?=(int)$ScopeId?>&AllTime=1"><i class="fas fa-times"></i> All time</a>
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
		<button class="tnr-tab" data-tnrtab="tournaments"><i class="fas fa-trophy"></i> Tournaments</button>
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
<?php foreach (($ProgramStats['ByStyle']??[]) as $s): ?>
				<div class="tnr-bar-row"><span><?=htmlspecialchars($s['Key'])?></span><b><?=(int)$s['Count']?></b></div>
<?php endforeach; ?>
<?php if (empty($ProgramStats['ByStyle'])): ?><div class="tnr-empty">No tournaments in range.</div><?php endif; ?>
			</div>
			<div class="tnr-card"><h4 class="tnr-h">By Method</h4>
<?php foreach (($ProgramStats['ByMethod']??[]) as $s): ?>
				<div class="tnr-bar-row"><span><?=htmlspecialchars($s['Key'])?></span><b><?=(int)$s['Count']?></b></div>
<?php endforeach; ?>
<?php if (empty($ProgramStats['ByMethod'])): ?><div class="tnr-empty">No tournaments in range.</div><?php endif; ?>
			</div>
		</div>
		<div class="tnr-card"><h4 class="tnr-h">Activity Over Time</h4>
			<svg id="tnr-trend" class="tnr-trend" viewBox="0 0 720 220" preserveAspectRatio="xMidYMid meet"></svg>
			<div class="tnr-legend">Bar height = participants per month &middot; number on each bar = tournaments held</div>
		</div>
		<script>window.__tnrTrend = <?=json_encode($ProgramStats['Trend'] ?? [])?>;</script>
	</div>

	<!-- Tournaments: per-tournament collective standings + warrior field stats -->
	<div class="tnr-panel" id="tnr-tab-tournaments">
<?php foreach (($TournamentList['Tournaments'] ?? []) as $tour): $w = $tour['WarriorStats']; ?>
		<div class="tnr-tcard">
			<a class="tnr-tcard-name" href="<?=UIR?>Tournament/profile/<?=(int)$tour['TournamentId']?>"><?=htmlspecialchars($tour['Name'])?></a>
			<div class="tnr-tcard-meta"><?=date('M j, Y', strtotime($tour['DateTime']))?><?php if ($scopeType==='kingdom' && $tour['ParkName']): ?> &middot; <?=htmlspecialchars($tour['ParkName'])?><?php endif; ?> &middot; <?=(int)$tour['BracketCount']?> bracket<?=$tour['BracketCount']==1?'':'s'?> &middot; <?=(int)$tour['ParticipantCount']?> fighters</div>
			<div class="tnr-warstats">
				<span class="tnr-warstat" data-tip="Average Order-of-the-Warrior level of the field"><b><?=htmlspecialchars($w['AvgLevel'])?></b> avg Warrior</span>
				<span class="tnr-warstat" data-tip="Median Order-of-the-Warrior level of the field"><b><?=htmlspecialchars($w['MedianLevel'])?></b> median</span>
				<span class="tnr-warstat"><b><?=(int)$w['Warlords']?></b> Warlord<?=$w['Warlords']==1?'':'s'?></span>
				<span class="tnr-warstat"><b><?=(int)$w['SwordKnights']?></b> Sword Knight<?=$w['SwordKnights']==1?'':'s'?></span>
			</div>
			<table class="tnr-table tnr-tstandings">
				<thead><tr><th>#</th><th>Fighter</th><th>W</th><th>L</th><th>Win %</th><th data-tip="Order of the Warrior 0-12">Warrior</th></tr></thead>
				<tbody>
<?php foreach ($tour['TopParticipants'] as $i => $p): ?>
					<tr class="<?=$i >= 4 ? 'tnr-thidden' : ''?>">
						<td><?=$i+1?></td>
						<td><a href="<?=UIR?>Player/profile/<?=(int)$p['MundaneId']?>"><?=htmlspecialchars($p['Persona'])?></a></td>
						<td><?=(int)$p['Wins']?></td><td><?=(int)$p['Losses']?></td><td><?=(int)$p['WinPct']?>%</td><td><?=(int)$p['WarriorLevel']?></td>
					</tr>
<?php endforeach; ?>
				</tbody>
			</table>
<?php if (count($tour['TopParticipants']) > 4): ?>
			<button type="button" class="tnr-showmore">Show more</button>
<?php endif; ?>
		</div>
<?php endforeach; ?>
<?php if (empty($TournamentList['Tournaments'])): ?><div class="tnr-empty">No tournaments in range.</div><?php endif; ?>
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
<?php foreach (($Leaderboard['Fighters']??[]) as $f): ?>
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
<?php if (empty($Leaderboard['Fighters'])): ?><div class="tnr-empty">No individual-bracket results in range.</div><?php endif; ?>
	</div>

	<!-- Award candidates -->
	<div class="tnr-panel" id="tnr-tab-awards">
<?php foreach (($AwardCandidates['Candidates']??[]) as $c): ?>
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
<?php if (empty($AwardCandidates['Candidates'])): ?><div class="tnr-empty">No recognition candidates meet the thresholds in range.</div><?php endif; ?>
	</div>

<?php if ($scopeType === 'kingdom'): ?>
	<!-- Park comparison -->
	<div class="tnr-panel" id="tnr-tab-parks">
		<table class="tnr-table tnr-sortable" id="tnr-parks">
			<thead><tr><th data-sort="text">Park</th><th data-sort="num">Tournaments Hosted</th><th data-sort="num">Participants</th><th data-sort="num">Championships</th><th data-sort="num">Avg Warrior</th></tr></thead>
			<tbody>
<?php foreach (($ParkComparison['Parks']??[]) as $p): ?>
				<tr>
					<td><a href="<?=UIR?>Park/profile/<?=(int)$p['ParkId']?>"><?=htmlspecialchars($p['ParkName'])?></a></td>
					<td><?=(int)$p['TournamentsHosted']?></td><td><?=(int)$p['Participants']?></td>
					<td><?=(int)$p['Championships']?></td><td><?=htmlspecialchars($p['AvgWarriorLevel'])?></td>
				</tr>
<?php endforeach; ?>
			</tbody>
		</table>
<?php if (empty($ParkComparison['Parks'])): ?><div class="tnr-empty">No park-hosted tournaments in range.</div><?php endif; ?>
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
  // Tournaments tab: show more / less of the collective standings (rows 5-8)
  root.querySelectorAll('.tnr-showmore').forEach(function(btn){
    btn.addEventListener('click', function(){
      var card=btn.closest('.tnr-tcard');
      var open=card.classList.toggle('tnr-show-all');
      btn.textContent = open ? 'Show less' : 'Show more';
    });
  });
  var data=window.__tnrTrend||[], svg=document.getElementById('tnr-trend');
  if(svg){
    if(!data.length){ svg.insertAdjacentHTML('afterend','<div class="tnr-empty">No activity in range.</div>'); svg.remove(); return; }
    var W=720,H=220, ml=42, mr=14, mt=22, mb=30;
    var pw=W-ml-mr, ph=H-mt-mb, n=data.length;
    var rawMax=Math.max.apply(null,data.map(function(d){return d.Participants;}).concat([1]));
    function niceMax(v){ if(v<=5)return 5; var p=Math.pow(10,Math.floor(Math.log10(v))); var f=v/p; var nf=f<=1?1:f<=2?2:f<=5?5:10; return nf*p; }
    var maxP=niceMax(rawMax);
    var step=pw/n, gap=Math.min(14, step*0.25), bw=step-gap;
    var labelEvery=Math.ceil(n/12); // thin month labels when the range is long
    function monShort(ym){ var s=ym.split('-'); var m=['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][parseInt(s[1],10)]; return m+" '"+s[0].slice(2); }
    var g='';
    // y gridlines + value labels (0, mid, max)
    [0,0.5,1].forEach(function(f){
      var y=mt+ph-ph*f;
      g+='<line x1="'+ml+'" y1="'+y+'" x2="'+(W-mr)+'" y2="'+y+'" class="tnr-grid"/>';
      g+='<text x="'+(ml-7)+'" y="'+(y+4)+'" class="tnr-axis tnr-axis-y">'+Math.round(maxP*f)+'</text>';
    });
    data.forEach(function(d,i){
      var x=ml+i*step+gap/2;
      var bh=ph*(d.Participants/maxP), y=mt+ph-bh;
      g+='<rect x="'+x.toFixed(1)+'" y="'+y.toFixed(1)+'" width="'+bw.toFixed(1)+'" height="'+Math.max(0,bh).toFixed(1)+'" rx="2" class="tnr-bar-p"></rect>';
      if(d.Tournaments>0){
        var inside=bh>18, ty=inside?(y+14):(y-5);
        g+='<text x="'+(x+bw/2).toFixed(1)+'" y="'+ty.toFixed(1)+'" class="tnr-bar-lbl'+(inside?' tnr-bar-lbl-in':'')+'">'+d.Tournaments+'</text>';
      }
      if(i%labelEvery===0){
        g+='<text x="'+(x+bw/2).toFixed(1)+'" y="'+(mt+ph+16)+'" class="tnr-axis tnr-axis-x">'+monShort(d.Month)+'</text>';
      }
    });
    svg.innerHTML=g;
  }
})();
</script>
