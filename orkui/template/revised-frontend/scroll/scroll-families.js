// Family-driven scroll renderer (browser canvas).
// Mirrors system/lib/ork3/class.ScrollFamilyRenderer.php — keep in sync.
window.ScrollFamilies = (function() {

	// Map family_key → seal stamp kind. Mirrors ScrollFamilyRenderer::SEAL_KIND.
	const SEAL_KIND = {
		hibernian_knotwork: 'knotwork',
		northern_gothic: 'lion',
		provencal_bestiary: 'rabbit',
		crimson_decree: 'crown',
		forest_reverie: 'oak_leaf',
		charred_edict: 'broken_sword',
		imperial_edict: 'eagle',
		scholars_hand: 'quill',
		crusaders_charter: 'fleur',
		astral_codex: 'pentagram',
	};

	const DROLERIE_KIND = {
		northern_gothic: 'hare_jousts_snail',
		provencal_bestiary: 'rabbit_lute',
	};

	function renderFamily(ctx, w, h, state, family) {
		const pal = family.palette;
		const fonts = family.fonts;
		const scale = w / 480;
		const key = state.family || family.key || 'northern_gothic';
		const decoration = family.decoration || [];
		const forPrint = !!state.forPrint;

		// 1. parchment foundation
		ScrollPrimitives.parchmentTexture(ctx, w, h, pal.bg, pal.ground_a, state.decorationIntensity || 'balanced');

		// 1b. Astral Codex star field (only on screen, not print)
		if (key === 'astral_codex' && !forPrint) {
			ScrollDecoration.drawStarField(ctx, w, h, pal);
		}

		// 1c. Charred Edict aging
		if (key === 'charred_edict' || (state.decorationIntensity === 'heavy')) {
			ScrollDecoration.applyBurntEdge(ctx, w, h, key === 'charred_edict' ? 0.6 : 0.3);
		}
		if (key === 'charred_edict') {
			ScrollDecoration.applyFoldCreases(ctx, w, h);
		}

		// 2. family-specific frame (asset-first, procedural fallback)
		ScrollDecoration.drawFrame(ctx, w, h, pal, family.frame || 'gothic_ivy', key);

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

		// 7. body + historiated initial
		ctx.textAlign = 'left';
		ctx.fillStyle = pal.text;
		ctx.font = `${Math.max(8, Math.round(13 * scale))}px ${fonts.body}`;
		const body = state.bodyText || _defaultBody();
		const bodyX = 60 * scale;
		const bodyY = 230 * scale;
		const bodyW = w - 120 * scale;
		const lineH = Math.max(10, 18 * scale);
		const fontSize = Math.max(8, Math.round(13 * scale));

		if (decoration.includes('historiated_initial') && body.trim()) {
			const initialW = Math.max(40, 76 * scale);
			const initialH = Math.max(50, 94 * scale);
			const letter = body.trim().charAt(0).toUpperCase() || 'B';
			ScrollDecoration.drawHistoriatedInitial(ctx, {
				x: bodyX, y: bodyY - 8 * scale,
				w: initialW, h: initialH,
				letter, palette: pal, font: fonts.title,
			});
			// Body wraps past the initial for first 5 lines, then below
			ctx.textAlign = 'left';
			ctx.fillStyle = pal.text;
			ctx.font = `${fontSize}px ${fonts.body}`;
			const indent = initialW + 12 * scale;
			_wrapText(ctx, body.substr(1), bodyX + indent, bodyY + 2 * scale, bodyW - indent, lineH, 5);
		} else {
			_wrapText(ctx, body, bodyX, bodyY, bodyW, lineH);
		}

		// 7c. drôlerie
		if (decoration.includes('drolerie') && DROLERIE_KIND[key]) {
			const drW = Math.max(60, 96 * scale);
			const drH = Math.max(28, 40 * scale);
			ScrollDecoration.drawDrolerie(ctx, w / 2 + 10 * scale, h - 155 * scale, drW, drH, pal, DROLERIE_KIND[key]);
		}

		// 7d. banderole
		if (decoration.includes('banderole')) {
			ScrollDecoration.drawBanderole(ctx, {
				cx: w / 2, cy: 190 * scale,
				w: 280 * scale, h: 36 * scale,
				text: state.motto || 'Honos Virtutis Praemium',
				palette: pal, font: fonts.subtitle,
			});
		}

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

		// 9. embossed wax seal
		const phi = 0.382;
		let sx, sy;
		if (key === 'imperial_edict' || key === 'astral_codex') {
			sx = w / 2;
			sy = h - 95 * scale;
		} else {
			sx = w * (1 - phi * 0.4);
			sy = h * (1 - phi * 0.4);
		}
		ScrollDecoration.drawWaxSealEmboss(ctx, {
			cx: sx, cy: sy,
			r: Math.max(16, 36 * scale),
			palette: pal,
			stampKind: SEAL_KIND[key] || 'fleur',
			familyKey: key,
		});

		// 10. date (top-right)
		ctx.textAlign = 'right';
		ctx.fillStyle = pal.text;
		ctx.font = `italic ${Math.max(8, Math.round(11 * scale))}px ${fonts.date}`;
		ctx.fillText(state.date || _todayLatin(), w - 60 * scale, 56 * scale);
	}

	function _wrapText(ctx, text, x, y, maxW, lineH, lineLimit = 0) {
		const words = String(text).split(/\s+/);
		let line = '';
		let drawn = 0;
		for (const w of words) {
			const test = line ? `${line} ${w}` : w;
			if (ctx.measureText(test).width > maxW) {
				if (line) {
					ctx.fillText(line, x, y);
					drawn++;
					if (lineLimit > 0 && drawn >= lineLimit) return;
				}
				y += lineH; line = w;
			} else {
				line = test;
			}
		}
		if (line && (lineLimit === 0 || drawn < lineLimit)) ctx.fillText(line, x, y);
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
