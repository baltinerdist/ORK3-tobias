'use strict';
// export-scrollery.cjs -- the Scrollery's Custom Border styles 2-4 as page sprites, in Ash's inked style.
//
// Each sprite is a 2550 x 3300 page (the Scrollery's certificate space) holding two <symbol>s, drawn band 1 then
// band 2, exactly like assets/scrolls/common/knot/knot.svg (style 1, Ash's own Jovious knot). Colour reads the
// page's custom properties so the composer recolours without a round trip:
//   style 2  interlock      band 1 = the loops coloured 1 (fill --knot-c1), band 2 = the loops coloured 2 (--knot-c2)
//   style 3  single, dark   band 1 = the enclosed holes (--knot-c2), band 2 = the strand (--knot-c1)
//   style 4  single, clear  band 1 = the strand (--knot-c1), band 2 empty
// Ink is black. Every under pass is truly cut (gap 0.53 x fill, ink 0.52 x fill per side, square inked cut ends).
//
// Geometry is fitted to Ash's knot on the page: the band's outer box (58, 52)-(2492, 3254), the top opening
// x 1048-1500 and the bottom opening x 976-1572 (measured from knot.svg). The interlock's ends can only sit on
// lattice columns E = 2 or 4 (mod 6), so its openings land on the nearest valid columns; the single strand's
// P-curl openings are set to Ash's widths directly.
//
// usage: node --no-maglev export-scrollery.cjs <outdir>
const fs = require('fs'), path = require('path');
const G = require('./gen.cjs'), FG = require('./ffgen.cjs');

const ASH = { x0: 58, y0: 52, x1: 2492, y1: 3254, topGap: [1048, 1500], bottomGap: [976, 1572] };
// Corner scale for the single-strand styles (3, 4), as a fraction of the scale that fits the art's own frame to
// Ash's box: the box stays put, the sides lengthen, and the corner knots shrink so they clear the scroll's text.
const CORNER = Number(process.env.KNOT_CORNER || 0.6);
const r1 = v => (Math.round(v * 10) / 10).toString();

// polyline pieces from 'M x yLx y...' strings
function parsePoly(d) { const n = (d.match(/-?[\d.]+/g) || []).map(Number), out = []; for (let i = 0; i + 1 < n.length; i += 2) { out.push([n[i], n[i + 1]]); } return out; }
function dp(pts, tol) {   // Douglas-Peucker
	if (pts.length < 3) { return pts; }
	const keep = new Uint8Array(pts.length); keep[0] = keep[pts.length - 1] = 1; const st = [[0, pts.length - 1]];
	while (st.length) {
		const [a, b] = st.pop(); let mi = -1, md = tol;
		const A = pts[a], B = pts[b], L = Math.hypot(B[0] - A[0], B[1] - A[1]) || 1e-9;
		for (let i = a + 1; i < b; i++) { const d = Math.abs((B[0] - A[0]) * (A[1] - pts[i][1]) - (A[0] - pts[i][0]) * (B[1] - A[1])) / L; if (d > md) { md = d; mi = i; } }
		if (mi >= 0) { keep[mi] = 1; st.push([a, mi], [mi, b]); }
	}
	return pts.filter((_, i) => keep[i]);
}
const dOf = (polys, T, closed) => polys.map(p => 'M' + dp(p.map(T), 0.15).map(q => r1(q[0]) + ' ' + r1(q[1])).join('L') + (closed ? 'Z' : '')).join('');
const bboxOf = (polys, pad) => { let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; polys.forEach(p => p.forEach(q => { x0 = Math.min(x0, q[0]); y0 = Math.min(y0, q[1]); x1 = Math.max(x1, q[0]); y1 = Math.max(y1, q[1]); })); return { x0: x0 - pad, y0: y0 - pad, x1: x1 + pad, y1: y1 + pad }; };
const fitTo = b => { const kx = (ASH.x1 - ASH.x0) / (b.x1 - b.x0), ky = (ASH.y1 - ASH.y0) / (b.y1 - b.y0); return { kx, ky, T: q => [ASH.x0 + (q[0] - b.x0) * kx, ASH.y0 + (q[1] - b.y0) * ky] }; };
const circ = (c, r) => 'M' + r1(c[0] - r) + ' ' + r1(c[1]) + 'a' + r1(r) + ' ' + r1(r) + ' 0 1 0 ' + r1(2 * r) + ' 0a' + r1(r) + ' ' + r1(r) + ' 0 1 0 ' + r1(-2 * r) + ' 0Z';

function sprite(id, note, band1, band2) {
	return '<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 2550 3300">\n<!-- ' + note + ' -->\n'
		+ '<symbol id="' + id + '-Band-1" viewBox="0 0 2550 3300">' + band1 + '</symbol>\n'
		+ '<symbol id="' + id + '-Band-2" viewBox="0 0 2550 3300">' + band2 + '</symbol>\n</svg>\n';
}
const inkPath = (d, w) => d ? '<path d="' + d + '" style="fill:none;stroke:#000;stroke-width:' + r1(w) + ';stroke-linecap:butt;stroke-linejoin:round"/>' : '';
const fillPath = (d, w, v) => d ? '<path d="' + d + '" style="fill:none;stroke:var(' + v + ');stroke-width:' + r1(w) + ';stroke-linecap:butt;stroke-linejoin:round"/>' : '';
const solid = (d, fill) => d ? '<path d="' + d + '" style="fill:' + fill + ';fill-rule:evenodd"/>' : '';

// ---- style 2: interlock
function interlock(root) {
	const seed = JSON.parse(fs.readFileSync(path.join(root, 'analyze/seed-two-corners.json'), 'utf8'));
	const P0 = JSON.parse(fs.readFileSync(path.join(root, 'results/interlock/run2/best-params.json'), 'utf8'));
	// band thickness ~ 4 s + 0.94 s of overhang (measured on the generated frame); Ash's band is ~146 px
	const sPage = 29.35, k = sPage / P0.s, fill = 8.5 * k, AW = 82, AH = 106;
	// end-wall columns for Ash's openings: the opening's edge sits ~0.37 s inside column E from the band's outer edge
	const col = x => (x - ASH.x0) / sPage - 0.37, pick = x => { let best = null; for (let E = 8; E < AW / 2 - 4; E++) { if (E % 6 !== 2 && E % 6 !== 4) { continue; } if (best === null || Math.abs(E - col(x)) < Math.abs(best - col(x))) { best = E; } } return best; };
	const Etop = pick(ASH.topGap[0]), Ebot = pick(ASH.bottomGap[0]);
	const P = Object.assign({}, P0, { s: sPage, origin: [200, 200], w: fill, ink: 0.52 * fill });
	const b = G.build(seed, P, { AW, AH, W: 2550, H: 3300, cuts: { top: Etop, bottom: Ebot }, gap: 0.53 * fill, loopColours: ['#c10001', '#c20002'] });
	if (!b.gates.closed || !b.gates.sitesValid || !b.gates.alternates) { throw new Error('interlock gates failed: ' + JSON.stringify(b.gates)); }
	const pc = b.pieces, inkP = pc.ink.map(q => ({ c: pc.colour[q.li], p: parsePoly(q.d) })), fillP = pc.fill.map(q => ({ c: pc.colour[q.li], p: parsePoly(q.d) }));
	const F = fitTo(bboxOf(inkP.map(q => q.p), pc.inkWidth / 2)), wI = pc.inkWidth * (F.kx + F.ky) / 2, wF = pc.fillWidth * (F.kx + F.ky) / 2;
	const band = c => inkPath(dOf(inkP.filter(q => q.c === c).map(q => q.p), F.T), wI) + fillPath(dOf(fillP.filter(q => q.c === c).map(q => q.p), F.T), wF, c ? '--knot-c2' : '--knot-c1');
	const note = 'Scrollery Custom Border style 2 (interlock), generated by tools/knot-match/analyze/export-scrollery.cjs on the knot-match engine. Ash inked style: under passes cut. Band 1 = loops in --knot-c1, band 2 = loops in --knot-c2; ink black. ' + AW + ' x ' + AH + ' lattice sites, openings at columns ' + Etop + ' (top) and ' + Ebot + ' (bottom); fitted to the Jovious knot box (scale ' + F.kx.toFixed(4) + ' x ' + F.ky.toFixed(4) + ').';
	return { svg: sprite('Knot-Interlock', note, band(0), band(1)), info: { Etop, Ebot, loops: b.loops.length, kx: F.kx, ky: F.ky, inkW: wI, fillW: wF } };
}

// ---- styles 3 and 4: single strand with P-curl ends
function single(root, dark) {
	const seed = JSON.parse(fs.readFileSync(path.join(root, 'analyze/seed-single-strand.json'), 'utf8'));
	const Q = JSON.parse(fs.readFileSync(path.join(root, 'results/single-strand/ash-style/params-smoothed-sigma1.json'), 'utf8'));
	// the corner curve's straight leads are snapped exactly onto the side lines: the fit left a sub-pixel waver there,
	// which page scale (x ~6.8) and heavy ink make visible as a jog where a side meets its corner
	const n = Q.pts.length, pts = Q.pts.map((p, i) => {
		if (i < 30 && Math.abs(p[0]) < 1 && p[1] > 45) { return [0, p[1]]; }
		if (i > n - 31 && Math.abs(p[1]) < 1 && p[0] > 45) { return [p[0], 0]; }
		return p.slice();
	});
	const fill = 3.5, P = Object.assign({}, Q, { pts, w: fill, ink: 0.52 * fill });
	const cx = FG.crossingsOf(P, seed); if (!cx.topoOK || cx.count !== seed.corner.crossings) { throw new Error('lead snapping changed the corner topology'); }
	const mk = (Pp, gTop, gBot) => FG.build(seed, Pp, { cuts: { tail: 13, gap: gTop, gapBottom: gBot }, gap: 0.53 * fill, dark, colours: { ink: '#000', fill: '#c10001', dark: '#c20002' } }).parts;
	// pass 1 at the reference's frame: the art's reach beyond each frame line, and the page scale
	let parts = mk(P, 60, 80), bb = bboxOf(parts.ink.map(parsePoly), parts.inkWidth / 2);
	const reach = { L: P.xL - bb.x0, R: bb.x1 - P.xR, T: P.yT - bb.y0, B: bb.y1 - P.yB };
	const k = CORNER * (ASH.x1 - ASH.x0) / (bb.x1 - bb.x0);
	// pass 2: frame lines placed so the art fills Ash's box at scale k (the sides lengthen; the knots keep shape)
	const P2 = Object.assign({}, P, { xL: ASH.x0 / k + reach.L, xR: ASH.x1 / k - reach.R, yT: ASH.y0 / k + reach.T, yB: ASH.y1 / k - reach.B });
	parts = mk(P2, (ASH.topGap[1] - ASH.topGap[0]) / k, (ASH.bottomGap[1] - ASH.bottomGap[0]) / k);
	const T = q => [q[0] * k, q[1] * k], wI = parts.inkWidth * k, wF = parts.fillWidth * k;
	const strand = inkPath(dOf(parts.ink.map(parsePoly), T), wI) + solid(parts.caps.map(c => circ(T(c), wI / 2)).join(''), '#000')
		+ fillPath(dOf(parts.fill.map(parsePoly), T), wF, '--knot-c1') + solid(parts.caps.map(c => circ(T(c), wF / 2)).join(''), 'var(--knot-c1)');
	const holes = solid(dOf(parts.dark.map(d => d.split('Z').map(parsePoly).filter(p => p.length > 2)).flat(), T, true), 'var(--knot-c2)');
	const id = dark ? 'Knot-Single-Dark' : 'Knot-Single', styleNo = dark ? 3 : 4;
	const note = 'Scrollery Custom Border style ' + styleNo + ' (single strand' + (dark ? ', holes filled' : '') + '), generated by tools/knot-match/analyze/export-scrollery.cjs on the knot-match engine. Ash inked style: under passes cut; P-curl ends at the openings. '
		+ (dark ? 'Band 1 = the enclosed holes in --knot-c2, band 2 = the strand in --knot-c1' : 'Band 1 = the strand in --knot-c1, band 2 empty') + '; ink black. Corner scale ' + k.toFixed(4) + '.';
	return { svg: dark ? sprite(id, note, holes, strand) : sprite(id, note, strand, ''), info: { k, frame: [P2.xL * k, P2.yT * k, P2.xR * k, P2.yB * k], inkW: wI, fillW: wF } };
}

// ---- style 3, original look: no cut gaps -- every crossing's over strand repainted solid, holes filled, white
// halo, the curved / straight stroke widths of the matched design (as the darkened-corner examples were drawn)
function singleSolid(root) {
	const seed = JSON.parse(fs.readFileSync(path.join(root, 'analyze/seed-single-strand.json'), 'utf8'));
	const Q = JSON.parse(fs.readFileSync(path.join(root, 'results/single-strand/ash-style/params-smoothed-sigma1.json'), 'utf8'));
	const run2 = JSON.parse(fs.readFileSync(path.join(root, 'results/single-strand/run2/best-params.json'), 'utf8'));
	const n = Q.pts.length, pts = Q.pts.map((p, i) => (i < 30 && Math.abs(p[0]) < 1 && p[1] > 45) ? [0, p[1]] : (i > n - 31 && Math.abs(p[1]) < 1 && p[0] > 45) ? [p[0], 0] : p.slice());
	// matched strokes, no per-side pixel offsets (they were sub-pixel registration to the reference raster)
	const P = Object.assign({}, Q, { pts, w: run2.w, ink: run2.ink, wS: run2.wS, inkS: run2.inkS, halo: 0, offL: 0, offR: 0, offT: 0, offB: 0 });
	const cx = FG.crossingsOf(P, seed); if (!cx.topoOK || cx.count !== seed.corner.crossings) { throw new Error('lead snapping changed the corner topology'); }
	const cuts = (gT, gB) => ({ gap: gT, gapBottom: gB });
	const C = { ink: '#000000', fill: '#c10001', dark: '#c20002', halo: '#ffffff' };
	const reachOf = Pp => { const b = FG.build(seed, Pp, { cuts: cuts(60, 80), colours: C, capLeads: true }); const pad = (Pp.wS + 2 * Pp.inkS) / 2 + Pp.halo; let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; b.d.split(/(?=M)/).filter(x => x.trim()).forEach(sub => G.samplePath(sub).forEach(q => { x0 = Math.min(x0, q[0]); y0 = Math.min(y0, q[1]); x1 = Math.max(x1, q[0]); y1 = Math.max(y1, q[1]); })); return { x0: x0 - pad, y0: y0 - pad, x1: x1 + pad, y1: y1 + pad }; };
	const bb = reachOf(P), k = CORNER * (ASH.x1 - ASH.x0) / (bb.x1 - bb.x0);
	const P2 = Object.assign({}, P, { xL: ASH.x0 / k + (P.xL - bb.x0), xR: ASH.x1 / k - (bb.x1 - P.xR), yT: ASH.y0 / k + (P.yT - bb.y0), yB: ASH.y1 / k - (bb.y1 - P.yB) });
	const b = FG.build(seed, P2, { cuts: cuts((ASH.topGap[1] - ASH.topGap[0]) / k, (ASH.bottomGap[1] - ASH.bottomGap[0]) / k), colours: C, capLeads: true });
	// the generator's paint order (halo, holes, ink, fill, straight runs, crossing patches) kept as one group, scaled
	// to the page; colour attributes become styles so they read the page's custom properties through <use>
	let inner = b.svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '');
	inner = inner.replace(/(stroke|fill)="#c10001"/g, 'style="$1:var(--knot-c1)"').replace(/(stroke|fill)="#c20002"/g, 'style="$1:var(--knot-c2)"');
	const note = 'Scrollery Custom Border style 3 (single strand, holes filled), generated by tools/knot-match/analyze/export-scrollery.cjs on the knot-match engine, in the original darkened-corner look: no cut gaps, every crossing repainted solid, no halo; corners at ' + CORNER + ' of the full-box scale so they clear the text. Strand in --knot-c1, holes in --knot-c2, ink black; drawn as band 1, band 2 empty. Corner scale ' + k.toFixed(4) + '.';
	return { svg: sprite('Knot-Single-Dark', note, '<g transform="scale(' + k.toFixed(5) + ')">' + inner + '</g>', ''), info: { k } };
}

module.exports = { interlock, single, singleSolid, ASH };

if (require.main === module) {
	const out = process.argv[2] || '.', root = path.resolve(__dirname, '..');
	fs.mkdirSync(out, { recursive: true });
	const a = interlock(root), b = singleSolid(root), c = single(root, false);
	fs.writeFileSync(path.join(out, 'knot-interlock.svg'), a.svg);
	fs.writeFileSync(path.join(out, 'knot-single-dark.svg'), b.svg);
	fs.writeFileSync(path.join(out, 'knot-single.svg'), c.svg);
	console.log(JSON.stringify({ interlock: a.info, singleDark: b.info, single: c.info, bytes: [a.svg.length, b.svg.length, c.svg.length] }, null, 1));
}
