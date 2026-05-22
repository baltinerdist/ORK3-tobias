<?php /* Tournament Report — Overview / Fighters / Awards / Parks */ ?>
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">
<div class="tnr-report" id="tnr-report"
     data-scope="<?= htmlspecialchars($this->data['ScopeType']) ?>"
     data-id="<?= (int)$this->data['ScopeId'] ?>">

  <div class="tnr-head">
    <h2 class="tnr-title"><?= htmlspecialchars($this->data['page_title']) ?></h2>
    <form class="tnr-filter" method="get" id="tnr-filter">
      <input type="hidden" name="<?= $this->data['ScopeType']==='park' ? 'ParkId' : 'KingdomId' ?>" value="<?= (int)$this->data['ScopeId'] ?>">
      <label>From <input type="text" class="tnr-date" name="DateFrom" value="<?= htmlspecialchars($this->data['DateFrom']) ?>"></label>
      <label>To <input type="text" class="tnr-date" name="DateTo" value="<?= htmlspecialchars($this->data['DateTo']) ?>"></label>
      <button type="submit" class="tnr-btn">Apply</button>
      <?php if ($this->data['DateFrom'] || $this->data['DateTo']): ?>
        <a class="tnr-btn tnr-btn-ghost" href="<?= UIR ?>Reports/tournaments&<?= $this->data['ScopeType']==='park' ? 'ParkId' : 'KingdomId' ?>=<?= (int)$this->data['ScopeId'] ?>">All time</a>
      <?php endif; ?>
    </form>
  </div>

  <nav class="tnr-tabs" role="tablist">
    <button class="tnr-tab tnr-active" data-tnrtab="overview"><i class="fas fa-chart-line"></i> Overview</button>
    <button class="tnr-tab" data-tnrtab="fighters"><i class="fas fa-khanda"></i> Fighters</button>
    <button class="tnr-tab" data-tnrtab="awards"><i class="fas fa-medal"></i> Awards</button>
    <?php if ($this->data['ScopeType']==='kingdom'): ?>
      <button class="tnr-tab" data-tnrtab="parks"><i class="fas fa-map-marked-alt"></i> Parks</button>
    <?php endif; ?>
  </nav>

  <div class="tnr-panel tnr-active" id="tnr-tab-overview">
    <?php $T = $this->data['ProgramStats']['Totals'] ?? []; ?>
    <div class="tnr-stat-row">
      <div class="tnr-stat"><div class="tnr-stat-num"><?= (int)($T['Total']??0) ?></div><div class="tnr-stat-lbl">Tournaments</div></div>
      <div class="tnr-stat"><div class="tnr-stat-num"><?= (int)($T['UniqueParticipants']??0) ?></div><div class="tnr-stat-lbl">Unique Fighters</div></div>
      <div class="tnr-stat"><div class="tnr-stat-num"><?= (int)($T['CompletionRate']??0) ?>%</div><div class="tnr-stat-lbl">Completion Rate</div></div>
      <div class="tnr-stat"><div class="tnr-stat-num"><?= htmlspecialchars($T['AvgWarriorLevel']??0) ?></div><div class="tnr-stat-lbl">Avg Warrior Level</div></div>
    </div>
    <div class="tnr-grid2">
      <div class="tnr-card"><h4 class="tnr-h">By Style</h4>
        <?php foreach (($this->data['ProgramStats']['ByStyle']??[]) as $s): ?>
          <div class="tnr-bar-row"><span><?= htmlspecialchars($s['Key']) ?></span><b><?= (int)$s['Count'] ?></b></div>
        <?php endforeach; ?>
      </div>
      <div class="tnr-card"><h4 class="tnr-h">By Method</h4>
        <?php foreach (($this->data['ProgramStats']['ByMethod']??[]) as $s): ?>
          <div class="tnr-bar-row"><span><?= htmlspecialchars($s['Key']) ?></span><b><?= (int)$s['Count'] ?></b></div>
        <?php endforeach; ?>
      </div>
    </div>
    <div class="tnr-card"><h4 class="tnr-h">Activity Over Time</h4>
      <svg id="tnr-trend" class="tnr-trend" viewBox="0 0 600 160" preserveAspectRatio="none"></svg>
    </div>
    <script>window.__tnrTrend = <?= json_encode($this->data['ProgramStats']['Trend'] ?? []) ?>;</script>
  </div>

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
          <td><a href="<?= UIR ?>Player/profile/<?= (int)$f['MundaneId'] ?>"><?= htmlspecialchars($f['Persona']) ?></a></td>
          <td><?= (int)$f['WarriorLevel'] ?></td>
          <td><?= (int)$f['TournamentsEntered'] ?></td>
          <td><?= (int)$f['Wins'] ?></td><td><?= (int)$f['Losses'] ?></td><td><?= (int)$f['WinPct'] ?>%</td>
          <td><?= (int)$f['Championships'] ?></td><td><?= (int)$f['Podiums'] ?></td>
          <td><?= (int)$f['MaxStreak'] ?></td><td><?= (int)$f['UpsetWins'] ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
    <?php if (empty($this->data['Leaderboard']['Fighters'])): ?><div class="tnr-empty">No individual-bracket results in range.</div><?php endif; ?>
  </div>

  <div class="tnr-panel" id="tnr-tab-awards">
    <?php foreach (($this->data['AwardCandidates']['Candidates']??[]) as $c): ?>
      <div class="tnr-cand <?= $c['OotWCandidate'] ? 'tnr-cand-ootw' : '' ?>">
        <div class="tnr-cand-main">
          <a class="tnr-cand-name" href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>"><?= htmlspecialchars($c['Persona']) ?></a>
          <span class="tnr-cand-wl">Warrior <?= (int)$c['WarriorLevel'] ?></span>
          <?php if ($c['OotWCandidate']): ?><span class="tnr-pill">Order of the Warrior candidate</span><?php endif; ?>
          <div class="tnr-cand-note"><?= htmlspecialchars($c['EvidenceNote']) ?></div>
        </div>
        <a class="tnr-btn" href="<?= UIR ?>Player/profile/<?= (int)$c['MundaneId'] ?>" data-tip="Open this fighter's profile to make an award recommendation">Recommend</a>
      </div>
    <?php endforeach; ?>
    <?php if (empty($this->data['AwardCandidates']['Candidates'])): ?><div class="tnr-empty">No recognition candidates meet the thresholds in range.</div><?php endif; ?>
  </div>

  <?php if ($this->data['ScopeType']==='kingdom'): ?>
    <div class="tnr-panel" id="tnr-tab-parks">
      <table class="tnr-table tnr-sortable" id="tnr-parks">
        <thead><tr><th data-sort="text">Park</th><th data-sort="num">Tournaments Hosted</th><th data-sort="num">Participants</th><th data-sort="num">Championships</th><th data-sort="num">Avg Warrior</th></tr></thead>
        <tbody>
        <?php foreach (($this->data['ParkComparison']['Parks']??[]) as $p): ?>
          <tr>
            <td><a href="<?= UIR ?>Park/profile/<?= (int)$p['ParkId'] ?>"><?= htmlspecialchars($p['ParkName']) ?></a></td>
            <td><?= (int)$p['TournamentsHosted'] ?></td><td><?= (int)$p['Participants'] ?></td>
            <td><?= (int)$p['Championships'] ?></td><td><?= htmlspecialchars($p['AvgWarriorLevel']) ?></td>
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
