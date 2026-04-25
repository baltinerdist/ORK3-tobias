// Foundation drawing primitives shared across all scroll family renderers.
// Mirrors system/lib/ork3/class.ScrollPrimitives.php — keep in sync.
// All primitives consume palette tokens (never hard-coded hex).
window.ScrollPrimitives = (function() {

	// ----------------------------------------------------------------------
	// Gilding gradient — multi-stop linear from dark gold → gold → highlight → gold → dark.
	// Always use this; never paint flat #FFD700.
	// ----------------------------------------------------------------------
	function gildingGradient(ctx, x1, y1, x2, y2, gold, goldHi) {
		const dark = ScrollPalette.darken(gold, 0.30);
		const g = ctx.createLinearGradient(x1, y1, x2, y2);
		g.addColorStop(0.00, dark);
		g.addColorStop(0.35, gold);
		g.addColorStop(0.50, goldHi);
		g.addColorStop(0.65, gold);
		g.addColorStop(1.00, dark);
		return g;
	}

	// ----------------------------------------------------------------------
	// Parchment texture — base + radial vignette + foxing spots + fiber noise.
	// Replaces ad-hoc bg + noise + vignette.
	// ----------------------------------------------------------------------
	let _noiseCache = null;
	function _noisePattern(ctx, bg) {
		if (_noiseCache) return _noiseCache;
		const c = document.createElement('canvas'); c.width = 80; c.height = 80;
		const cx = c.getContext('2d');
		cx.fillStyle = bg; cx.fillRect(0, 0, 80, 80);
		cx.fillStyle = 'rgba(101,79,40,0.04)';
		for (let y = 0; y < 80; y += 2) cx.fillRect(0, y, 80, 1);
		cx.fillStyle = 'rgba(101,79,40,0.03)';
		for (let x = 0; x < 80; x += 2) cx.fillRect(x, 0, 1, 80);
		_noiseCache = ctx.createPattern(c, 'repeat');
		return _noiseCache;
	}

	function _foxing(ctx, w, h, n) {
		// Deterministic seeded random — same scroll always foxes the same way.
		let seed = (w * 7919 + h * 6151) & 0xffff;
		const rnd = () => { seed = (seed * 9301 + 49297) & 0xffff; return (seed % 1000) / 1000; };
		ctx.save();
		for (let i = 0; i < n; i++) {
			const x = rnd() * w; const y = rnd() * h;
			const r = 0.5 + rnd() * 2.5;
			ctx.fillStyle = rnd() > 0.5 ? 'rgba(92,63,26,0.30)' : 'rgba(107,69,35,0.30)';
			ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function parchmentTexture(ctx, w, h, bg, groundA, agingPreset = 'balanced') {
		// 1. base fill
		ctx.fillStyle = bg;
		ctx.fillRect(0, 0, w, h);

		// 2. fiber noise (cached pattern)
		ctx.fillStyle = _noisePattern(ctx, bg);
		ctx.fillRect(0, 0, w, h);

		// 3. radial vignette to groundA
		const vg = ctx.createRadialGradient(w/2, h/2, Math.min(w,h)*0.4, w/2, h/2, Math.max(w,h)*0.7);
		vg.addColorStop(0, 'rgba(0,0,0,0)');
		const alpha = agingPreset === 'heavy' ? 0.55 : agingPreset === 'light' ? 0.25 : 0.4;
		vg.addColorStop(1, ScrollPalette.toRgba(groundA, alpha));
		ctx.fillStyle = vg;
		ctx.fillRect(0, 0, w, h);

		// 4. foxing spots
		const density = { light: 12, balanced: 35, heavy: 70 }[agingPreset] || 35;
		_foxing(ctx, w, h, density);
	}

	// ----------------------------------------------------------------------
	// Stub frame — Plan 1 stand-in for the per-family curated frame in Plan 2.
	// Inset double rule + 4 corner gilded besants.
	// ----------------------------------------------------------------------
	function stubFrame(ctx, w, h, palette) {
		const inset = Math.round(28 * w / 480);
		ctx.strokeStyle = palette.text;
		ctx.lineWidth = 0.7;
		ctx.strokeRect(inset, inset, w - 2*inset, h - 2*inset);
		ctx.lineWidth = 0.4;
		ctx.strokeRect(inset + 4, inset + 4, w - 2*(inset + 4), h - 2*(inset + 4));

		[[inset, inset], [w-inset, inset], [inset, h-inset], [w-inset, h-inset]].forEach(([cx, cy]) => {
			const r = 7 * w / 480;
			const grad = ctx.createRadialGradient(cx-3, cy-3, 1, cx, cy, r + 1);
			grad.addColorStop(0, palette.gold_highlight);
			grad.addColorStop(0.6, palette.gold);
			grad.addColorStop(1, ScrollPalette.darken(palette.gold, 0.4));
			ctx.fillStyle = grad;
			ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI*2); ctx.fill();
		});
	}

	// ----------------------------------------------------------------------
	// Asset loader (Promise-cached) + tintAsset (channel-multiply for runtime use,
	// e.g., user-uploaded artwork). System assets are pre-tinted at seed time
	// in Plan 2 — they don't go through this path.
	// ----------------------------------------------------------------------
	const _loadCache = new Map();
	function loadAsset(url) {
		if (_loadCache.has(url)) return _loadCache.get(url);
		const p = new Promise((resolve, reject) => {
			const img = new Image();
			img.crossOrigin = 'anonymous';
			img.onload = () => resolve(img);
			img.onerror = reject;
			img.src = url;
		});
		_loadCache.set(url, p);
		return p;
	}

	const _tintCache = new Map();
	function tintAsset(img, color, mode = 'channel_multiply') {
		if (mode === 'none') return img;
		if (!img.complete || !img.naturalWidth) return img;
		const key = (img.src || '') + '|' + color + '|' + mode;
		if (_tintCache.has(key)) return _tintCache.get(key);

		const c = document.createElement('canvas');
		c.width = img.naturalWidth;
		c.height = img.naturalHeight;
		const x = c.getContext('2d');

		if (mode === 'channel_multiply') {
			// Correct order for anti-aliased alpha: clip first, then multiply.
			// (1) draw image → (2) globalCompositeOperation=source-in → fill with color, but that loses luminance.
			// Use: draw image, multiply, then mask out non-asset pixels via destination-in.
			x.drawImage(img, 0, 0);
			x.globalCompositeOperation = 'multiply';
			x.fillStyle = color;
			x.fillRect(0, 0, c.width, c.height);
			x.globalCompositeOperation = 'destination-in';
			x.drawImage(img, 0, 0);
		} else if (mode === 'overlay') {
			x.drawImage(img, 0, 0);
			x.globalCompositeOperation = 'source-in';
			x.fillStyle = color;
			x.fillRect(0, 0, c.width, c.height);
		}
		_tintCache.set(key, c);
		return c;
	}

	return { gildingGradient, parchmentTexture, stubFrame, loadAsset, tintAsset };
})();
