// Browser-side palette validator + color utilities.
// Mirrors system/lib/ork3/class.ScrollPalette.php — keep in sync.
// Required tokens: bg, text, accent, border, gold, gold_highlight, wax, ground_a.
window.ScrollPalette = (function() {
	const REQUIRED = ['bg','text','accent','border','gold','gold_highlight','wax','ground_a'];
	const FORBIDDEN = new Set(['#000000','#FFFFFF','#000','#FFF']);

	function validate(palette) {
		for (const t of REQUIRED) {
			if (!(t in palette)) return [false, `missing required token: ${t}`];
			const v = String(palette[t]).trim().toUpperCase();
			if (!/^#[0-9A-F]{3}([0-9A-F]{3})?$/.test(v)) return [false, `token ${t} is not a valid hex color: ${palette[t]}`];
			if (FORBIDDEN.has(v)) return [false, `token ${t} may not be pure black or pure white: ${palette[t]}`];
		}
		return [true, ''];
	}
	function hexToRgb(hex) {
		let h = hex.replace('#','');
		if (h.length === 3) h = h.split('').map(c => c+c).join('');
		return [parseInt(h.substr(0,2),16), parseInt(h.substr(2,2),16), parseInt(h.substr(4,2),16)];
	}
	function lighten(hex, pct) {
		const [r,g,b] = hexToRgb(hex);
		const f = (x) => Math.min(255, Math.round(x + (255-x)*pct));
		return '#' + [f(r), f(g), f(b)].map(x => x.toString(16).padStart(2,'0')).join('').toUpperCase();
	}
	function darken(hex, pct) {
		const [r,g,b] = hexToRgb(hex);
		const f = (x) => Math.max(0, Math.round(x * (1 - pct)));
		return '#' + [f(r), f(g), f(b)].map(x => x.toString(16).padStart(2,'0')).join('').toUpperCase();
	}
	function toRgba(hex, a) {
		const [r,g,b] = hexToRgb(hex);
		return `rgba(${r},${g},${b},${a})`;
	}
	return { validate, hexToRgb, lighten, darken, toRgba };
})();
