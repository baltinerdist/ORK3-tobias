#!/usr/bin/env python3
"""Hibernian Knotwork interlace SVG generator (Scroll Forge Wave 1).

Generates the three currentColor-tintable frame pieces consumed by the
ornament composer (plan Task 3):

	system/assets/scroll/forge/families/hibernian_knotwork/corner_nw.svg
	system/assets/scroll/forge/families/hibernian_knotwork/edge_top.svg
	system/assets/scroll/forge/families/hibernian_knotwork/medallion.svg

This is a Python port of the plait/interlace construction in the legacy
canvas renderer `assets/scroll/celticknot.js`.  That renderer builds a
closed knot band from a break-grid: strands run diagonally between the
band walls, bounce (turn) where a break/wall stops them, and cross the
opposing strand midway between bounces, with over/under alternating by
grid parity (the [break1][break2][rowParity][colParity] tile table).
Here the same walk is expressed directly as strand centerline polylines:

  * vertices  = the wall bounces (the legacy tileCorner / curved-cross
	turns), smoothed into quadratic arcs;
  * crossings = computed segment intersections (the legacy straight/
	curved cross tiles), over/under alternating along each strand
	exactly like the parity checkerboard.

Over/under weaving uses the SPLIT-SEGMENT technique (plan Task 9): the
"under" strand's centerline is cut short on both sides of each crossing
(gap sized from the stroke widths, the crossing angle and the round line
caps), so the over strand visibly passes on top.  No masks, no painted
ground color — everything is `stroke="currentColor"` so the composer's
CSS tint (family --border) flows in, and the pieces sit on ANY ground.

Deterministic: pure geometry, no randomness — regeneration is
diff-stable.  Run:  python3 tools/gen_knotwork.py
"""

import re
import sys
from math import hypot, cos, sin, pi, sqrt

OUT_DIR = "system/assets/scroll/forge/families/hibernian_knotwork"

# Visible clearance (in viewBox units) between the cut end of an under
# strand and the edge of the over strand, before accounting for caps.
MIN_MARGIN = 0.1  # geometric slack required by the self-checks


def fmt(v):
	"""Format a coordinate: max 2 decimals, no trailing zeros, no -0."""
	s = "%.2f" % v
	s = s.rstrip("0").rstrip(".")
	if s in ("-0", ""):
		s = "0"
	return s


# ── geometry primitives ─────────────────────────────────────────────────────

def sub(a, b):
	return (a[0] - b[0], a[1] - b[1])


def unit(v):
	l = hypot(v[0], v[1])
	return (v[0] / l, v[1] / l)


def seg_intersect(a1, a2, b1, b2):
	"""Proper interior intersection of segments a1a2 / b1b2.
	Returns (t, u, point) or None (parallel / touching at endpoints)."""
	dax, day = a2[0] - a1[0], a2[1] - a1[1]
	dbx, dby = b2[0] - b1[0], b2[1] - b1[1]
	den = dax * dby - day * dbx
	if abs(den) < 1e-9:
		return None
	t = ((b1[0] - a1[0]) * dby - (b1[1] - a1[1]) * dbx) / den
	u = ((b1[0] - a1[0]) * day - (b1[1] - a1[1]) * dax) / den
	if t <= 1e-3 or t >= 1 - 1e-3 or u <= 1e-3 or u >= 1 - 1e-3:
		return None
	return t, u, (a1[0] + t * dax, a1[1] + t * day)


class Strand:
	"""A woven strand: a polyline centerline (open or closed)."""

	def __init__(self, name, pts, closed=False, stroke=4.4, smooth=6.0,
			smooth_overrides=None):
		self.name = name
		self.pts = pts
		self.closed = closed
		self.stroke = stroke
		self.smooth = smooth
		# vertex index -> smoothing radius (else self.smooth)
		self.smooth_overrides = smooth_overrides or {}

	def nseg(self):
		return len(self.pts) if self.closed else len(self.pts) - 1

	def seg(self, i):
		return self.pts[i], self.pts[(i + 1) % len(self.pts)]

	def seg_len(self, i):
		p, q = self.seg(i)
		return hypot(q[0] - p[0], q[1] - p[1])

	def seg_dir(self, i):
		p, q = self.seg(i)
		return unit(sub(q, p))

	def point_at(self, i, t):
		p, q = self.seg(i)
		return (p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1]))

	def smooth_at(self, vertex_idx):
		"""Smoothing radius at the vertex STARTING segment vertex_idx."""
		n = len(self.pts)
		if not self.closed and (vertex_idx == 0 or vertex_idx == n - 1):
			return 0.0  # open strand endpoints are not smoothed
		return self.smooth_overrides.get(vertex_idx % n, self.smooth)


class Ring:
	"""A decorative circle that always weaves OVER the strands it meets
	(a ring threaded onto a strand). Gaps land on the strand only."""

	def __init__(self, name, cx, cy, r, stroke=4.4):
		self.name = name
		self.cx, self.cy, self.r = cx, cy, r
		self.stroke = stroke


class Crossing:
	def __init__(self, pt, a, seg_a, t_a, b, seg_b, t_b, angle_sin):
		self.pt = pt
		self.a, self.seg_a, self.t_a = a, seg_a, t_a
		self.b, self.seg_b, self.t_b = b, seg_b, t_b
		self.angle_sin = angle_sin  # sin of crossing angle
		self.over = None            # strand/ring name drawn on top
		self.forced = False

	def involves(self, name):
		return self.a.name == name or self.b.name == name

	def leg(self, name):
		if self.a.name == name:
			return self.seg_a, self.t_a
		return self.seg_b, self.t_b

	def other(self, name):
		return self.b if self.a.name == name else self.a


def find_crossings(strands, rings=()):
	"""All strand x strand and ring x strand crossings."""
	crossings = []
	for i in range(len(strands)):
		for j in range(i + 1, len(strands)):
			sa, sb = strands[i], strands[j]
			for ia in range(sa.nseg()):
				a1, a2 = sa.seg(ia)
				for ib in range(sb.nseg()):
					b1, b2 = sb.seg(ib)
					hit = seg_intersect(a1, a2, b1, b2)
					if hit is None:
						continue
					t, u, pt = hit
					da, db = sa.seg_dir(ia), sb.seg_dir(ib)
					cross = abs(da[0] * db[1] - da[1] * db[0])
					crossings.append(Crossing(pt, sa, ia, t, sb, ib, u, cross))
	for ring in rings:
		for s in strands:
			for i in range(s.nseg()):
				p, q = s.seg(i)
				# circle/segment intersection: |p + t(q-p) - c|^2 = r^2
				dx, dy = q[0] - p[0], q[1] - p[1]
				fx, fy = p[0] - ring.cx, p[1] - ring.cy
				A = dx * dx + dy * dy
				B = 2 * (fx * dx + fy * dy)
				C = fx * fx + fy * fy - ring.r * ring.r
				disc = B * B - 4 * A * C
				if disc <= 0:
					continue
				rt = sqrt(disc)
				for t in ((-B - rt) / (2 * A), (-B + rt) / (2 * A)):
					if t <= 1e-3 or t >= 1 - 1e-3:
						continue
					pt = (p[0] + t * dx, p[1] + t * dy)
					# tangent of the circle at pt vs segment direction
					radial = unit(sub(pt, (ring.cx, ring.cy)))
					tangent = (-radial[1], radial[0])
					d = s.seg_dir(i)
					cross = abs(d[0] * tangent[1] - d[1] * tangent[0])
					c = Crossing(pt, ring, -1, t, s, i, t, cross)
					c.over = ring.name
					c.forced = True
					crossings.append(c)
	return crossings


def assign_weave(strands, crossings, seed_name):
	"""Alternate over/under along the seed strand (which, by design,
	participates in every non-forced crossing), then verify that EVERY
	strand's non-forced crossings alternate — the parity checkerboard
	property of the legacy tile table."""
	def order_key(name):
		return lambda c: c.leg(name)

	seed = [c for c in crossings if not c.forced and c.involves(seed_name)]
	unforced = [c for c in crossings if not c.forced]
	if len(seed) != len(unforced):
		raise AssertionError("seed strand %s must touch every crossing" % seed_name)
	seed.sort(key=order_key(seed_name))
	for idx, c in enumerate(seed):
		c.over = seed_name if idx % 2 == 0 else c.other(seed_name).name
	# verify alternation per strand
	for s in strands:
		mine = [c for c in crossings if not c.forced and c.involves(s.name)]
		mine.sort(key=order_key(s.name))
		states = [c.over == s.name for c in mine]
		for k in range(1, len(states)):
			if states[k] == states[k - 1]:
				raise AssertionError(
					"weave not alternating along %s at crossing %d" % (s.name, k))


def gap_half_length(under_stroke, over_stroke, clearance, angle_sin):
	"""Distance from crossing center to the under strand's cut point.
	The round linecap regrows under_stroke/2 of ink past the cut (along
	the path), and the over strand's edge sits (over_stroke/2)/sin(angle)
	from the crossing center measured along the under path."""
	return under_stroke / 2.0 + (over_stroke / 2.0 + clearance) / max(angle_sin, 0.2)


def build_gaps(strand, crossings, clearance):
	"""Per-segment sorted gap windows (t0,t1) where strand goes UNDER."""
	gaps = {}
	for c in crossings:
		if not c.involves(strand.name) or c.over == strand.name:
			continue
		seg_i, t = c.leg(strand.name)
		other = c.other(strand.name)
		hg = gap_half_length(strand.stroke, other.stroke, clearance, c.angle_sin)
		length = strand.seg_len(seg_i)
		lo, hi = t - hg / length, t + hg / length
		# self-check: the cut must stay on the straight part of the segment,
		# clear of the smoothing arcs at both vertices
		s_start = strand.smooth_at(seg_i)
		s_end = strand.smooth_at(seg_i + 1)
		if lo * length < s_start + MIN_MARGIN or (1 - hi) * length < s_end + MIN_MARGIN:
			raise AssertionError(
				"%s seg %d: gap [%.2f..%.2f] collides with smoothing (%s/%s)"
				% (strand.name, seg_i, lo * length, hi * length, s_start, s_end))
		gaps.setdefault(seg_i, []).append((max(lo, 0.0), min(hi, 1.0)))
	for k in gaps:
		gaps[k].sort()
		merged = [gaps[k][0]]
		for lo, hi in gaps[k][1:]:
			if lo <= merged[-1][1]:
				merged[-1] = (merged[-1][0], max(hi, merged[-1][1]))
			else:
				merged.append((lo, hi))
		gaps[k] = merged
	return gaps


def strand_paths(strand, gaps):
	"""Emit one SVG path 'd' per continuous run between gaps, smoothing
	interior vertices with quadratic arcs (the legacy tileCorner turns)."""
	n = strand.nseg()
	# keep-intervals per segment
	pieces = []  # (seg, t0, t1) in traversal order
	for i in range(n):
		windows = gaps.get(i, [])
		t = 0.0
		for lo, hi in windows:
			if lo > t:
				pieces.append((i, t, lo))
			t = hi
		if t < 1.0:
			pieces.append((i, t, 1.0))
	if not pieces:
		return []
	# group contiguous pieces into runs
	runs = [[pieces[0]]]
	for p in pieces[1:]:
		prev = runs[-1][-1]
		if prev[2] == 1.0 and p[1] == 0.0 and p[0] == prev[0] + 1:
			runs[-1].append(p)
		else:
			runs.append([p])
	closed_loop = False
	if strand.closed and len(runs) > 1:
		first, last = runs[0], runs[-1]
		if last[-1][2] == 1.0 and first[0][1] == 0.0 \
				and last[-1][0] == n - 1 and first[0][0] == 0:
			runs[0] = last + first
			runs.pop()
	elif strand.closed and len(runs) == 1 and not gaps:
		closed_loop = True

	out = []
	for run in runs:
		d = []
		start = strand.point_at(run[0][0], run[0][1])
		d.append("M%s %s" % (fmt(start[0]), fmt(start[1])))
		for k in range(len(run)):
			seg_i, t0, t1 = run[k]
			end = strand.point_at(seg_i, t1)
			nxt = run[(k + 1) % len(run)] if (k + 1 < len(run) or closed_loop) else None
			joins_next = nxt is not None and t1 == 1.0 and nxt[1] == 0.0
			if joins_next:
				v = strand.pts[(seg_i + 1) % len(strand.pts)]
				r = strand.smooth_at(seg_i + 1)
				if r > 0:
					din = strand.seg_dir(seg_i)
					dout = strand.seg_dir((seg_i + 1) % n)
					a = (v[0] - r * din[0], v[1] - r * din[1])
					b = (v[0] + r * dout[0], v[1] + r * dout[1])
					d.append("L%s %s" % (fmt(a[0]), fmt(a[1])))
					d.append("Q%s %s %s %s" % (fmt(v[0]), fmt(v[1]), fmt(b[0]), fmt(b[1])))
				else:
					d.append("L%s %s" % (fmt(v[0]), fmt(v[1])))
			else:
				d.append("L%s %s" % (fmt(end[0]), fmt(end[1])))
		if closed_loop:
			d.append("Z")
		out.append(" ".join(d))
	return out


def circle_path(cx, cy, r):
	return ("M%s %s A%s %s 0 1 0 %s %s A%s %s 0 1 0 %s %s Z"
		% (fmt(cx - r), fmt(cy), fmt(r), fmt(r), fmt(cx + r), fmt(cy),
			fmt(r), fmt(r), fmt(cx - r), fmt(cy)))


# ── self-checks ─────────────────────────────────────────────────────────────

def check_bounds(label, strands, rings, rails_pts, w, h):
	for s in strands:
		for p in s.pts:
			if not (0 <= p[0] <= w and 0 <= p[1] <= h):
				raise AssertionError("%s: %s vertex %s outside viewBox" % (label, s.name, p))
	for r in rings:
		if not (r.r < r.cx < w - r.r and r.r < r.cy < h - r.r):
			raise AssertionError("%s: ring %s outside viewBox" % (label, r.name))
	for p in rails_pts:
		if not (0 <= p[0] <= w and 0 <= p[1] <= h):
			raise AssertionError("%s: rail point %s outside viewBox" % (label, p))


def svg_doc(viewbox, groups, preserve=None, note=""):
	pa = ' preserveAspectRatio="%s"' % preserve if preserve else ""
	head = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s"%s>\n'
		'\t<!-- Hibernian Knotwork %s — generated by tools/gen_knotwork.py'
		' (deterministic; do not hand-edit). All strokes currentColor. -->\n'
		% (viewbox, pa, note))
	body = []
	body.append('\t<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">')
	for stroke_w, paths in groups:
		body.append('\t\t<g stroke-width="%s">' % fmt(stroke_w))
		for d in paths:
			body.append('\t\t\t<path d="%s"/>' % d)
		body.append('\t\t</g>')
	body.append('\t</g>')
	return head + "\n".join(body) + "\n</svg>\n"


# ── the three pieces ────────────────────────────────────────────────────────

def build_edge():
	"""8-crossing two-strand plait ribbon, 400x40, stretch-tolerant."""
	stroke, smooth, clearance = 5.0, 8.0, 1.3
	ya, yb, n_half = 5.0, 32.0, 8  # extrema walls; 8 half-periods = 8 crossings
	step = 400.0 / n_half
	a_pts = [(k * step, ya if k % 2 == 0 else yb) for k in range(n_half + 1)]
	b_pts = [(k * step, yb if k % 2 == 0 else ya) for k in range(n_half + 1)]
	A = Strand("A", a_pts, stroke=stroke, smooth=smooth)
	B = Strand("B", b_pts, stroke=stroke, smooth=smooth)
	strands = [A, B]
	crossings = find_crossings(strands)
	assert len(crossings) == 8, "edge expects 8 crossings, got %d" % len(crossings)
	assign_weave(strands, crossings, "A")
	paths = []
	for s in strands:
		paths += strand_paths(s, build_gaps(s, crossings, clearance))
	rails = ["M0 1.2 L400 1.2", "M0 35.8 L400 35.8"]
	check_bounds("edge_top", strands, [], [(0, 1.2), (400, 35.8)], 400, 40)
	svg = svg_doc("0 0 400 40", [(stroke, paths), (1.4, rails)],
		preserve="none", note="edge strip (8x1 plait)")
	return svg, crossings, paths + rails


def build_corner():
	"""L-band corner knot, 100x100. The two edge strands turn the corner
	on the 45-degree lattice (walls y/x = 4 and 28, crossing rows y/x = 16);
	a ring threaded onto the outer miter diagonal dresses the corner.
	Entry stubs: right edge at y=4 and y=28, bottom edge at x=4 and x=28
	(the offsets the edge strips meet — see plan Task 9)."""
	stroke, clearance = 4.2, 1.0
	P = Strand("P", [(100, 4), (76, 28), (52, 4), (4, 52), (28, 76), (4, 100)],
		stroke=stroke, smooth=6.0)
	Q = Strand("Q", [(100, 28), (76, 4), (52, 28), (28, 4), (4, 28),
		(28, 52), (4, 76), (28, 100)],
		stroke=stroke, smooth=6.0, smooth_overrides={3: 3.2, 4: 3.2})
	ring = Ring("ring", 16, 16, 8, stroke=stroke)
	strands = [P, Q]
	crossings = find_crossings(strands, [ring])
	n_strand = sum(1 for c in crossings if not c.forced)
	n_ring = sum(1 for c in crossings if c.forced)
	assert n_strand == 6, "corner expects 6 strand crossings, got %d" % n_strand
	assert n_ring == 2, "corner expects 2 ring crossings, got %d" % n_ring
	assign_weave(strands, crossings, "P")
	paths = []
	for s in strands:
		paths += strand_paths(s, build_gaps(s, crossings, clearance))
	paths.append(circle_path(ring.cx, ring.cy, ring.r))  # ring drawn last = on top
	rails = [
		"M100 1.2 L9 1.2 Q1.2 1.2 1.2 9 L1.2 100",     # outer rail
		"M100 31.4 L38 31.4 Q31.4 31.4 31.4 38 L31.4 100",  # inner rail
	]
	check_bounds("corner_nw", strands, [ring],
		[(100, 1.2), (1.2, 100), (100, 31.4), (31.4, 100)], 100, 100)
	svg = svg_doc("0 0 100 100", [(stroke, paths), (1.2, rails)],
		note="NW corner (L-band knot + threaded ring)")
	return svg, crossings, paths + rails


def build_medallion():
	"""Circular twist roundel, 100x100: two closed strands winding between
	inner/outer walls with 8 alternating crossings, plus rail rings."""
	stroke, smooth, clearance = 4.6, 4.0, 1.2
	cx = cy = 50.0
	r_out, r_in, n = 42.0, 24.0, 8
	a_pts, b_pts = [], []
	for k in range(n):
		ang = (k + 0.5) * (2 * pi / n) - pi / 2
		ra = r_out if k % 2 == 0 else r_in
		rb = r_in if k % 2 == 0 else r_out
		a_pts.append((cx + ra * cos(ang), cy + ra * sin(ang)))
		b_pts.append((cx + rb * cos(ang), cy + rb * sin(ang)))
	A = Strand("A", a_pts, closed=True, stroke=stroke, smooth=smooth)
	B = Strand("B", b_pts, closed=True, stroke=stroke, smooth=smooth)
	strands = [A, B]
	crossings = find_crossings(strands)
	assert len(crossings) == 8, "medallion expects 8 crossings, got %d" % len(crossings)
	assign_weave(strands, crossings, "A")
	paths = []
	for s in strands:
		paths += strand_paths(s, build_gaps(s, crossings, clearance))
	center = [circle_path(cx, cy, 7)]
	rails = [circle_path(cx, cy, 46.5), circle_path(cx, cy, 19.5)]
	check_bounds("medallion", strands, [Ring("c", cx, cy, 7), Ring("o", cx, cy, 46.5)],
		[], 100, 100)
	svg = svg_doc("0 0 100 100", [(stroke, paths + center), (1.2, rails)],
		note="medallion roundel (circular twist)")
	return svg, crossings, paths + center + rails


# ── main ────────────────────────────────────────────────────────────────────

def main():
	import os
	os.makedirs(OUT_DIR, exist_ok=True)
	builds = [
		("edge_top.svg", build_edge),
		("corner_nw.svg", build_corner),
		("medallion.svg", build_medallion),
	]
	for fname, fn in builds:
		svg, crossings, paths = fn()
		n_paths = svg.count("<path")
		if n_paths < 6:
			raise AssertionError("%s: only %d paths (need >= 6)" % (fname, n_paths))
		if "currentColor" not in svg:
			raise AssertionError("%s: missing currentColor" % fname)
		# every coordinate in every d attribute must sit inside the viewBox
		vb = re.search(r'viewBox="0 0 (\d+) (\d+)"', svg)
		w, h = float(vb.group(1)), float(vb.group(2))
		for d in re.findall(r'd="([^"]+)"', svg):
			nums = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', d)]
			pairs = []
			it = iter(re.findall(r'[MLQAZ]|-?\d+(?:\.\d+)?', d))
			cmd = None
			buf = []
			for tok in it:
				if tok in "MLQAZ":
					cmd = tok
					buf = []
					continue
				buf.append(float(tok))
				if cmd in "ML" and len(buf) == 2:
					pairs.append(tuple(buf)); buf = []
				elif cmd == "Q" and len(buf) == 4:
					pairs.append((buf[0], buf[1])); pairs.append((buf[2], buf[3])); buf = []
				elif cmd == "A" and len(buf) == 7:
					pairs.append((buf[5], buf[6])); buf = []
			for (x, y) in pairs:
				if not (-0.01 <= x <= w + 0.01 and -0.01 <= y <= h + 0.01):
					raise AssertionError("%s: coord (%s,%s) outside viewBox" % (fname, x, y))
		path = os.path.join(OUT_DIR, fname)
		with open(path, "w") as f:
			f.write(svg)
		unders = sum(1 for c in crossings)
		print("%-14s %2d paths, %d crossings, viewBox %dx%d -> %s"
			% (fname, n_paths, len(crossings), w, h, path))
	print("gen_knotwork: OK (deterministic — rerun yields identical bytes)")


if __name__ == "__main__":
	main()
