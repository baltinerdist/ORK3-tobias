// expt2/lib.cjs: shared helpers (V13 tool + engine, read-only). Scale s: raster = 1275*s x 1650*s.
const fs = require('fs'), path = require('path');
const T = process.env.TOOL || path.join(__dirname, '..', 'knotmatch.cjs');
const E = process.env.ENG;   // the merged engine's scroll-knot.js (knot-v6-engine line); required
if (!E) { throw new Error('set ENG=<path to the merged engine scroll-knot.js>'); }
const KM = require(T);
const PAL = { bg: '#f4ead2', A: '#2a5bd7', B: '#e06aa0' };
function ashSvg(sh, mirror) {   // sh: [dx,dy] in 1x raster px; mirror: L-R flip of the page
	const src = fs.readFileSync(KM.DEFAULT_REF, 'utf8');
	const body = src.split('-->').slice(1).join('-->').replace(/<\/svg>\s*$/, '');
	const k = 2550 / 1275, tx = (sh ? sh[0] : 0) * k, ty = (sh ? sh[1] : 0) * k;
	const g0 = '<g transform="translate(' + tx + ' ' + ty + ')' + (mirror ? ' translate(2550 0) scale(-1 1)' : '') + '">';
	return '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 2550 3300" width="2550" height="3300"><rect width="2550" height="3300" fill="' + PAL.bg + '"/>' + g0 +
		body.split('var(--knot-c1)').join(PAL.A).split('var(--knot-c2)').join(PAL.B) + '<use href="#Knot-Band-1"/><use href="#Knot-Band-2"/></g></svg>';
}
function oursText(b) {
	const K = KM.loadEngine(E, KM.buildOverrides({ consts: b.consts || {}, cornerTile: b.cornerTile, endTile: b.endTile }));
	const s = KM.renderSvg(K, b.cfg); return typeof s === 'string' ? s : s.ser();
}
function shiftSvg(t, sh) {   // ours (viewBox 816 wide): shift by sh 1x raster px
	if (!sh || (!sh[0] && !sh[1])) { return t; }
	const k = 816 / 1275; return t.replace('<g>', '<g transform="translate(' + (sh[0] * k).toFixed(5) + ' ' + (sh[1] * k).toFixed(5) + ')">');
}
async function cm(svg, s) { return KM.classMap(await KM.rasterize(svg, Math.round(1275 * s), Math.round(1650 * s))); }
let M1 = null;
async function m1() { if (!M1) { M1 = (await KM.getRef(KM.DEFAULT_REF)).m; } return M1; }
async function regions(s) {
	const m = await m1(), out = {};
	const sc = r => Object.assign({}, r, { x0: Math.round(r.x0 * s), x1: Math.round(r.x1 * s), y0: Math.round(r.y0 * s), y1: Math.round(r.y1 * s) });
	KM.regionsFor('side', m).forEach(r => { out[r.name] = sc(r); });
	out.TL = sc(KM.regionsFor('corner', m).find(r => r.name === 'TL'));
	out['top-L'] = sc(KM.regionsFor('end', m).find(r => r.name === 'top-L'));
	out.cap = sc(KM.regionsFor('cap', m)[0]);
	return { R: out, band: m.band * s, m };
}
function score(refCm, ours, r, band) { const ro = { cm: refCm, dts: {} }; return KM.regionScore(refCm, ours, r, band, KM.refDTFor(ro, r)); }
module.exports = { KM, T, E, ashSvg, oursText, shiftSvg, cm, regions, score, m1 };
