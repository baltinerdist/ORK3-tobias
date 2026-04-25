// Family-driven scroll renderer (browser canvas).
// Mirrors system/lib/ork3/class.ScrollFamilyRenderer.php — keep in sync.
// Plan 1 uses a canonical layout for all 10 families. Plan 3 differentiates per-family.
window.ScrollFamilies = (function() {

	function renderFamily(ctx, w, h, state, family) {
		const pal = family.palette;
		const fonts = family.fonts;
		const scale = w / 480;

		// 1. parchment
		ScrollPrimitives.parchmentTexture(ctx, w, h, pal.bg, pal.ground_a, state.decorationIntensity || 'balanced');

		// 2. stub frame (Plan 2: replaced by drawFrameFamily with curated assets)
		ScrollPrimitives.stubFrame(ctx, w, h, pal);

		// 3. title
		ctx.textAlign = 'center';
		ctx.fillStyle = pal.accent;
		ctx.font = `${Math.max(20, Math.round(38 * scale))}px ${fonts.title}`;
		ctx.fillText(state.awardName || 'Untitled', w / 2, 110 * scale);

		// 4. subtitle "It is hereby proclaimed"
		ctx.fillStyle = pal.text;
		ctx.font = `italic ${Math.max(8, Math.round(14 * scale))}px ${fonts.subtitle}`;
		ctx.fillText('It is hereby proclaimed', w / 2, 140 * scale);

		// 5. recipient
		ctx.font = `500 ${Math.max(12, Math.round(22 * scale))}px ${fonts.subtitle}`;
		ctx.fillText(state.recipient || '—', w / 2, 170 * scale);

		// 6. ornamental rule
		ctx.fillStyle = pal.accent;
		ctx.fillRect(w/2 - 140 * scale, 195 * scale, 280 * scale, Math.max(1, scale));

		// 7. body
		ctx.textAlign = 'left';
		ctx.fillStyle = pal.text;
		ctx.font = `${Math.max(8, Math.round(13 * scale))}px ${fonts.body}`;
		_wrapText(ctx, state.bodyText || _defaultBody(), 60 * scale, 248 * scale, w - 120 * scale, 18 * scale);

		// 8. signatures (bottom-left)
		const sigCount = family.sigCount || 2;
		const sigY = h - 110 * scale;
		for (let i = 0; i < sigCount; i++) {
			const y = sigY + (i * 32 * scale);
			ctx.strokeStyle = pal.text;
			ctx.lineWidth = Math.max(0.5, scale * 0.5);
			ctx.beginPath(); ctx.moveTo(60 * scale, y); ctx.lineTo(220 * scale, y); ctx.stroke();
			const sig = (state.signatures && state.signatures[i]) || { name: '', role: '' };
			if (sig.name) {
				ctx.fillStyle = pal.border;
				ctx.font = `${Math.max(10, Math.round(18 * scale))}px ${fonts.signatures}`;
				ctx.fillText(sig.name, 72 * scale, y - 4 * scale);
			}
			if (sig.role) {
				ctx.fillStyle = pal.text;
				ctx.font = `italic ${Math.max(7, Math.round(10 * scale))}px ${fonts.body}`;
				ctx.fillText(sig.role, 60 * scale, y + 14 * scale);
			}
		}

		// 9. wax seal placeholder (Plan 2: replaced by drawWaxSealEmboss + family stamp asset)
		const phi = 0.382;
		const sx = w * (1 - phi * 0.4);
		const sy = h * (1 - phi * 0.4);
		const sr = Math.max(16, 36 * scale);
		const wg = ctx.createRadialGradient(sx - sr * 0.3, sy - sr * 0.3, sr * 0.1, sx, sy, sr);
		wg.addColorStop(0, ScrollPalette.lighten(pal.wax, 0.35));
		wg.addColorStop(0.55, pal.wax);
		wg.addColorStop(1, ScrollPalette.darken(pal.wax, 0.45));
		ctx.fillStyle = wg;
		ctx.beginPath(); ctx.arc(sx, sy, sr, 0, Math.PI * 2); ctx.fill();

		// 10. date (top-right)
		ctx.textAlign = 'right';
		ctx.fillStyle = pal.text;
		ctx.font = `italic ${Math.max(8, Math.round(11 * scale))}px ${fonts.date}`;
		ctx.fillText(state.date || _todayLatin(), w - 60 * scale, 56 * scale);
	}

	function _wrapText(ctx, text, x, y, maxW, lineH) {
		const words = String(text).split(/\s+/);
		let line = '';
		for (const w of words) {
			const test = line ? `${line} ${w}` : w;
			if (ctx.measureText(test).width > maxW) {
				if (line) ctx.fillText(line, x, y);
				y += lineH; line = w;
			} else {
				line = test;
			}
		}
		if (line) ctx.fillText(line, x, y);
	}

	function _defaultBody() {
		return 'Be it known to all who behold this proclamation, that on the day herein recorded, the bearer hereof has been recognized for valor, counsel, and faithful service. Let it stand witness across the realm.';
	}

	function _todayLatin() {
		const y = new Date().getFullYear();
		const m = [['M',1000],['CM',900],['D',500],['CD',400],['C',100],['XC',90],['L',50],['XL',40],['X',10],['IX',9],['V',5],['IV',4],['I',1]];
		let s = '', n = y;
		for (const [v, k] of m) while (n >= k) { s += v; n -= k; }
		return `Anno Domini ${s}`;
	}

	return { renderFamily };
})();
