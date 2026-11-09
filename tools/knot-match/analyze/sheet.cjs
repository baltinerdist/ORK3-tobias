'use strict';
// sheet.cjs -- zoomed review sheets: ours | reference | overlay, per region.
// Overlay colours: ink in both = black, ref-only ink = red, our-only ink = blue; fill in both = light grey,
// fill in one only = pale red (ref) / pale blue (ours).
// usage: node --no-maglev sheet.cjs <ref.png> <seed.json> <params.json> <outdir> [zoom]
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { PNG } = require('pngjs');
const G = require('./gen.cjs'), SC = require('./score.cjs');

function writePng(file, w, h, px) { const png = new PNG({ width: w, height: h }); png.data.set(px); fs.writeFileSync(file, PNG.sync.write(png)); }

async function sheets(refFile, seed, P, outDir, zoom, opt) {
	opt = opt || {};
	fs.mkdirSync(outDir, { recursive: true });
	const ctx = SC.makeRefCtx(refFile, seed), W = ctx.ref.w, H = ctx.ref.h, AH = seed.frame.H, AW = opt.AW || AH;
	const b = G.build(seed, P, { AW, AH, W, H, colours: { ink: '#1a1a1a', fill: '#ffffff' } });
	const ours = path.join(outDir, 'ours.png'); fs.writeFileSync(path.join(outDir, 'ours.svg'), b.svg);
	execFileSync('rsvg-convert', ['-w', String(W), '-h', String(H), '-b', '#d8d8d8', '-o', ours, path.join(outDir, 'ours.svg')]);
	const om = await SC.classOf(G.build(seed, P, { AW, AH, W, H }).svg, W, H), rc = ctx.ref.c;
	const ov = new Uint8Array(W * H * 4);
	for (let i = 0; i < W * H; i++) {
		const r = rc[i], o = om.c[i]; let col;
		if (r === 1 && o === 1) { col = [0, 0, 0]; } else if (r === 1) { col = [220, 30, 30]; } else if (o === 1) { col = [30, 80, 230]; }
		else if (r === 2 && o === 2) { col = [225, 225, 225]; } else if (r === 2) { col = [250, 185, 185]; } else if (o === 2) { col = [185, 205, 250]; } else { col = [255, 255, 255]; }
		ov.set([col[0], col[1], col[2], 255], i * 4);
	}
	const ovFile = path.join(outDir, 'overlay.png'); writePng(ovFile, W, H, ov);
	const files = [];
	ctx.R.forEach(r => {
		const cw = r.x1 - r.x0, ch = Math.min(r.y1 - r.y0, 420), geo = cw + 'x' + ch + '+' + r.x0 + '+' + r.y0;
		const crop = (src, tag) => { const f = path.join(outDir, r.name + '-' + tag + '.png'); execFileSync('convert', [src, '-crop', geo, '+repage', '-filter', 'point', '-resize', (zoom * 100) + '%', f]); return f; };
		const a = crop(ours, 'ours'), c = crop(refFile, 'ref'), d = crop(ovFile, 'overlay');
		const out = path.join(outDir, 'sheet-' + r.name + '.png');
		execFileSync('convert', [a, c, d, '-background', '#888', '-splice', '6x0', '+append', out]);
		files.push(out);
	});
	return files;
}
module.exports = { sheets };

if (require.main === module) {
	const [ref, seedFile, pFile, outDir, z] = process.argv.slice(2);
	const seed = JSON.parse(fs.readFileSync(seedFile, 'utf8')), P = JSON.parse(fs.readFileSync(pFile, 'utf8'));
	sheets(ref, seed, P, outDir, +(z || 3)).then(f => console.log(f.join('\n')));
}
