/**
 * Celtic Knot Border Renderer
 * Original implementation for ORK3 Scroll Generator.
 *
 * Renders a closed celtic knotwork border onto any Canvas 2D context.
 * Based on the well-known tile-based knotwork construction method:
 *   - A grid of "breaks" (none / horizontal / vertical) determines the pattern
 *   - Each visible cell maps to a tile based on its two nearest breaks + row/col parity
 *   - 5 base tile shapes are rotated/flipped to fill all 36 possible states
 *   - Closed borders are produced by placing breaks along every edge
 */
var CelticKnot = (function() {
  'use strict';

  // Break types
  var NONE = 0, HBREAK = 1, VBREAK = 2;

  // Parity
  var ODD = 1, EVEN = 0;

  // ---- Base tile drawing functions ----
  // Each receives (ctx, sz, strW, halfSz, halfStr) where sz=cellSize

  function tileStraightCross(ctx, sz, strW, halfSz, halfStr) {
    // Diagonal strand from bottom-left to top-right, crossing another
    var h = Math.round(strW / 1.414);
    ctx.beginPath();
    ctx.moveTo(0, sz);
    ctx.lineTo(0, sz - h);
    ctx.lineTo(sz - h, 0);
    ctx.lineTo(sz, 0);
    ctx.lineTo(sz, h);
    ctx.lineTo(h, sz);
    ctx.closePath();
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(0, sz - h);
    ctx.lineTo(sz - h, 0);
    ctx.moveTo(h, sz);
    ctx.lineTo(sz, h);
    ctx.lineTo(sz - h, 0);
    ctx.stroke();
  }

  function tileHLine(ctx, sz, strW, halfSz, halfStr) {
    ctx.fillRect(0, halfSz - halfStr, sz, strW);
    ctx.beginPath();
    ctx.moveTo(0, halfSz - halfStr);
    ctx.lineTo(sz, halfSz - halfStr);
    ctx.moveTo(0, halfSz + halfStr);
    ctx.lineTo(sz, halfSz + halfStr);
    ctx.stroke();
  }

  function tileCorner(ctx, sz, strW, halfSz, halfStr) {
    // Corner curving toward bottom-right
    ctx.beginPath();
    ctx.moveTo(halfSz - halfStr, 0);
    ctx.lineTo(halfSz + halfStr, 0);
    ctx.quadraticCurveTo(halfSz + halfStr, halfSz + halfStr, 0, halfSz + halfStr);
    ctx.lineTo(0, halfSz - halfStr);
    ctx.quadraticCurveTo(halfSz - halfStr, halfSz - halfStr, halfSz - halfStr, 0);
    ctx.closePath();
    ctx.fill();

    // Outer curve stroke
    ctx.beginPath();
    ctx.moveTo(halfSz + halfStr, 0);
    ctx.quadraticCurveTo(halfSz + halfStr, halfSz + halfStr, 0, halfSz + halfStr);
    // Inner curve stroke
    ctx.moveTo(0, halfSz - halfStr);
    ctx.quadraticCurveTo(halfSz - halfStr, halfSz - halfStr, halfSz - halfStr, 0);
    ctx.stroke();
  }

  function tileCurvedCross(ctx, sz, strW, halfSz, halfStr, crossOver) {
    // Vertical strand curving right at top, crossing another strand
    crossOver = crossOver !== false;
    var h = Math.round(strW / 1.414);
    var cpL = 2;

    function leftCurve() {
      ctx.bezierCurveTo(
        halfSz - halfStr, halfSz - h * 0.4,
        (sz - h) - cpL, cpL,
        sz - h, 0
      );
    }
    function rightCurve() {
      ctx.bezierCurveTo(
        sz - cpL, h + cpL,
        halfSz + halfStr, halfSz + h * 0.4,
        halfSz + halfStr, sz
      );
    }

    // Fill the curved strand shape
    ctx.beginPath();
    ctx.moveTo(halfSz - halfStr, sz);
    leftCurve();
    ctx.lineTo(sz, 0);
    ctx.lineTo(sz, h);
    rightCurve();
    ctx.closePath();
    ctx.fill();

    // Stroke outline
    ctx.beginPath();
    ctx.moveTo(halfSz - halfStr, sz);
    leftCurve();
    if (crossOver) {
      ctx.moveTo(sz, h);
    } else {
      ctx.lineTo(sz, h);
    }
    rightCurve();
    ctx.stroke();
  }

  function tileCurvedCrossUnder(ctx, sz, strW, halfSz, halfStr) {
    tileCurvedCross(ctx, sz, strW, halfSz, halfStr, false);
  }

  // ---- Transform helpers ----

  function rotate(fn, deg) {
    return function(ctx, sz, strW, halfSz, halfStr) {
      ctx.save();
      ctx.translate(halfSz, halfSz);
      ctx.rotate(deg * Math.PI / 180);
      ctx.translate(-halfSz, -halfSz);
      fn(ctx, sz, strW, halfSz, halfStr);
      ctx.restore();
    };
  }

  function flipH(fn) {
    return function(ctx, sz, strW, halfSz, halfStr) {
      ctx.save();
      ctx.scale(-1, 1);
      ctx.translate(-sz, 0);
      fn(ctx, sz, strW, halfSz, halfStr);
      ctx.restore();
    };
  }

  // ---- Build the 36-state tile lookup [break1][break2][rowParity][colParity] ----

  var T = [];
  var noop = function() {};
  for (var a = 0; a < 3; a++) {
    T[a] = [];
    for (var b = 0; b < 3; b++) {
      T[a][b] = [[noop, noop], [noop, noop]];
    }
  }

  // No breaks: diagonal crossings at all 4 parities
  T[NONE][NONE][ODD][ODD]   = tileStraightCross;
  T[NONE][NONE][ODD][EVEN]  = rotate(tileStraightCross, 90);
  T[NONE][NONE][EVEN][EVEN] = rotate(tileStraightCross, 180);
  T[NONE][NONE][EVEN][ODD]  = rotate(tileStraightCross, 270);

  // Both horizontal: straight horizontal lines
  T[HBREAK][HBREAK][EVEN][EVEN] = tileHLine;
  T[HBREAK][HBREAK][ODD][ODD]   = tileHLine;
  T[HBREAK][HBREAK][EVEN][ODD]  = tileHLine;
  T[HBREAK][HBREAK][ODD][EVEN]  = tileHLine;

  // Both vertical: straight vertical lines
  var tileVLine = rotate(tileHLine, 90);
  T[VBREAK][VBREAK][EVEN][EVEN] = tileVLine;
  T[VBREAK][VBREAK][ODD][ODD]   = tileVLine;
  T[VBREAK][VBREAK][EVEN][ODD]  = tileVLine;
  T[VBREAK][VBREAK][ODD][EVEN]  = tileVLine;

  // H + V corners
  T[HBREAK][VBREAK][EVEN][EVEN] = tileCorner;
  T[HBREAK][VBREAK][EVEN][ODD]  = rotate(tileCorner, 90);
  T[HBREAK][VBREAK][ODD][ODD]   = tileCorner;
  T[HBREAK][VBREAK][ODD][EVEN]  = rotate(tileCorner, 90);

  T[VBREAK][HBREAK][EVEN][EVEN] = rotate(tileCorner, 180);
  T[VBREAK][HBREAK][ODD][ODD]   = rotate(tileCorner, 180);
  T[VBREAK][HBREAK][EVEN][ODD]  = rotate(tileCorner, 270);
  T[VBREAK][HBREAK][ODD][EVEN]  = rotate(tileCorner, 270);

  // V + NONE: curved crossings
  T[VBREAK][NONE][EVEN][EVEN] = tileCurvedCross;
  T[VBREAK][NONE][ODD][ODD]   = tileCurvedCrossUnder;
  T[VBREAK][NONE][EVEN][ODD]  = flipH(tileCurvedCrossUnder);
  T[VBREAK][NONE][ODD][EVEN]  = flipH(tileCurvedCross);

  T[NONE][VBREAK][EVEN][EVEN] = rotate(tileCurvedCrossUnder, 180);
  T[NONE][VBREAK][EVEN][ODD]  = rotate(flipH(tileCurvedCross), 180);
  T[NONE][VBREAK][ODD][ODD]   = rotate(tileCurvedCross, 180);
  T[NONE][VBREAK][ODD][EVEN]  = rotate(flipH(tileCurvedCrossUnder), 180);

  // H + NONE: curved crossings (rotated)
  T[HBREAK][NONE][EVEN][EVEN] = rotate(flipH(tileCurvedCross), 90);
  T[HBREAK][NONE][EVEN][ODD]  = rotate(tileCurvedCrossUnder, 270);
  T[HBREAK][NONE][ODD][ODD]   = rotate(flipH(tileCurvedCrossUnder), 90);
  T[HBREAK][NONE][ODD][EVEN]  = rotate(tileCurvedCross, 270);

  T[NONE][HBREAK][EVEN][EVEN] = rotate(flipH(tileCurvedCrossUnder), 270);
  T[NONE][HBREAK][EVEN][ODD]  = rotate(tileCurvedCross, 90);
  T[NONE][HBREAK][ODD][ODD]   = rotate(flipH(tileCurvedCross), 270);
  T[NONE][HBREAK][ODD][EVEN]  = rotate(tileCurvedCrossUnder, 90);

  // ---- Pattern generation ----

  function emptyPattern(rows, cols) {
    var p = [];
    for (var r = 0; r < rows; r++) {
      p[r] = [];
      for (var c = 0; c < cols; c++) p[r][c] = NONE;
    }
    return p;
  }

  function closedBorderPattern(gridRows, gridCols) {
    var bRows = gridRows + 1;
    var bCols = gridCols / 2 + 1;
    var breaks = emptyPattern(bRows, bCols);

    // Top and bottom edges: horizontal breaks
    for (var c = 0; c < bCols - 1; c++) {
      breaks[0][c] = HBREAK;
      breaks[bRows - 1][c] = HBREAK;
    }
    // Left and right edges: vertical breaks on odd rows
    for (var r = 1; r < bRows; r += 2) {
      breaks[r][0] = VBREAK;
      breaks[r][bCols - 1] = VBREAK;
    }
    return breaks;
  }

  function symmetricRandomPattern(gridRows, gridCols, density) {
    density = density || 0.3;
    var bRows = gridRows + 1;
    var bCols = gridCols / 2 + 1;
    var breaks = closedBorderPattern(gridRows, gridCols);
    var states = [NONE, VBREAK, HBREAK];
    var totalBreaks = Math.floor(bRows * bCols * density);

    for (var i = 0; i < totalBreaks; i++) {
      var r = Math.floor(Math.random() * (bRows - 2)) + 1; // skip edges
      var maxC = (r % 2) ? bCols - 2 : bCols - 3;
      if (maxC < 1) continue;
      var c = Math.floor(Math.random() * maxC) + 1;

      var allowed = states;
      if (r <= 1 || r >= bRows - 2) allowed = [NONE, HBREAK];
      else if (c <= 0 || c >= maxC) allowed = [NONE, VBREAK];

      var val = allowed[Math.floor(Math.random() * allowed.length)];
      var mirC = (bCols - 1) - c;
      breaks[r][c] = val;
      // Mirror horizontally for symmetry
      breaks[r][mirC] = val;
      // Mirror vertically too (4-quadrant symmetry)
      var rMir = bRows - r - 1;
      if (rMir !== r) {
        breaks[rMir][c] = val;
        breaks[rMir][mirC] = val;
      }
    }
    return breaks;
  }

  // ---- Core renderer ----

  function render(ctx, opts) {
    var rows    = opts.rows;
    var cols    = opts.columns;
    var sz      = opts.cellSize;
    var strW    = opts.stringSize;
    var halfSz  = sz / 2;
    var halfStr = strW / 2;
    var breaks  = opts.breaks;

    ctx.save();
    ctx.lineCap = 'square';
    ctx.lineJoin = 'round';
    ctx.fillStyle = opts.fillColor || '#c4972a';
    ctx.strokeStyle = opts.strokeColor || '#6b5a32';
    ctx.lineWidth = opts.strokeWidth || 1;

    if (opts.offsetX || opts.offsetY) {
      ctx.translate(opts.offsetX || 0, opts.offsetY || 0);
    }

    for (var x = 0; x < cols; x++) {
      for (var y = 0; y < rows; y++) {
        ctx.save();
        ctx.translate(x * sz, y * sz);

        var rowP = (y + 1) % 2;
        var colP = (x + 1) % 2;
        var b1 = NONE, b2 = NONE;

        if (colP === 1) {
          b1 = breaks[y + 1][x / 2];
          b2 = breaks[y][x / 2];
        } else {
          if (rowP === 1) {
            b1 = breaks[y + 1][(x + 1) / 2];
            b2 = breaks[y][(x - 1) / 2];
          } else {
            b1 = breaks[y + 1][(x - 1) / 2];
            b2 = breaks[y][(x + 1) / 2];
          }
        }

        var fn = T[b1][b2][rowP][colP];
        fn(ctx, sz, strW, halfSz, halfStr);

        ctx.restore();
      }
    }
    ctx.restore();
  }

  // ---- Public API ----
  return {
    closedBorderPattern: closedBorderPattern,
    symmetricRandomPattern: symmetricRandomPattern,
    render: render
  };
})();
