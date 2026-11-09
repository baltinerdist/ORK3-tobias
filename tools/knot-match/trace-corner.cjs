#!/usr/bin/env node
/* trace-corner.cjs -- trace Ash's TL corner (knot.svg) into a designed corner tile for the knot engine.

   node tools/knot-match/trace-corner.cjs <arm> <out.json>                 -> traced paths + <out>.png overlay
   FORCE="x,y:x,y;..." pins gap links (band units, TL frame) where the tangent rule is ambiguous. The
   committed corner-8 tile used arm 2.0 and FORCE="0.27,0.89:0.66,0.50;0.42,0.63:0.90,1.22;0.51,0.29:0.93,0.68"
   (read off the full-resolution art: the diagonal bar passes under the bight into the left-edge strand; the
   bight's lower leg passes under the pink bar into the inner-edge strand; its top leg under the bar into
   the curved strand that leaves along the top).
   node tools/knot-match/trace-corner.cjs tile <traced.json> <corner best.json> <init.json> <lam> <phase>
                                                                            -> corner-stage --init file

   Method: Ash's reference raster (the scorer's class map), per fill colour: 4-connected pieces (each strand
   piece between two under-crossings), Zhang-Suen skeleton -> longest path (a short straight bar that thins
   to a dot uses its principal axis instead). Piece ends are linked across the gap where both end tangents
   point at each other and the gap crosses (almost) no open ground (a gap under an over strand never does).
   Chains are clipped to the L between the in-port line (y = arm) and the out-port line (x = arm). The
   over seed is the colour Ash shows at the first blue/pink crossing. */
const KM = require('./knotmatch.cjs');
const { PNG } = require('pngjs');
const fs = require('fs');
if (process.argv[2] === 'tile') { makeTile(...process.argv.slice(3)).catch(e => { console.error(e); process.exit(1); }); } else { trace(+(process.argv[2] || 1.65), process.argv[3] || 'tile.json').catch(e => { console.error(e); process.exit(1); }); }
async function trace(ARM, OUT) {
  const WIN = ARM + 0.7;
  const ref = await KM.getRef(KM.DEFAULT_REF), { w, c } = ref.cm, m = ref.m, b = m.band;
  // END=1: Ash's top-L break end instead -- frame origin at the break's outer ink edge, x = U (band widths
  // from the end into the weave, i.e. leftwards on the page), y = V down across the band
  const END = !!process.env.END, O = END ? [m.topGap[0], m.inset] : [m.inset, m.inset];
  console.log('inset', m.inset, 'band', b, END ? 'end top-L' : 'corner TL');
  const N = Math.ceil(WIN * b), at = END ? (x, y) => c[(O[1] + y) * w + O[0] - x] : (x, y) => c[(O[1] + y) * w + O[0] + x];
  const inL = END ? (x, y) => x >= 0 && y >= 0 && x < N && y < b * 1.05 : (x, y) => (x < b * 1.05 || y < b * 1.05) && x >= 0 && y >= 0 && x < N && y < N;
  const pieces = [];
  for (const cls of [2, 3]) {
    const lab = new Int32Array(N * N).fill(-1);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
      if (lab[y * N + x] >= 0 || !inL(x, y) || at(x, y) !== cls) continue;
      const id = pieces.length, comp = [], q = [[x, y]]; lab[y * N + x] = id;
      while (q.length) { const [px, py] = q.pop(); comp.push([px, py]);
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = px + dx, ny = py + dy;
          if (nx < 0 || ny < 0 || nx >= N || ny >= N || lab[ny * N + nx] >= 0 || !inL(nx, ny) || at(nx, ny) !== cls) continue; lab[ny * N + nx] = id; q.push([nx, ny]); } }
      if (comp.length < 0.02 * b * b) { pieces.push(null); continue; }
      pieces.push({ cls, comp, lab: id });
    }
    // skeleton per component (Zhang-Suen on a local bitmap)
    pieces.forEach((p, id) => {
      if (!p || p.cls !== cls || p.skel) return;
      let x0 = 1e9, y0 = 1e9, x1 = -1, y1 = -1; p.comp.forEach(([x, y]) => { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); });
      const W2 = x1 - x0 + 3, H2 = y1 - y0 + 3, B = new Uint8Array(W2 * H2);
      p.comp.forEach(([x, y]) => { B[(y - y0 + 1) * W2 + x - x0 + 1] = 1; });
      const nb = (i) => { const x = i % W2, y = (i / W2) | 0; return [B[(y - 1) * W2 + x], B[(y - 1) * W2 + x + 1], B[y * W2 + x + 1], B[(y + 1) * W2 + x + 1], B[(y + 1) * W2 + x], B[(y + 1) * W2 + x - 1], B[y * W2 + x - 1], B[(y - 1) * W2 + x - 1]]; };
      let changed = true;
      while (changed) { changed = false;
        for (const step of [0, 1]) { const del = [];
          for (let y = 1; y < H2 - 1; y++) for (let x = 1; x < W2 - 1; x++) { const i = y * W2 + x; if (!B[i]) continue;
            const P = nb(i), s = P.reduce((a, v) => a + v, 0); if (s < 2 || s > 6) continue;
            let t = 0; for (let k = 0; k < 8; k++) if (!P[k] && P[(k + 1) % 8]) t++; if (t !== 1) continue;
            if (step === 0 ? (P[0] * P[2] * P[4] || P[2] * P[4] * P[6]) : (P[0] * P[2] * P[6] || P[0] * P[4] * P[6])) continue;
            del.push(i); }
          del.forEach(i => { B[i] = 0; }); if (del.length) changed = true; } }
      const pts = []; for (let i = 0; i < B.length; i++) if (B[i]) pts.push(i);
      const set = new Set(pts), adj = i => { const out = []; const x = i % W2, y = (i / W2) | 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { if (!dx && !dy) continue; const j = (y + dy) * W2 + x + dx; if (set.has(j)) out.push(j); } return out; };
      const bfs = s => { const d = new Map([[s, 0]]), par = new Map(), q = [s]; let last = s; while (q.length) { const u = q.shift(); last = u; for (const v of adj(u)) if (!d.has(v)) { d.set(v, d.get(u) + 1); par.set(v, u); q.push(v); } } return { last, par }; };
      if (!pts.length) return;
      const a = bfs(pts[0]).last, r = bfs(a); let u = r.last; const path = [];
      while (u !== undefined) { path.push([(u % W2) + x0 - 1, ((u / W2) | 0) + y0 - 1]); u = r.par.get(u); }
      // smooth + to band units
      const sm = path.map((q, i) => { let sx = 0, sy = 0, n = 0; for (let k = Math.max(0, i - 3); k <= Math.min(path.length - 1, i + 3); k++) { sx += path[k][0]; sy += path[k][1]; n++; } return [sx / n / b, sy / n / b]; });
      p.skel = sm;
      // a short straight piece (a bar between two crossings) can thin to a dot: use its principal axis
      let mx = 0, my = 0; p.comp.forEach(q => { mx += q[0]; my += q[1]; }); mx /= p.comp.length; my /= p.comp.length;
      let sxx = 0, syy = 0, sxy = 0; p.comp.forEach(q => { const dx = q[0] - mx, dy = q[1] - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy; });
      const th = 0.5 * Math.atan2(2 * sxy, sxx - syy), ux = Math.cos(th), uy = Math.sin(th);
      let lo = 1e9, hi = -1e9, wlo = 1e9, whi = -1e9; p.comp.forEach(q => { const t = (q[0] - mx) * ux + (q[1] - my) * uy, s2 = -(q[0] - mx) * uy + (q[1] - my) * ux; lo = Math.min(lo, t); hi = Math.max(hi, t); wlo = Math.min(wlo, s2); whi = Math.max(whi, s2); });
      const hw = (whi - wlo) / 2;
      if (sm.length * 1.0 < 0.6 * (hi - lo)) {
        const a0 = lo + hw, a1 = hi - hw, n = Math.max(4, Math.round(a1 - a0)), line = [];
        for (let k = 0; k <= n; k++) { const t = a0 + (a1 - a0) * k / n; line.push([(mx + 0.5 + ux * t) / b, (my + 0.5 + uy * t) / b]); }
        p.skel = line; p.pca = true;
      }
    });
  }
  const P = pieces.filter(p => p && p.skel && p.skel.length > 3);
  console.log('pieces', P.length);
  // endpoints with outward tangents
  const ends = [];
  P.forEach((p, i) => { const s = p.skel, n = s.length, k = Math.min(n - 1, Math.round(0.12 * b));
    const t0 = norm([s[0][0] - s[k][0], s[0][1] - s[k][1]]), t1 = norm([s[n - 1][0] - s[n - 1 - k][0], s[n - 1][1] - s[n - 1 - k][1]]);
    ends.push({ i, e: 0, p: s[0], t: t0 }, { i, e: 1, p: s[n - 1], t: t1 }); });
  function norm(v) { const l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; }
  // gap bridging: same colour, end tangents point at each other
  const cand = [];
  for (let a = 0; a < ends.length; a++) for (let bI = a + 1; bI < ends.length; bI++) {
    const A = ends[a], Bn = ends[bI]; if (A.i === Bn.i || P[A.i].cls !== P[Bn.i].cls) continue;
    const d = [Bn.p[0] - A.p[0], Bn.p[1] - A.p[1]], L = Math.hypot(d[0], d[1]); if (L < 0.05 || L > 0.85) continue;
    const u = [d[0] / L, d[1] / L], ca = A.t[0] * u[0] + A.t[1] * u[1], cb = -(Bn.t[0] * u[0] + Bn.t[1] * u[1]);
    if (ca < 0.5 || cb < 0.5) continue;
    let bg = 0; for (let k = 1; k < 20; k++) { const X = Math.round((A.p[0] + d[0] * k / 20) * b), Y = Math.round((A.p[1] + d[1] * k / 20) * b); if (X >= 0 && Y >= 0 && X < N && Y < N && at(X, Y) === 0) bg++; }
    if (bg > 4) continue;                            // a gap under an over strand never crosses open ground
    cand.push({ a, b: bI, cost: L * (3 - ca - cb) + 0.05 * bg });
  }
  cand.sort((x, y) => x.cost - y.cost);
  const link = new Map();
  // links read off the full-resolution art where the tangent heuristic is ambiguous (FORCE="x,y:x,y;...")
  (process.env.FORCE || '').split(';').filter(Boolean).forEach(pr => {
    const [p, q] = pr.split(':').map(t => t.split(',').map(Number));
    const near = pt => { let bi = -1, bd = 1e9; ends.forEach((E, k) => { const d = Math.hypot(E.p[0] - pt[0], E.p[1] - pt[1]); if (d < bd) { bd = d; bi = k; } }); return bi; };
    const a1 = near(p), b1 = near(q); link.set(a1, b1); link.set(b1, a1);
  });
  cand.forEach(cn => { if (link.has(cn.a) || link.has(cn.b)) return; link.set(cn.a, cn.b); link.set(cn.b, cn.a); });
  if (process.env.DBG) ends.forEach((A, a) => { if (link.has(a)) return; const near = [];
    ends.forEach((Bn, bI) => { if (bI === a || Bn.i === A.i || P[A.i].cls !== P[Bn.i].cls) return; const d = [Bn.p[0] - A.p[0], Bn.p[1] - A.p[1]], L = Math.hypot(d[0], d[1]); if (L > 1.2) return;
      const u = [d[0] / L, d[1] / L], ca = A.t[0] * u[0] + A.t[1] * u[1], cb = -(Bn.t[0] * u[0] + Bn.t[1] * u[1]);
      let bg = 0; for (let k = 1; k < 20; k++) { const X = Math.round((A.p[0] + d[0] * k / 20) * b), Y = Math.round((A.p[1] + d[1] * k / 20) * b); if (X >= 0 && Y >= 0 && X < N && Y < N && at(X, Y) === 0) bg++; }
      near.push(`${bI}(${Bn.p.map(v => v.toFixed(2))}) L${L.toFixed(2)} ca${ca.toFixed(2)} cb${cb.toFixed(2)} bg${bg}${link.has(bI) ? ' LINKED' : ''}`); });
    console.log('free end', a, 'cls', P[A.i].cls, A.p.map(v => v.toFixed(2)).join(','), 't', A.t.map(v => v.toFixed(2)).join(','), '|', near.join(' ; ')); });
  // chains
  const used = new Set(), chains = [];
  const endIdx = (i, e) => 2 * P.indexOf(P[i]) + e;
  ends.forEach((E, k) => {
    if (used.has(E.i) || link.has(k)) return;        // start from free ends
    let i = E.i, e = E.e, pts = [], cls = P[i].cls;
    while (true) { used.add(i); const s = e === 0 ? P[i].skel : P[i].skel.slice().reverse(); pts = pts.concat(s);
      const other = 2 * i + (1 - e), nx = link.get(other); if (nx == null) break; const N2 = ends[nx]; if (used.has(N2.i)) break; i = N2.i; e = N2.e; }
    chains.push({ cls, pts });
  });
  P.forEach((p, i) => { if (!used.has(i)) chains.push({ cls: p.cls, pts: p.skel, loose: true }); });
  // clip each chain to the L domain between the in-port line (y = ARM, x < 1) and out-port line (x = ARM, y < 1)
  const paths = [];
  chains.forEach(ch => {
    const q = ch.pts; let cur = null, startSide = null;
    for (let k = 1; k < q.length; k++) {
      const a = q[k - 1], bq = q[k];
      const cutIn = (a[1] - ARM) * (bq[1] - ARM) <= 0 && a[1] !== bq[1] && Math.min(a[0], bq[0]) < 1.1;
      const cutOut = (a[0] - ARM) * (bq[0] - ARM) <= 0 && a[0] !== bq[0] && Math.min(a[1], bq[1]) < 1.1;
      if (cutIn || cutOut) {
        const f = cutIn ? (ARM - a[1]) / (bq[1] - a[1]) : (ARM - a[0]) / (bq[0] - a[0]), X = [a[0] + f * (bq[0] - a[0]), a[1] + f * (bq[1] - a[1])];
        const side = cutIn ? 'in' : 'out';
        if (cur) { cur.push(X); paths.push({ cls: ch.cls, pts: cur, a: startSide, b: side }); cur = null; }
        else { const inside = cutIn ? bq[1] < ARM : bq[0] < ARM; if (inside) { cur = [X]; startSide = side; } }
        continue;
      }
      if (cur) cur.push(bq);
    }
  });
  if (END) {                                       // end: every chain clipped to U < ARM; ends 'out' (port) or inside
    const ep = [];
    chains.forEach(ch => { let cur = null, sa = null; const q = ch.pts;
      if (q[0][0] < ARM) { cur = [q[0]]; sa = 'in'; }
      for (let k = 1; k < q.length; k++) { const a = q[k - 1], bq = q[k];
        if ((a[0] - ARM) * (bq[0] - ARM) <= 0 && a[0] !== bq[0]) { const f = (ARM - a[0]) / (bq[0] - a[0]), X = [ARM, a[1] + f * (bq[1] - a[1])];
          if (cur) { cur.push(X); ep.push({ cls: ch.cls, pts: cur, a: sa, b: 'port' }); cur = null; } else { cur = [X]; sa = 'port'; } continue; }
        if (cur) cur.push(bq); }
      if (cur && cur.length > 2) ep.push({ cls: ch.cls, pts: cur, a: sa, b: 'in' }); });
    ep.forEach(p => console.log('end path', p.cls, p.a + '-' + p.b, p.pts.length, p.pts[0].map(v => v.toFixed(3)).join(','), '->', p.pts[p.pts.length - 1].map(v => v.toFixed(3)).join(',')));
    paths.length = 0; ep.forEach(p => paths.push(p));
  }
  const tilePaths = paths.filter(p => END || p.a !== p.b).map(p => {
    let pts = p.pts, a = p.a, bb = p.b;
    if (p.a === 'out' || (END && p.a === 'in' && p.b === 'port')) { pts = pts.slice().reverse(); a = p.b; bb = p.a; }
    return END ? { c: p.cls === 2 ? 0 : 1, a, b: bb, pts } : { c: p.cls === 2 ? 0 : 1, pts };
  });
  chains.forEach((ch, k) => console.log('chain', k, ch.cls, ch.loose ? 'loose' : '', ch.pts.length, ch.pts[0].map(v => v.toFixed(2)).join(','), '->', ch.pts[ch.pts.length - 1].map(v => v.toFixed(2)).join(',')));
  console.log('chains', chains.length, 'paths', paths.map(p => p.a + '-' + p.b + ':' + p.pts.length).join(' '));
  tilePaths.forEach(tp => console.log('c' + tp.c, 'in', tp.pts[0].map(v => v.toFixed(3)).join(','), 'out', tp.pts[tp.pts.length - 1].map(v => v.toFixed(3)).join(',')));
  fs.writeFileSync(OUT, JSON.stringify({ arm: ARM, paths: tilePaths, chains: chains.map(c => ({ cls: c.cls, loose: !!c.loose, pts: c.pts })) }));
  // overlay picture (4x)
  const S = 4, pw = N * S, img = new PNG({ width: pw, height: pw });
  for (let y = 0; y < pw; y++) for (let x = 0; x < pw; x++) { const v = at((x / S) | 0, (y / S) | 0), col = [[244, 234, 210], [60, 60, 60], [150, 175, 235], [235, 180, 205]][v] || [255, 255, 255]; img.data.set([...col, 255], (y * pw + x) * 4); }
  const dot = (x, y, col, r) => { r = r || 1; x = Math.round(x * b * S); y = Math.round(y * b * S); for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) { const X = x + dx, Y = y + dy; if (X >= 0 && Y >= 0 && X < pw && Y < pw) img.data.set([...col, 255], (Y * pw + X) * 4); } };
  const line = (pts, col, r) => { for (let k = 1; k < pts.length; k++) { const a = pts[k - 1], c2 = pts[k], n = Math.ceil(Math.hypot(c2[0] - a[0], c2[1] - a[1]) * b * S); for (let t = 0; t <= n; t++) dot(a[0] + (c2[0] - a[0]) * t / n, a[1] + (c2[1] - a[1]) * t / n, col, r); } };
  chains.forEach(ch => line(ch.pts, ch.loose ? [0, 160, 0] : [90, 90, 90], 1));
  tilePaths.forEach(tp => line(tp.pts, tp.c ? [200, 0, 80] : [0, 40, 200], 2));
  ends.forEach(E => dot(E.p[0], E.p[1], [255, 140, 0], 3));
  line([[ARM, 0], [ARM, N / b]], [0, 0, 0], 0); if (!END) line([[0, ARM], [N / b, ARM]], [0, 0, 0], 0);
  fs.writeFileSync(OUT.replace(/\.json$/, '.png'), PNG.sync.write(img));
}
async function makeTile(tracedF, bestF, outF, lam, phase) {
  const T = JSON.parse(fs.readFileSync(tracedF)), best = JSON.parse(fs.readFileSync(bestF));

  const ref = await KM.getRef(KM.DEFAULT_REF), b = ref.m.band, O = [ref.m.inset, ref.m.inset];
  const paths = T.paths.map(p => ({ c: p.c, pts: smooth(resample(p.pts, 0.02), 3, 4) }));
  // over seed: first crossing between a c0 and a c1 path; the colour Ash shows there is the over strand
  let over = null;
  for (let a = 0; a < paths.length && !over; a++) for (let q = 0; q < paths.length && !over; q++) {
    if (paths[a].c !== 0 || paths[q].c !== 1) continue;
    const A = paths[a].pts, B = paths[q].pts;
    for (let i = 0; i < A.length - 1 && !over; i++) for (let j = 0; j < B.length - 1; j++) {
      const p = A[i], r = [A[i + 1][0] - p[0], A[i + 1][1] - p[1]], s0 = B[j], s = [B[j + 1][0] - s0[0], B[j + 1][1] - s0[1]];
      const den = r[0] * s[1] - r[1] * s[0]; if (Math.abs(den) < 1e-12) continue;
      const t = ((s0[0] - p[0]) * s[1] - (s0[1] - p[1]) * s[0]) / den, u = ((s0[0] - p[0]) * r[1] - (s0[1] - p[1]) * r[0]) / den;
      if (t < 0 || t > 1 || u < 0 || u > 1) continue;
      const X = Math.round((p[0] + t * r[0]) * b + O[0]), Y = Math.round((p[1] + t * r[1]) * b + O[1]), cls = ref.cm.c[Y * ref.cm.w + X];
      over = cls === 2 ? [a, q] : cls === 3 ? [q, a] : null; if (over) console.log('seed crossing', ((X - O[0]) / b).toFixed(2), ((Y - O[1]) / b).toFixed(2), 'class', cls, 'over', over); break;
    }
  }
  const tile = { notes: "Traced from Ash's TL corner centrelines (knot.svg raster skeleton, gaps bridged across the over strands; three ambiguous links read off the full-resolution art).",
    lam: +lam, arm: T.arm, phase: +phase, over: over || [0, 1],
    paths: paths.map(p => ({ c: p.c, d: 'M ' + p.pts.map(q => q[0].toFixed(4) + ' ' + q[1].toFixed(4)).join(' L ') })) };
  const init = Object.assign({}, best, { stage: 'corner', cornerTile: { name: best.cornerTile.name, family: best.cornerTile.family, tile } });
  fs.writeFileSync(outF, JSON.stringify(init));
  console.log('paths', tile.paths.length, 'in', paths.map(p => p.pts[0][0].toFixed(3)).join(','), 'out', paths.map(p => p.pts[p.pts.length - 1][1].toFixed(3)).join(','));
}
function resample(pts, ds) { const out = [pts[0]]; let acc = 0; for (let i = 1; i < pts.length; i++) { const a = pts[i - 1], b = pts[i]; let L = Math.hypot(b[0] - a[0], b[1] - a[1]), t0 = 0; while (acc + L - t0 >= ds) { const t = t0 + ds - acc; const f = t / L; out.push([a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f]); t0 = t; acc = 0; } acc += L - t0; } out.push(pts[pts.length - 1]); return out; }
function smooth(pts, k, it) { let p = pts; for (let r = 0; r < it; r++) p = p.map((q, i) => { if (i === 0 || i === p.length - 1) return q; let sx = 0, sy = 0, n = 0; for (let j = Math.max(0, i - k); j <= Math.min(p.length - 1, i + k); j++) { sx += p[j][0]; sy += p[j][1]; n++; } return [sx / n, sy / n]; }); return p; }
