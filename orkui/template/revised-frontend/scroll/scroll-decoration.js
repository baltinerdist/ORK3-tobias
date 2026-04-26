// Family-specific decorative primitives — JS canvas mirror of class.ScrollDecoration.php.
// Procedural draws (no external assets). Each family has its own visual signature.
//
// Methods:
//   drawFrame(ctx, w, h, palette, kind)
//   drawSealStamp(ctx, cx, cy, r, palette, kind)
//   drawHistoriatedInitial(ctx, opts)
//   drawDrolerie(ctx, x, y, w, h, palette, kind)
//   drawBanderole(ctx, opts)
//   drawWaxSealEmboss(ctx, opts)
//   applyBurntEdge(ctx, w, h, intensity)
//   applyFoldCreases(ctx, w, h)
//   drawStarField(ctx, w, h, palette)
//   drawHeraldryMedallion(ctx, cx, cy, r, image, palette)

window.ScrollDecoration = (function() {
	const FRAME_INSET = 28;

	// ============ Frames =============================================
	function drawFrame(ctx, w, h, palette, kind) {
		const fn = ({
			gothic_ivy: drawFrame_gothic_ivy,
			insular_knot: drawFrame_insular_knot,
			asymmetric_ivy_grotesque: drawFrame_asymmetric_ivy_grotesque,
			gothic_arch: drawFrame_gothic_arch,
			organic_vine: drawFrame_organic_vine,
			minimal_burnt: drawFrame_minimal_burnt,
			jeweled_cabochon: drawFrame_jeweled_cabochon,
			renaissance_white_vine: drawFrame_renaissance_white_vine,
			romanesque_arch: drawFrame_romanesque_arch,
			astral_star_pattern: drawFrame_astral_star_pattern,
		}[kind] || drawFrame_gothic_ivy);
		fn(ctx, w, h, palette);
	}

	function drawFrame_gothic_ivy(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		// Inner ink rule
		ctx.strokeStyle = pal.text + '7A';
		ctx.lineWidth = 0.7;
		ctx.strokeRect(inset + 4, inset + 4, w - 2 * (inset + 4), h - 2 * (inset + 4));

		// Sinuous ivy lines along edges
		ctx.strokeStyle = pal.border;
		ctx.lineWidth = Math.max(1, 1.2 * scale);
		const amp = 4 * scale;
		const period = 32 * scale;
		const drawWave = (x0, y0, x1, y1) => {
			ctx.beginPath();
			const horiz = y0 === y1;
			if (horiz) {
				ctx.moveTo(x0, y0);
				for (let x = x0; x <= x1; x += 2) ctx.lineTo(x, y0 - amp * Math.sin((x - x0) * Math.PI * 2 / period));
			} else {
				ctx.moveTo(x0, y0);
				for (let y = y0; y <= y1; y += 2) ctx.lineTo(x0 - amp * Math.sin((y - y0) * Math.PI * 2 / period), y);
			}
			ctx.stroke();
		};
		drawWave(inset, inset, w - inset, inset);
		drawWave(inset, h - inset, w - inset, h - inset);
		drawWave(inset, inset, inset, h - inset);
		drawWave(w - inset, inset, w - inset, h - inset);

		// Ivy leaves
		ctx.fillStyle = pal.border;
		const leafStep = 36 * scale;
		const leafR = 5 * scale;
		const leaf = (cx, cy, dir) => {
			ctx.beginPath();
			let pts;
			switch (dir) {
				case 'down': pts = [[cx, cy + leafR], [cx - leafR, cy - leafR / 2], [cx, cy - leafR], [cx + leafR, cy - leafR / 2]]; break;
				case 'up':   pts = [[cx, cy - leafR], [cx - leafR, cy + leafR / 2], [cx, cy + leafR], [cx + leafR, cy + leafR / 2]]; break;
				case 'left': pts = [[cx - leafR, cy], [cx + leafR / 2, cy - leafR], [cx + leafR, cy], [cx + leafR / 2, cy + leafR]]; break;
				case 'right':pts = [[cx + leafR, cy], [cx - leafR / 2, cy - leafR], [cx - leafR, cy], [cx - leafR / 2, cy + leafR]]; break;
			}
			ctx.moveTo(pts[0][0], pts[0][1]);
			for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
			ctx.closePath(); ctx.fill();
		};
		for (let x = inset + leafStep; x < w - inset; x += leafStep) {
			leaf(x, inset - 8 * scale, 'down');
			leaf(x, h - inset + 8 * scale, 'up');
		}
		for (let y = inset + leafStep; y < h - inset; y += leafStep) {
			leaf(inset - 8 * scale, y, 'right');
			leaf(w - inset + 8 * scale, y, 'left');
		}

		// Gilded besants at corners + midpoints
		gildedBesant(ctx, inset, inset, 9 * scale, pal);
		gildedBesant(ctx, w - inset, inset, 9 * scale, pal);
		gildedBesant(ctx, inset, h - inset, 9 * scale, pal);
		gildedBesant(ctx, w - inset, h - inset, 9 * scale, pal);
		gildedBesant(ctx, w / 2, inset, 5 * scale, pal);
		gildedBesant(ctx, w / 2, h - inset, 5 * scale, pal);
		gildedBesant(ctx, inset, h / 2, 5 * scale, pal);
		gildedBesant(ctx, w - inset, h / 2, 5 * scale, pal);
		ctx.restore();
	}

	function drawFrame_insular_knot(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		ctx.strokeStyle = pal.border;
		ctx.lineWidth = Math.max(1, 1.5 * scale);
		const band = 14 * scale;
		const step = 20 * scale;
		const tile = (cx, cy) => {
			ctx.beginPath(); ctx.arc(cx, cy, band / 2, 0, Math.PI * 2); ctx.stroke();
			ctx.fillStyle = pal.accent;
			ctx.beginPath(); ctx.arc(cx, cy, band / 5, 0, Math.PI * 2); ctx.fill();
		};
		for (let x = inset + step / 2; x < w - inset; x += step) {
			tile(x, inset - band / 2);
			tile(x, h - inset + band / 2);
		}
		for (let y = inset + step / 2; y < h - inset; y += step) {
			tile(inset - band / 2, y);
			tile(w - inset + band / 2, y);
		}
		// Triskeles in 4 corners
		[[inset - band, inset - band], [w - inset + band, inset - band], [inset - band, h - inset + band], [w - inset + band, h - inset + band]].forEach(([cx, cy]) => triskele(ctx, cx, cy, 14 * scale, pal));
		ctx.restore();
	}

	function drawFrame_asymmetric_ivy_grotesque(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		// Heavy left + top with ivy
		ctx.strokeStyle = pal.border;
		ctx.lineWidth = 2 * scale;
		ctx.beginPath();
		for (let y = inset; y < h - inset; y += 2) {
			const x = inset - 6 * scale * Math.sin(y * Math.PI / (14 * scale));
			ctx.lineTo(x, y);
		}
		ctx.stroke();
		ctx.beginPath();
		for (let x = inset; x < w - inset; x += 2) {
			const y = inset - 6 * scale * Math.sin(x * Math.PI / (14 * scale));
			ctx.lineTo(x, y);
		}
		ctx.stroke();
		// Light right + bottom
		ctx.strokeStyle = pal.text + '70';
		ctx.lineWidth = 0.7;
		ctx.beginPath();
		ctx.moveTo(w - inset, inset); ctx.lineTo(w - inset, h - inset); ctx.stroke();
		ctx.beginPath();
		ctx.moveTo(inset, h - inset); ctx.lineTo(w - inset, h - inset); ctx.stroke();
		// Accents
		ctx.fillStyle = pal.accent;
		for (let y = inset + 28 * scale; y < h - inset; y += 28 * scale) {
			ctx.beginPath(); ctx.arc(inset - 14 * scale, y, 4 * scale, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function drawFrame_gothic_arch(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		const archTop = inset * 1.2;
		ctx.save();
		ctx.strokeStyle = pal.accent;
		ctx.lineWidth = 3 * scale;
		ctx.beginPath();
		ctx.moveTo(inset, h - inset);
		ctx.lineTo(inset, archTop * 2);
		ctx.lineTo(w / 2, archTop);
		ctx.lineTo(w - inset, archTop * 2);
		ctx.lineTo(w - inset, h - inset);
		ctx.closePath();
		ctx.stroke();
		// Inner gold line
		ctx.strokeStyle = ScrollPrimitives.gildingGradient(ctx, 0, 0, w, h, pal.gold, pal.gold_highlight);
		ctx.lineWidth = 2 * scale;
		ctx.beginPath();
		ctx.moveTo(inset + 4, h - inset - 4);
		ctx.lineTo(inset + 4, archTop * 2 + 4);
		ctx.lineTo(w / 2, archTop + 6);
		ctx.lineTo(w - inset - 4, archTop * 2 + 4);
		ctx.lineTo(w - inset - 4, h - inset - 4);
		ctx.stroke();
		// Fleurs at corners
		fleurDeLis(ctx, inset, h - inset, 10 * scale, pal);
		fleurDeLis(ctx, w - inset, h - inset, 10 * scale, pal);
		ctx.restore();
	}

	function drawFrame_organic_vine(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		ctx.fillStyle = pal.border;
		// Sinuous vines breaking the frame
		const breakOut = 8 * scale;
		for (let y = inset; y < h - inset; y += 2) {
			const x1 = inset - breakOut * 2 * Math.sin(y * Math.PI / (40 * scale));
			const x2 = w - inset + breakOut * 2 * Math.sin(y * Math.PI / (40 * scale));
			ctx.fillRect(x1, y, 2, 2);
			ctx.fillRect(x2, y, 2, 2);
		}
		// Leaves
		ctx.fillStyle = pal.accent;
		for (let y = inset + 30; y < h - inset; y += 50 * scale) {
			ctx.beginPath(); ctx.ellipse(inset - 10 * scale, y, 7 * scale, 3 * scale, -0.3, 0, Math.PI * 2); ctx.fill();
			ctx.beginPath(); ctx.ellipse(w - inset + 10 * scale, y, 7 * scale, 3 * scale, 0.3, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function drawFrame_minimal_burnt(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		ctx.strokeStyle = pal.text + '80';
		ctx.lineWidth = 1;
		ctx.strokeRect(inset, inset, w - 2 * inset, h - 2 * inset);
		ctx.restore();
	}

	function drawFrame_jeweled_cabochon(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		ctx.strokeStyle = pal.text;
		ctx.lineWidth = 1;
		ctx.strokeRect(inset, inset, w - 2 * inset, h - 2 * inset);
		// Gold panel top 18%
		ctx.fillStyle = ScrollPrimitives.gildingGradient(ctx, 0, inset, 0, inset + (h - 2 * inset) * 0.18, pal.gold, pal.gold_highlight);
		ctx.fillRect(inset, inset, w - 2 * inset, (h - 2 * inset) * 0.18);
		// Cabochons
		const gemR = 5 * scale;
		const gemStep = 30 * scale;
		const drawGem = (x, y, color) => {
			ctx.fillStyle = color;
			ctx.beginPath(); ctx.arc(x, y, gemR, 0, Math.PI * 2); ctx.fill();
			ctx.strokeStyle = '#5A4A0F'; ctx.lineWidth = 1;
			ctx.beginPath(); ctx.arc(x, y, gemR + 1, 0, Math.PI * 2); ctx.stroke();
		};
		let i = 0;
		for (let x = inset + gemStep / 2; x < w - inset; x += gemStep, i++) {
			drawGem(x, inset, i % 2 ? pal.accent : pal.border);
			drawGem(x, h - inset, i % 2 ? pal.accent : pal.border);
		}
		i = 0;
		for (let y = inset + gemStep / 2; y < h - inset; y += gemStep, i++) {
			drawGem(inset, y, i % 2 ? pal.accent : pal.border);
			drawGem(w - inset, y, i % 2 ? pal.accent : pal.border);
		}
		ctx.restore();
	}

	function drawFrame_renaissance_white_vine(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		const bandW = 10 * scale;
		ctx.save();
		const colors = [pal.border, pal.accent, pal.ground_a];
		colors.forEach((c, i) => {
			const [r, g, b] = ScrollPalette.hexToRgb(c);
			ctx.fillStyle = `rgba(${r},${g},${b},0.85)`;
			ctx.fillRect(inset + i * bandW, inset, bandW, h - 2 * inset);
			ctx.fillRect(w - inset - (i + 1) * bandW, inset, bandW, h - 2 * inset);
		});
		// White-vine arc overlay
		ctx.strokeStyle = pal.bg + 'B0';
		ctx.lineWidth = 1.5;
		const step = 22 * scale;
		for (let y = inset + step / 2; y < h - inset; y += step) {
			ctx.beginPath(); ctx.arc(inset + bandW * 1.5, y, bandW, 0, Math.PI); ctx.stroke();
			ctx.beginPath(); ctx.arc(w - inset - bandW * 1.5, y, bandW, Math.PI, Math.PI * 2); ctx.stroke();
		}
		// Gilded disks at corners
		gildedBesant(ctx, inset, inset, 5 * scale, pal);
		gildedBesant(ctx, w - inset, inset, 5 * scale, pal);
		gildedBesant(ctx, inset, h - inset, 5 * scale, pal);
		gildedBesant(ctx, w - inset, h - inset, 5 * scale, pal);
		ctx.restore();
	}

	function drawFrame_romanesque_arch(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		const archTop = 120 * scale;
		const colW = 8 * scale;
		ctx.save();
		ctx.fillStyle = pal.accent;
		ctx.fillRect(inset, archTop, colW, h - inset - archTop);
		ctx.fillRect(w - inset - colW, archTop, colW, h - inset - archTop);
		ctx.strokeStyle = pal.accent; ctx.lineWidth = 2;
		ctx.beginPath();
		ctx.arc(w / 2, archTop, (w - 2 * inset) / 2, Math.PI, 0);
		ctx.stroke();
		// Inner gold arc
		ctx.strokeStyle = pal.gold; ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.arc(w / 2, archTop + 2, (w - 2 * inset) / 2 - 4, Math.PI, 0);
		ctx.stroke();
		// Bottom rule
		ctx.strokeStyle = pal.accent;
		ctx.beginPath(); ctx.moveTo(inset, h - inset); ctx.lineTo(w - inset, h - inset); ctx.stroke();
		// Jeweled cross
		jeweledCross(ctx, w / 2, archTop - 20 * scale, 14 * scale, pal);
		ctx.restore();
	}

	function drawFrame_astral_star_pattern(ctx, w, h, pal) {
		const scale = w / 480;
		const inset = FRAME_INSET * scale;
		ctx.save();
		ctx.strokeStyle = pal.border;
		ctx.lineWidth = 1;
		ctx.strokeRect(inset, inset, w - 2 * inset, h - 2 * inset);
		ctx.fillStyle = '#C0C0C0';
		const starStep = 28 * scale;
		const sR = 5 * scale;
		const drawStar = (cx, cy, r) => {
			ctx.beginPath();
			for (let i = 0; i < 10; i++) {
				const a = -Math.PI / 2 + i * Math.PI / 5;
				const rr = i % 2 === 0 ? r : r * 0.4;
				const x = cx + Math.cos(a) * rr;
				const y = cy + Math.sin(a) * rr;
				if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
			}
			ctx.closePath(); ctx.fill();
		};
		for (let x = inset + starStep / 2; x < w - inset; x += starStep) {
			drawStar(x, inset, sR);
			drawStar(x, h - inset, sR);
		}
		for (let y = inset + starStep / 2; y < h - inset; y += starStep) {
			drawStar(inset, y, sR);
			drawStar(w - inset, y, sR);
		}
		ctx.restore();
	}

	// ============ Helpers =============================================
	function gildedBesant(ctx, cx, cy, r, pal) {
		const grad = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.3, r * 0.1, cx, cy, r + 1);
		grad.addColorStop(0, pal.gold_highlight);
		grad.addColorStop(0.6, pal.gold);
		grad.addColorStop(1, ScrollPalette.darken(pal.gold, 0.4));
		ctx.fillStyle = grad;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
	}

	function fleurDeLis(ctx, cx, cy, r, pal) {
		ctx.save();
		ctx.fillStyle = pal.gold;
		ctx.beginPath();
		ctx.moveTo(cx, cy - r);
		ctx.lineTo(cx + r * 0.6, cy + r * 0.2);
		ctx.lineTo(cx + r * 0.3, cy + r * 0.6);
		ctx.lineTo(cx, cy + r);
		ctx.lineTo(cx - r * 0.3, cy + r * 0.6);
		ctx.lineTo(cx - r * 0.6, cy + r * 0.2);
		ctx.closePath(); ctx.fill();
		ctx.fillRect(cx - r * 0.7, cy + r * 0.2, r * 1.4, r * 0.2);
		ctx.restore();
	}

	function triskele(ctx, cx, cy, r, pal) {
		for (let k = 0; k < 3; k++) {
			const a = k * 2 * Math.PI / 3;
			const ox = cx + Math.cos(a) * r * 0.4;
			const oy = cy + Math.sin(a) * r * 0.4;
			ctx.fillStyle = k % 2 ? pal.accent : pal.border;
			ctx.beginPath(); ctx.arc(ox, oy, r / 3, 0, Math.PI * 2); ctx.fill();
		}
		ctx.fillStyle = pal.accent;
		ctx.beginPath(); ctx.arc(cx, cy, r / 4, 0, Math.PI * 2); ctx.fill();
	}

	function jeweledCross(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		const t = Math.max(2, r / 4);
		ctx.fillRect(cx - t, cy - r, t * 2, r * 2);
		ctx.fillRect(cx - r * 0.7, cy - t, r * 1.4, t * 2);
		ctx.fillStyle = pal.accent;
		ctx.beginPath(); ctx.arc(cx, cy, t, 0, Math.PI * 2); ctx.fill();
	}

	// ============ Seal stamps =========================================
	function drawSealStamp(ctx, cx, cy, r, pal, kind) {
		const fn = ({
			lion: stamp_lion, fleur: stamp_fleur, crown: stamp_crown,
			oak_leaf: stamp_oak_leaf, broken_sword: stamp_broken_sword,
			eagle: stamp_eagle, pentagram: stamp_pentagram, quill: stamp_quill,
			knotwork: stamp_knotwork, rabbit: stamp_rabbit,
		}[kind] || stamp_fleur);
		fn(ctx, cx, cy, r, pal);
	}

	function stamp_lion(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.beginPath(); ctx.ellipse(cx + r * 0.1, cy + r * 0.2, r, r * 0.7, 0, 0, Math.PI * 2); ctx.fill();
		ctx.beginPath(); ctx.ellipse(cx - r * 0.4, cy - r * 0.2, r * 0.6, r * 0.55, 0, 0, Math.PI * 2); ctx.fill();
		// Mane
		for (let k = 0; k < 8; k++) {
			const a = Math.PI + k * Math.PI / 7;
			const x = cx - r * 0.4 + Math.cos(a) * r * 0.45;
			const y = cy - r * 0.2 + Math.sin(a) * r * 0.45;
			ctx.beginPath(); ctx.arc(x, y, r * 0.18, 0, Math.PI * 2); ctx.fill();
		}
	}

	function stamp_fleur(ctx, cx, cy, r, pal) { fleurDeLis(ctx, cx, cy, r, pal); }

	function stamp_crown(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.fillRect(cx - r, cy + r * 0.2, r * 2, r * 0.3);
		ctx.beginPath();
		ctx.moveTo(cx - r, cy + r * 0.2);
		ctx.lineTo(cx - r * 0.7, cy - r * 0.4);
		ctx.lineTo(cx - r * 0.3, cy + r * 0.2);
		ctx.lineTo(cx, cy - r * 0.7);
		ctx.lineTo(cx + r * 0.3, cy + r * 0.2);
		ctx.lineTo(cx + r * 0.7, cy - r * 0.4);
		ctx.lineTo(cx + r, cy + r * 0.2);
		ctx.closePath(); ctx.fill();
		ctx.fillStyle = pal.accent;
		[[-r * 0.7, -r * 0.3], [0, -r * 0.55], [r * 0.7, -r * 0.3]].forEach(([dx, dy]) => {
			ctx.beginPath(); ctx.arc(cx + dx, cy + dy, r * 0.18, 0, Math.PI * 2); ctx.fill();
		});
	}

	function stamp_oak_leaf(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.beginPath();
		for (let i = 0; i < 16; i++) {
			const a = -Math.PI / 2 + i * 2 * Math.PI / 16;
			const rr = r * (0.6 + 0.4 * Math.abs(Math.sin(i * Math.PI / 4)));
			const x = cx + Math.cos(a) * rr; const y = cy + Math.sin(a) * rr;
			if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
		}
		ctx.closePath(); ctx.fill();
		ctx.strokeStyle = pal.border; ctx.lineWidth = 1;
		ctx.beginPath(); ctx.moveTo(cx, cy - r); ctx.lineTo(cx, cy + r); ctx.stroke();
	}

	function stamp_broken_sword(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.fillRect(cx - r * 0.5, cy - r * 0.1, r, r * 0.2);
		ctx.fillRect(cx - r * 0.05, cy - r * 0.3, r * 0.1, r * 0.6);
		ctx.fillRect(cx - r * 0.1, cy + r * 0.3, r * 0.2, r * 0.3);
		ctx.beginPath();
		ctx.moveTo(cx - r * 0.1, cy + r * 0.6); ctx.lineTo(cx + r * 0.1, cy + r * 0.6);
		ctx.lineTo(cx, cy + r * 0.7); ctx.lineTo(cx - r * 0.05, cy + r * 0.65);
		ctx.closePath(); ctx.fill();
	}

	function stamp_eagle(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.beginPath(); ctx.ellipse(cx, cy + r * 0.1, r * 0.4, r * 0.6, 0, 0, Math.PI * 2); ctx.fill();
		ctx.beginPath();
		ctx.moveTo(cx, cy); ctx.lineTo(cx - r, cy - r * 0.3); ctx.lineTo(cx - r * 0.7, cy + r * 0.2);
		ctx.closePath(); ctx.fill();
		ctx.beginPath();
		ctx.moveTo(cx, cy); ctx.lineTo(cx + r, cy - r * 0.3); ctx.lineTo(cx + r * 0.7, cy + r * 0.2);
		ctx.closePath(); ctx.fill();
		ctx.beginPath(); ctx.arc(cx, cy - r * 0.4, r * 0.3, 0, Math.PI * 2); ctx.fill();
	}

	function stamp_pentagram(ctx, cx, cy, r, pal) {
		ctx.strokeStyle = pal.gold; ctx.lineWidth = 1.2;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
		const pts = [];
		for (let i = 0; i < 5; i++) {
			const a = -Math.PI / 2 + i * 4 * Math.PI / 5;
			pts.push([cx + Math.cos(a) * r * 0.85, cy + Math.sin(a) * r * 0.85]);
		}
		const order = [0, 2, 4, 1, 3, 0];
		ctx.beginPath();
		ctx.moveTo(pts[order[0]][0], pts[order[0]][1]);
		for (let i = 1; i < order.length; i++) ctx.lineTo(pts[order[i]][0], pts[order[i]][1]);
		ctx.stroke();
	}

	function stamp_quill(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.beginPath();
		ctx.moveTo(cx - r * 0.7, cy + r * 0.7);
		ctx.lineTo(cx + r * 0.5, cy - r * 0.5);
		ctx.lineTo(cx + r * 0.7, cy - r * 0.3);
		ctx.lineTo(cx - r * 0.5, cy + r * 0.9);
		ctx.closePath(); ctx.fill();
		ctx.beginPath(); ctx.arc(cx + r * 0.6, cy - r * 0.4, r * 0.25, 0, Math.PI * 2); ctx.fill();
	}

	function stamp_knotwork(ctx, cx, cy, r, pal) {
		triskele(ctx, cx, cy, r, pal);
		ctx.strokeStyle = pal.border; ctx.lineWidth = 1;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
	}

	function stamp_rabbit(ctx, cx, cy, r, pal) {
		ctx.fillStyle = pal.gold;
		ctx.beginPath(); ctx.ellipse(cx, cy + r * 0.2, r * 0.7, r * 0.5, 0, 0, Math.PI * 2); ctx.fill();
		ctx.beginPath(); ctx.ellipse(cx - r * 0.4, cy - r * 0.1, r * 0.3, r * 0.3, 0, 0, Math.PI * 2); ctx.fill();
		ctx.beginPath(); ctx.ellipse(cx - r * 0.55, cy - r * 0.55, r * 0.15, r * 0.4, 0, 0, Math.PI * 2); ctx.fill();
		ctx.beginPath(); ctx.ellipse(cx - r * 0.25, cy - r * 0.6, r * 0.15, r * 0.4, 0, 0, Math.PI * 2); ctx.fill();
	}

	// ============ Historiated initial ===============================
	function drawHistoriatedInitial(ctx, opts) {
		const { x, y, w, h, letter, palette: pal, font } = opts;
		const cornerSq = Math.round(w * 0.22);

		ctx.fillStyle = pal.accent;
		ctx.fillRect(x, y, cornerSq, cornerSq);
		ctx.fillRect(x + w - cornerSq, y + h - cornerSq, cornerSq, cornerSq);

		ctx.fillStyle = ScrollPrimitives.gildingGradient(ctx, x + w - cornerSq, y, x + w, y + cornerSq, pal.gold, pal.gold_highlight);
		ctx.fillRect(x + w - cornerSq, y, cornerSq, cornerSq);
		ctx.fillStyle = ScrollPrimitives.gildingGradient(ctx, x, y + h - cornerSq, x + cornerSq, y + h, pal.gold, pal.gold_highlight);
		ctx.fillRect(x, y + h - cornerSq, cornerSq, cornerSq);

		// Inner field
		ctx.fillStyle = pal.border;
		ctx.fillRect(x + 4, y + 4, w - 8, h - 8);
		// Diaper pattern
		ctx.strokeStyle = pal.bg + 'A0';
		ctx.lineWidth = 0.5;
		ctx.beginPath();
		for (let dy = 0; dy < h; dy += 6) {
			ctx.moveTo(x + 4, y + 4 + dy);
			ctx.lineTo(x + w - 4, y + 4 + dy + 6);
		}
		ctx.stroke();

		// Letter
		ctx.fillStyle = pal.bg;
		ctx.font = `bold ${Math.round(h * 0.55)}px ${font || 'serif'}`;
		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.fillText(letter, x + w / 2, y + h / 2 + 2);
	}

	// ============ Drôlerie ==========================================
	function drawDrolerie(ctx, x, y, w, h, pal, kind) {
		ctx.save();
		ctx.fillStyle = pal.border;
		const dark = ScrollPalette.darken(pal.border, 0.3);
		switch (kind) {
			case 'hare_jousts_snail':
				ctx.beginPath(); ctx.ellipse(x + w * 0.2, y + h * 0.65, w * 0.18, h * 0.30, 0, 0, Math.PI * 2); ctx.fill();
				ctx.beginPath(); ctx.ellipse(x + w * 0.15, y + h * 0.3, w * 0.04, h * 0.25, 0, 0, Math.PI * 2); ctx.fill();
				ctx.beginPath(); ctx.ellipse(x + w * 0.22, y + h * 0.3, w * 0.04, h * 0.25, 0, 0, Math.PI * 2); ctx.fill();
				ctx.strokeStyle = dark; ctx.lineWidth = 1.5;
				ctx.beginPath(); ctx.moveTo(x + w * 0.3, y + h * 0.5); ctx.lineTo(x + w * 0.7, y + h * 0.4); ctx.stroke();
				ctx.fillStyle = pal.border;
				ctx.beginPath(); ctx.ellipse(x + w * 0.85, y + h * 0.75, w * 0.15, h * 0.18, 0, 0, Math.PI * 2); ctx.fill();
				ctx.strokeStyle = dark;
				ctx.beginPath(); ctx.arc(x + w * 0.85, y + h * 0.65, w * 0.09, 0, Math.PI * 2); ctx.stroke();
				ctx.beginPath(); ctx.arc(x + w * 0.85, y + h * 0.65, w * 0.05, 0, Math.PI * 2); ctx.stroke();
				ctx.beginPath(); ctx.moveTo(x + w * 0.7, y + h * 0.55); ctx.lineTo(x + w * 0.4, y + h * 0.4); ctx.stroke();
				break;
			default:
				ctx.beginPath(); ctx.ellipse(x + w * 0.5, y + h * 0.65, w * 0.2, h * 0.3, 0, 0, Math.PI * 2); ctx.fill();
				ctx.beginPath(); ctx.ellipse(x + w * 0.4, y + h * 0.4, w * 0.1, h * 0.15, 0, 0, Math.PI * 2); ctx.fill();
				break;
		}
		ctx.restore();
	}

	// ============ Banderole =========================================
	function drawBanderole(ctx, opts) {
		const { cx, cy, w, h, text, palette: pal, font } = opts;
		ctx.save();
		ctx.fillStyle = pal.gold;
		ctx.strokeStyle = ScrollPalette.darken(pal.gold, 0.4);
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.moveTo(cx - w / 2, cy);
		ctx.bezierCurveTo(cx - w / 4, cy - h * 0.5, cx + w / 4, cy - h * 0.5, cx + w / 2, cy);
		ctx.lineTo(cx + w / 2 + 12, cy + h * 0.7);
		ctx.lineTo(cx + w / 2 - 4, cy + h * 0.6);
		ctx.bezierCurveTo(cx + w / 4, cy + h * 0.4, cx - w / 4, cy + h * 0.4, cx - w / 2 + 4, cy + h * 0.6);
		ctx.lineTo(cx - w / 2 - 12, cy + h * 0.7);
		ctx.closePath(); ctx.fill(); ctx.stroke();
		// Text
		if (text) {
			ctx.fillStyle = pal.text;
			ctx.font = `italic ${Math.round(h * 0.35)}px ${font || 'serif'}`;
			ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
			ctx.fillText(text, cx, cy + h * 0.05);
		}
		ctx.restore();
	}

	// ============ Wax seal emboss ===================================
	function drawWaxSealEmboss(ctx, opts) {
		const { cx, cy, r, palette: pal, stampKind } = opts;
		ctx.save();
		// Ribbon tails (behind disc)
		const ribbonGrad = ctx.createLinearGradient(cx, cy + r, cx, cy + r * 1.7);
		ribbonGrad.addColorStop(0, pal.wax);
		ribbonGrad.addColorStop(1, ScrollPalette.darken(pal.wax, 0.3));
		ctx.fillStyle = ribbonGrad;
		ctx.beginPath();
		ctx.moveTo(cx - r * 0.3, cy + r * 0.8);
		ctx.lineTo(cx - r * 1.0, cy + r * 1.6);
		ctx.lineTo(cx - r * 0.6, cy + r * 1.7);
		ctx.lineTo(cx - r * 0.1, cy + r * 0.9);
		ctx.closePath(); ctx.fill();
		ctx.beginPath();
		ctx.moveTo(cx + r * 0.3, cy + r * 0.8);
		ctx.lineTo(cx + r * 1.0, cy + r * 1.6);
		ctx.lineTo(cx + r * 0.6, cy + r * 1.7);
		ctx.lineTo(cx + r * 0.1, cy + r * 0.9);
		ctx.closePath(); ctx.fill();
		// Wax disc
		const wg = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.3, r * 0.1, cx, cy, r);
		wg.addColorStop(0, ScrollPalette.lighten(pal.wax, 0.35));
		wg.addColorStop(0.55, pal.wax);
		wg.addColorStop(1, ScrollPalette.darken(pal.wax, 0.45));
		ctx.fillStyle = wg;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
		// Highlight
		ctx.fillStyle = 'rgba(255,255,255,0.18)';
		ctx.beginPath(); ctx.ellipse(cx - r * 0.3, cy - r * 0.35, r * 0.4, r * 0.18, -Math.PI / 4, 0, Math.PI * 2); ctx.fill();
		// Embossed stamp
		drawSealStamp(ctx, cx, cy, r * 0.7, pal, stampKind || 'fleur');
		ctx.restore();
	}

	// ============ Aging ============================================
	function applyBurntEdge(ctx, w, h, intensity = 0.6) {
		const g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * (1 - intensity * 0.5), w / 2, h / 2, Math.max(w, h) * 0.7);
		g.addColorStop(0, 'rgba(0,0,0,0)');
		g.addColorStop(0.7, 'rgba(40,20,8,0.4)');
		g.addColorStop(1, 'rgba(20,10,4,0.95)');
		ctx.save();
		ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
		// Bites
		let seed = (w * 1009 + h * 1013) & 0xffff;
		const rnd = () => { seed = (seed * 9301 + 49297) & 0xffff; return (seed % 1000) / 1000; };
		ctx.globalCompositeOperation = 'source-over';
		ctx.fillStyle = '#120804';
		for (let i = 0; i < 60; i++) {
			const side = i % 4;
			const t = rnd();
			let x, y;
			if (side === 0) { x = w * t; y = 0; }
			else if (side === 1) { x = w; y = h * t; }
			else if (side === 2) { x = w * t; y = h; }
			else { x = 0; y = h * t; }
			const r = (8 + rnd() * 24) * (w / 480);
			ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function applyFoldCreases(ctx, w, h) {
		ctx.save();
		ctx.strokeStyle = 'rgba(60,36,24,0.18)';
		ctx.lineWidth = 1;
		ctx.beginPath(); ctx.moveTo(w / 3, 0); ctx.lineTo(w / 3, h);
		ctx.moveTo(w * 2 / 3, 0); ctx.lineTo(w * 2 / 3, h); ctx.stroke();
		ctx.strokeStyle = 'rgba(60,36,24,0.10)';
		ctx.beginPath(); ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2); ctx.stroke();
		ctx.restore();
	}

	function drawStarField(ctx, w, h, pal) {
		ctx.save();
		ctx.fillStyle = '#DCDCF0';
		let seed = (w * 5413 + h * 6271) & 0xffff;
		const rnd = () => { seed = (seed * 9301 + 49297) & 0xffff; return (seed % 1000) / 1000; };
		for (let i = 0; i < 80; i++) {
			const x = rnd() * w; const y = rnd() * h;
			const r = rnd() > 0.8 ? 2 : 1;
			ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function drawHeraldryMedallion(ctx, cx, cy, r, image, pal) {
		ctx.save();
		// Outer gilded ring
		const grad = ctx.createRadialGradient(cx, cy, r, cx, cy, r * 1.15);
		grad.addColorStop(0, pal.gold_highlight);
		grad.addColorStop(0.6, pal.gold);
		grad.addColorStop(1, ScrollPalette.darken(pal.gold, 0.4));
		ctx.fillStyle = grad;
		ctx.beginPath(); ctx.arc(cx, cy, r * 1.15, 0, Math.PI * 2); ctx.fill();
		// Inner parchment area
		ctx.fillStyle = pal.bg;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
		// Heraldry image (clipped circle)
		if (image && image.complete) {
			ctx.save();
			ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
			ctx.drawImage(image, cx - r, cy - r, r * 2, r * 2);
			ctx.restore();
		}
		ctx.restore();
	}

	return {
		drawFrame, drawSealStamp, drawHistoriatedInitial,
		drawDrolerie, drawBanderole, drawWaxSealEmboss,
		applyBurntEdge, applyFoldCreases, drawStarField,
		drawHeraldryMedallion,
	};
})();
