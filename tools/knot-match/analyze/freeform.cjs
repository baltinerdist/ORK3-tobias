'use strict';
// freeform.cjs -- read a FREE-FORM corner knot (curves that do not sit on a crossing lattice) as one traced
// centreline with its crossings, for borders whose sides are plain straight strands and whose corners are knots.
//
// Walker: start on a side strand outside the corner, step 1 px along the strand, re-centre on the ridge of the
// distance to non-fill (inside the current fill region only), and steer by the recent heading. A fill fragment
// ends only where the strand passes UNDER another: there the walker marches straight on through ink, the over
// strand's fill and ink again, and lands on the next fragment (a jump = an under-crossing). It stops on the other
// side strand. The polyline is smoothed, its self-intersections are the crossings, and the jumps say which pass
// is under at each.
const IM = require('./image.cjs');
const { CLS } = IM;

function fillDT(cm) { const m = new Uint8Array(cm.w * cm.h); for (let i = 0; i < m.length; i++) { m[i] = cm.c[i] === CLS.FILL ? 0 : 1; } return IM.edt(m, cm.w, cm.h); }

function trace(cm, start, dir, stop, opt) {
	opt = opt || {};
	const W = cm.w, H = cm.h, D = opt.dt || fillDT(cm);
	// regions of the fill ERODED by 1 px: anti-aliasing can leave a 1 px bridge between two strands' fills where
	// an outline thins out, which would let the walker slide from one strand onto another
	const core = new Uint8Array(W * H); for (let i = 0; i < W * H; i++) { core[i] = cm.c[i] === CLS.FILL && D[i] > 1.01 ? 1 : 0; }
	const lab = IM.components(core, W, H).lab;
	const cls = (x, y) => { const X = Math.round(x), Y = Math.round(y); return X < 0 || Y < 0 || X >= W || Y >= H ? CLS.GROUND : core[Y * W + X] ? CLS.FILL : cm.c[Y * W + X] === CLS.FILL ? CLS.INK : cm.c[Y * W + X]; };
	const reg = (x, y) => lab[Math.round(y) * W + Math.round(x)];
	const dAt = (x, y) => { const X = Math.round(x), Y = Math.round(y); return X < 0 || Y < 0 || X >= W || Y >= H ? 0 : D[Y * W + X]; };
	let p = start.slice(), d = norm(dir), r = reg(p[0], p[1]);
	const pts = [p.slice()], jumps = [];
	for (let it = 0; it < (opt.maxSteps || 4000); it++) {
		let q = [p[0] + d[0], p[1] + d[1]];
		// the strand bends: before calling this a fragment end, try turning up to 40 degrees within the same region
		if (!(cls(q[0], q[1]) === CLS.FILL && reg(q[0], q[1]) === r)) {
			let bestB = null;
			for (let ag = -60; ag <= 60; ag += 5) {
				if (!ag) { continue; }
				const c = Math.cos(ag * Math.PI / 180), sn = Math.sin(ag * Math.PI / 180), u = [d[0] * c - d[1] * sn, d[0] * sn + d[1] * c];
				const q2 = [p[0] + u[0] * 2, p[1] + u[1] * 2];
				if (cls(q2[0], q2[1]) !== CLS.FILL || reg(q2[0], q2[1]) !== r || dAt(q2[0], q2[1]) < 2) { continue; }
				const v = dAt(q2[0], q2[1]) - 0.02 * Math.abs(ag);
				if (!bestB || v > bestB.v) { bestB = { v, u }; }
			}
			if (bestB) { d = bestB.u; q = [p[0] + d[0], p[1] + d[1]]; }
		}
		if (cls(q[0], q[1]) === CLS.FILL && reg(q[0], q[1]) === r) {
			// re-centre across the heading, within this region, preferring small moves
			const n = [-d[1], d[0]]; let best = null;
			for (let t = -2.5; t <= 2.5; t += 0.5) { const x = q[0] + n[0] * t, y = q[1] + n[1] * t; if (cls(x, y) !== CLS.FILL || reg(x, y) !== r) { continue; } const v = dAt(x, y) - 0.15 * Math.abs(t); if (!best || v > best.v) { best = { v, x, y }; } }
			const np = best ? [best.x, best.y] : q;
			// heading: blend of the old heading and the move, over the last few points
			const back = pts[Math.max(0, pts.length - 4)], h = norm([np[0] - back[0], np[1] - back[1]]);
			d = norm([0.6 * d[0] + 0.4 * h[0], 0.6 * d[1] + 0.4 * h[1]]);
			p = np; pts.push(p.slice());
		} else {
			// fragment end: march on to the fragment beyond the over strand
			const back = pts[Math.max(0, pts.length - 6)], h = norm([p[0] - back[0], p[1] - back[1]]);
			// march straight on; where the strand curves into the crossing, fan the ray out (smallest deflection
			// first) until it passes one other fill region (the over strand) and lands on a third
			let land = null, over = null, hd = h;
			const angs = [0]; for (let a = 5; a <= 40; a += 5) { angs.push(a, -a); }
			for (const ag of angs) {
				const c = Math.cos(ag * Math.PI / 180), sn = Math.sin(ag * Math.PI / 180), u = [h[0] * c - h[1] * sn, h[0] * sn + h[1] * c];
				const seq = [];
				for (let t = 0.5; t <= (opt.maxJump || 18); t += 0.5) {
					const x = p[0] + u[0] * t, y = p[1] + u[1] * t, cc = cls(x, y), raw = cm.c[Math.round(y) * W + Math.round(x)];
					const k = cc === CLS.FILL ? 'F' + reg(x, y) : raw === CLS.FILL ? 'R' : cc === CLS.INK ? 'I' : 'G';   // R = eroded rim
					if (k === 'G') { break; }
					if (!seq.length || seq[seq.length - 1].k !== k) { seq.push({ k, t, x, y }); }
					const fills = seq.filter(z => z.k[0] === 'F' && z.k !== 'F' + r);
					// a short break in one strand (erosion / anti-aliasing): another fill within 3.5 px, straight on
					if (fills.length === 1 && fills[0].t <= 3.5 && Math.abs(ag) <= 15 && !seq.some(z => z.k === 'I')) { land = fills[0]; over = null; break; }
					// the landing fragment must be a different strand piece from both this one and the over strand
					// in the UN-eroded labels too (an anti-aliasing bridge can join the over strand to this one)
					if (fills.length >= 2) {
						const L0 = cm.lab, li = z => L0[Math.round(z.y) * W + Math.round(z.x)], here = L0[Math.round(p[1]) * W + Math.round(p[0])];
						const cand = fills.slice(1).find(z => li(z) !== here && li(z) !== li(fills[0]));
						if (cand) { land = cand; over = fills[0]; break; }
						if (fills.length >= 4) { break; }
					}
				}
				if (land) { hd = u; break; }
			}
			if (!land) { return { pts, jumps, stopped: 'lost at ' + p.map(v => v.toFixed(1)).join(',') }; }
			h[0] = hd[0]; h[1] = hd[1];
			const steps = Math.ceil(land.t + 1);
			for (let k = 1; k <= steps; k++) { pts.push([p[0] + h[0] * k, p[1] + h[1] * k]); }
			if (over) { jumps.push({ at: pts.length - 1 - Math.round(steps / 2), x: (p[0] + land.x) / 2, y: (p[1] + land.y) / 2, overRegion: +over.k.slice(1) }); }
			// settle on the landing fragment's ridge (the march can end on its rim)
			const lr = reg(land.x, land.y); let bs = null;
			for (let dy = -3; dy <= 3; dy++) { for (let dx = -3; dx <= 3; dx++) { const x = Math.round(land.x) + dx, y = Math.round(land.y) + dy; if (cls(x, y) !== CLS.FILL || reg(x, y) !== lr) { continue; } const v = dAt(x, y) - 0.3 * Math.hypot(dx, dy); if (!bs || v > bs.v) { bs = { v, x, y }; } } }
			p = bs ? [bs.x, bs.y] : [land.x, land.y]; pts.push(p.slice()); d = h; r = lr;
		}
		if (stop(p, d)) { return { pts, jumps, stopped: null }; }
	}
	return { pts, jumps, stopped: 'step limit' };
}

function norm(v) { const l = Math.hypot(v[0], v[1]) || 1; return [v[0] / l, v[1] / l]; }

// gaussian smoothing of an open polyline (ends held)
function smooth(pts, sigma) {
	const n = pts.length, R = Math.ceil(3 * sigma), out = [];
	for (let i = 0; i < n; i++) {
		if (i < 2 || i > n - 3) { out.push(pts[i].slice()); continue; }
		let sx = 0, sy = 0, sw = 0; for (let k = -R; k <= R; k++) { const j = Math.min(n - 1, Math.max(0, i + k)), w = Math.exp(-k * k / (2 * sigma * sigma)); sx += pts[j][0] * w; sy += pts[j][1] * w; sw += w; }
		out.push([sx / sw, sy / sw]);
	}
	return out;
}
// resample at equal arc length
function resample(pts, step) {
	const out = [pts[0].slice()]; let carry = 0;
	for (let i = 1; i < pts.length; i++) {
		const a = pts[i - 1], b = pts[i], L = Math.hypot(b[0] - a[0], b[1] - a[1]); let t = step - carry;
		while (t <= L) { out.push([a[0] + (b[0] - a[0]) * t / L, a[1] + (b[1] - a[1]) * t / L]); t += step; }
		carry = L - (t - step);
	}
	const last = pts[pts.length - 1]; if (Math.hypot(last[0] - out[out.length - 1][0], last[1] - out[out.length - 1][1]) > step * 0.3) { out.push(last.slice()); }
	return out;
}
// self-intersections of a polyline: [{i, j, ti, tj, x, y}] with i < j segment indices
function selfCross(pts) {
	const out = [];
	for (let i = 0; i < pts.length - 1; i++) {
		for (let j = i + 2; j < pts.length - 1; j++) {
			const a = pts[i], b = pts[i + 1], c = pts[j], d = pts[j + 1];
			const den = (b[0] - a[0]) * (d[1] - c[1]) - (b[1] - a[1]) * (d[0] - c[0]); if (Math.abs(den) < 1e-12) { continue; }
			const t = ((c[0] - a[0]) * (d[1] - c[1]) - (c[1] - a[1]) * (d[0] - c[0])) / den, u = ((c[0] - a[0]) * (b[1] - a[1]) - (c[1] - a[1]) * (b[0] - a[0])) / den;
			if (t >= 0 && t < 1 && u >= 0 && u < 1) { out.push({ i, j, ti: t, tj: u, x: a[0] + t * (b[0] - a[0]), y: a[1] + t * (b[1] - a[1]) }); }
		}
	}
	return out;
}

module.exports = { trace, smooth, resample, selfCross, fillDT, norm };
