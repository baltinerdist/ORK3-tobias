/* ============================================================
   ORK3 Survey — Results page controller  (survey-results.js)

   Talks to SurveyAjax/results and SurveyAjax/rows (design spec §6)
   and draws one card per question with the chart the spec's §7
   table prescribes.

   Colour policy (dataviz method):
   - Categorical identity uses a fixed eight-hue order, never cycled,
     assigned in sequence. Both mode palettes were validated with the
     six-check validator (adjacent pairs: worst CVD ΔE 9.1 light /
     8.4 dark, worst normal-vision ΔE 19.6 / 19.3).
   - A single-series bar or column is ONE hue — bar length already
     encodes the value, so identity colour is not spent re-encoding it.
   - Matrix columns are ORDINAL (strongly disagree → strongly agree),
     so they take a one-hue blue ramp with monotone lightness, clamped
     to the steps that still clear 2:1 on each surface.
   - NPS is POLARITY, so it takes the documented diverging pair
     (blue ↔ red) with a neutral gray midpoint for passives. The mid
     step is a visible gray rather than the near-surface one because
     these are bar segments, not heatmap cells.
   - Three light-mode hues sit under 3:1 on the light surface, so the
     relief rule applies: every bar/column carries a visible direct
     label, and the full row-level table below the charts is the
     table view.

   Highcharts: orkui.js inlines Highcharts 3.0.7 and owns the
   window.Highcharts global. Survey_results.tpl loads 11.4.8 inside a
   sandbox that hides that global for the duration of the load and
   republishes the fresh copy as window.SvHighcharts, so this file must
   never touch window.Highcharts - that is still the 3.0.7 build.
   ============================================================ */
(function () {
    'use strict';

    var CFG       = window.SvConfig || {};
    var UIR       = CFG.uir || '';
    var SURVEY_ID = parseInt(CFG.surveyId, 10) || 0;
    var QUESTIONS = Array.isArray(CFG.questions) ? CFG.questions : [];

    if (!SURVEY_ID) { return; }

    var TEXT_TYPES     = { short_text: 1, paragraph: 1 };
    var TEXT_PREVIEW   = 20;    /* responses shown before "Show all" */
    var ROWS_PAGE      = 100;

    /* ---------------------------------------------------------
       Palette (see the header note; values from the validated
       reference palette, not eyeballed)
       --------------------------------------------------------- */

    var SV_COLORS = {
        light: ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948'],
        dark : ['#3987e5', '#d95926', '#199e70', '#c98500', '#d55181', '#008300', '#9085e9', '#e66767']
    };

    /* One-hue ordinal ramp, light → dark. Light starts at step 250 and dark
       stops at step 600 so the end nearest each surface still clears 2:1. */
    var SV_RAMP = {
        light: ['#86b6ef', '#6da7ec', '#5598e7', '#3987e5', '#2a78d6', '#256abf', '#1c5cab', '#184f95', '#104281', '#0d366b'],
        dark : ['#cde2fb', '#b7d3f6', '#9ec5f4', '#86b6ef', '#6da7ec', '#5598e7', '#3987e5', '#2a78d6', '#256abf', '#184f95']
    };

    /* Diverging pair + neutral midpoint, for NPS polarity. */
    var SV_DIVERGING = {
        light: { neg: '#e34948', mid: '#a0aec0', pos: '#2a78d6' },
        dark : { neg: '#e66767', mid: '#718096', pos: '#3987e5' }
    };

    /* ---------------------------------------------------------
       Small helpers
       --------------------------------------------------------- */

    function $(id) { return document.getElementById(id); }

    function esc(s) {
        return String(s === null || s === undefined ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function num(v, dp) {
        if (v === null || v === undefined || v === '') { return '—'; }
        var n = Number(v);
        if (!isFinite(n)) { return '—'; }
        if (dp === undefined) { dp = 0; }
        return n.toFixed(dp).replace(/\.0+$/, '').replace(/(\.\d*?)0+$/, '$1');
    }

    function pct(v) {
        if (v === null || v === undefined) { return '—'; }
        return num(v, 1) + '%';
    }

    function duration(secs) {
        if (secs === null || secs === undefined || secs === '') { return '—'; }
        var s = Math.max(0, Math.round(Number(secs)));
        if (!isFinite(s)) { return '—'; }
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + 'm ' + (r < 10 ? '0' : '') + r + 's';
    }

    function monthLabel(iso) {
        var m = /^(\d{4})-(\d{2})$/.exec(String(iso || ''));
        if (!m) { return String(iso || ''); }
        var names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return names[parseInt(m[2], 10) - 1] + ' ' + m[1];
    }

    function typeLabel(t) {
        var map = {
            single: 'Single choice', multi: 'Multiple choice', dropdown: 'Dropdown', yesno: 'Yes / No',
            rating: 'Rating', nps: 'Net promoter', matrix: 'Matrix', ranking: 'Ranking',
            short_text: 'Short text', paragraph: 'Paragraph', number: 'Number', date: 'Date'
        };
        return map[t] || t;
    }

    /* Sample n evenly spaced steps out of an ordinal ramp. */
    function rampSteps(ramp, n) {
        if (n <= 0) { return []; }
        if (n === 1) { return [ramp[Math.floor(ramp.length / 2)]]; }
        var out = [];
        for (var i = 0; i < n; i++) {
            out.push(ramp[Math.round(i * (ramp.length - 1) / (n - 1))]);
        }
        return out;
    }

    /* ---------------------------------------------------------
       Theme
       --------------------------------------------------------- */

    /* Set while the browser is producing print output: paper is white whatever
       the screen theme is, and browsers drop the dark card background, so the
       dark chart palette would print near-white labels on white. */
    var printingLight = false;

    function svIsDark() {
        if (printingLight) { return false; }
        var a = document.documentElement.getAttribute('data-theme');
        if (a === 'dark') { return true; }
        if (a === 'light') { return false; }
        return !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    }

    function svChartTheme() {
        var dk = svIsDark();
        return {
            dark   : dk,
            colors : dk ? SV_COLORS.dark : SV_COLORS.light,
            ramp   : dk ? SV_RAMP.dark : SV_RAMP.light,
            div    : dk ? SV_DIVERGING.dark : SV_DIVERGING.light,
            text   : dk ? '#e2e8f0' : '#2d3748',
            muted  : dk ? '#a0aec0' : '#718096',
            grid   : dk ? '#3a4557' : '#e6e6e6',
            line   : dk ? '#4a5568' : '#ccd6eb',
            /* Card background — the 2px gap colour between stacked segments. */
            surface: dk ? '#2d3748' : '#ffffff',
            tipBg  : dk ? '#1a2035' : '#ffffff',
            tipEdge: dk ? '#818cf8' : '#cbd5e0'
        };
    }

    function baseCfg(theme, type) {
        return {
            chart: {
                type           : type,
                backgroundColor: 'transparent',
                style          : { fontFamily: 'inherit' },
                spacing        : [8, 8, 8, 8],
                animation      : false
            },
            title  : { text: null },
            credits: { enabled: false },
            legend : {
                enabled       : false,
                itemStyle     : { color: theme.muted, fontWeight: '600', fontSize: '11px' },
                itemHoverStyle: { color: theme.text }
            },
            tooltip: {
                backgroundColor: theme.tipBg,
                borderColor    : theme.tipEdge,
                borderWidth    : 1,
                shadow         : false,
                style          : { color: theme.text, fontSize: '12px' }
            },
            xAxis: {
                labels    : { style: { color: theme.muted, fontSize: '11px' } },
                lineColor : theme.line,
                tickColor : theme.line
            },
            yAxis: {
                title        : { text: null },
                gridLineColor: theme.grid,
                lineColor    : theme.line,
                labels       : { style: { color: theme.muted, fontSize: '11px' } }
            },
            plotOptions: {
                series: { animation: false, borderWidth: 0 }
            }
        };
    }

    function labelStyle(theme) {
        return { color: theme.text, textOutline: 'none', fontWeight: '600', fontSize: '11px' };
    }

    /* Perceived luminance of a #rrggbb fill. A label printed INSIDE a stacked
       segment sits on that segment's colour, not on the card, so the theme
       foreground is the wrong choice: in dark mode the ramp's lightest steps
       are near-white and a white label vanishes on them. */
    function onFill(hex) {
        var m = /^#([0-9a-f]{6})$/i.exec(String(hex || ''));
        if (!m) { return null; }
        var n = parseInt(m[1], 16);
        var lum = (0.2126 * ((n >> 16) & 255) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255;
        return lum > 0.55 ? '#1a202c' : '#ffffff';
    }

    /* labelStyle for a label that sits on top of `fill`. */
    function labelStyleOn(theme, fill) {
        var st = labelStyle(theme);
        var c = onFill(fill);
        if (c) { st.color = c; }
        return st;
    }

    /* ---------------------------------------------------------
       Chart specs, one per question type (spec §7 table)
       --------------------------------------------------------- */

    function specChoice(q, theme) {
        var counts = (q.agg && q.agg.counts) || [];
        var cfg = baseCfg(theme, 'bar');
        cfg.xAxis.categories = counts.map(function (c) { return c.label; });
        cfg.yAxis.allowDecimals = false;
        cfg.yAxis.min = 0;
        cfg.yAxis.title = { text: 'Responses', style: { color: theme.muted, fontSize: '11px' } };
        cfg.plotOptions.bar = {
            borderRadius: 4,
            pointPadding: 0.08,
            groupPadding: 0.12,
            dataLabels  : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () {
                    var p = counts[this.point.index];
                    return this.y + ' (' + (p ? num(p.pct, 1) : '0') + '%)';
                }
            }
        };
        cfg.series = [{
            name       : 'Responses',
            color      : theme.colors[0],
            data       : counts.map(function (c) { return c.count; }),
            /* One series: bar length carries the value, so one hue only. */
            colorByPoint: false
        }];
        return cfg;
    }

    function specRating(q, theme) {
        var dist = (q.agg && q.agg.distribution) || [];
        var cfg = baseCfg(theme, 'column');
        cfg.xAxis.categories = dist.map(function (d) { return String(d.value); });
        cfg.xAxis.title = { text: 'Rating', style: { color: theme.muted, fontSize: '11px' } };
        cfg.yAxis.allowDecimals = false;
        cfg.yAxis.min = 0;
        cfg.plotOptions.column = {
            borderRadius: 4,
            dataLabels  : { enabled: true, style: labelStyle(theme) }
        };
        cfg.series = [{
            name : 'Responses',
            color: theme.colors[0],
            data : dist.map(function (d) { return d.count; })
        }];
        return cfg;
    }

    function specNps(q, theme) {
        var a = q.agg || {};
        var n = a.n || 0;
        var cfg = baseCfg(theme, 'bar');
        cfg.chart.height = 150;
        cfg.xAxis.categories = ['Responses'];
        cfg.xAxis.visible = false;
        cfg.yAxis.min = 0;
        cfg.yAxis.max = n || 1;
        cfg.yAxis.visible = false;
        cfg.legend.enabled = true;
        cfg.legend.reversed = true;
        cfg.plotOptions.series.stacking = 'normal';
        cfg.plotOptions.bar = {
            /* 2px surface gap between stacked segments. */
            borderWidth: 2,
            borderColor: theme.surface,
            dataLabels : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () {
                    if (!this.y) { return null; }
                    return this.y + ' (' + num(this.y / (n || 1) * 100, 0) + '%)';
                }
            }
        };
        cfg.series = [
            { name: 'Detractors (0–6)', color: theme.div.neg, data: [a.detractors || 0],
                dataLabels: { style: labelStyleOn(theme, theme.div.neg) } },
            { name: 'Passives (7–8)', color: theme.div.mid, data: [a.passives || 0],
                dataLabels: { style: labelStyleOn(theme, theme.div.mid) } },
            { name: 'Promoters (9–10)', color: theme.div.pos, data: [a.promoters || 0],
                dataLabels: { style: labelStyleOn(theme, theme.div.pos) } }
        ];
        return cfg;
    }

    function specMatrix(q, theme) {
        var a = q.agg || {};
        var cols = a.columns || [];
        var rows = a.rows || [];
        var colors = rampSteps(theme.ramp, cols.length);

        var cfg = baseCfg(theme, 'bar');
        cfg.xAxis.categories = rows.map(function (r) { return r.label; });
        cfg.yAxis.min = 0;
        cfg.yAxis.max = 100;
        cfg.yAxis.labels.format = '{value}%';
        cfg.legend.enabled = cols.length > 1;
        cfg.plotOptions.series.stacking = 'percent';
        cfg.plotOptions.bar = {
            borderWidth: 2,
            borderColor: theme.surface,
            dataLabels : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () {
                    var p = this.percentage || 0;
                    /* Only label a segment wide enough to hold the number. */
                    return p >= 10 ? Math.round(p) + '%' : null;
                }
            }
        };
        cfg.tooltip.formatter = function () {
            var p = this.percentage || 0;
            return '<b>' + esc(this.x) + '</b><br/>' + esc(this.series.name) + ': <b>' +
                this.y + '</b> (' + num(p, 1) + '%)';
        };
        cfg.series = cols.map(function (c, i) {
            return {
                name      : c.label,
                color     : colors[i],
                dataLabels: { style: labelStyleOn(theme, colors[i]) },
                data : rows.map(function (r) {
                    var cell = 0;
                    (r.counts || []).forEach(function (x) {
                        if (Number(x.option_id) === Number(c.option_id)) { cell = x.count; }
                    });
                    return cell;
                })
            };
        });
        return cfg;
    }

    function specRanking(q, theme) {
        var opts = ((q.agg && q.agg.options) || []).slice();
        /* Lower mean rank is better — sort the best to the top. */
        opts.sort(function (a, b) {
            var av = a.mean_rank === null ? Infinity : a.mean_rank;
            var bv = b.mean_rank === null ? Infinity : b.mean_rank;
            return av - bv;
        });

        var cfg = baseCfg(theme, 'bar');
        cfg.xAxis.categories = opts.map(function (o) { return o.label; });
        cfg.yAxis.min = 0;
        cfg.yAxis.reversed = false;
        cfg.yAxis.title = { text: 'Mean rank (lower is better)', style: { color: theme.muted, fontSize: '11px' } };
        cfg.plotOptions.bar = {
            borderRadius: 4,
            dataLabels  : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () { return num(this.y, 2); }
            }
        };
        cfg.tooltip.formatter = function () {
            var o = opts[this.point.index] || {};
            return '<b>' + esc(o.label) + '</b><br/>Mean rank: <b>' + num(o.mean_rank, 2) + '</b><br/>' +
                'Ranked first: <b>' + (o.first_count || 0) + '</b><br/>Borda score: <b>' + (o.score || 0) + '</b>';
        };
        cfg.series = [{
            name : 'Mean rank',
            color: theme.colors[0],
            data : opts.map(function (o) { return o.mean_rank === null ? 0 : o.mean_rank; })
        }];
        return cfg;
    }

    function specNumber(q, theme) {
        var hist = (q.agg && q.agg.histogram) || [];
        var cfg = baseCfg(theme, 'column');
        cfg.xAxis.categories = hist.map(function (h) { return num(h.from, 2) + '–' + num(h.to, 2); });
        cfg.xAxis.labels.rotation = -35;
        cfg.yAxis.allowDecimals = false;
        cfg.yAxis.min = 0;
        cfg.plotOptions.column = {
            borderRadius: 4,
            pointPadding: 0.02,
            groupPadding: 0.06,
            dataLabels  : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () { return this.y ? this.y : null; }
            }
        };
        cfg.series = [{ name: 'Responses', color: theme.colors[0], data: hist.map(function (h) { return h.count; }) }];
        return cfg;
    }

    function specDate(q, theme) {
        var by = (q.agg && q.agg.by_month) || [];
        var cfg = baseCfg(theme, 'line');
        cfg.xAxis.categories = by.map(function (b) { return monthLabel(b.month); });
        cfg.yAxis.allowDecimals = false;
        cfg.yAxis.min = 0;
        cfg.plotOptions.line = {
            lineWidth: 2,
            marker   : { enabled: true, radius: 4, lineWidth: 2, lineColor: theme.surface },
            dataLabels: { enabled: by.length <= 12, style: labelStyle(theme) }
        };
        cfg.series = [{ name: 'Answers', color: theme.colors[0], data: by.map(function (b) { return b.count; }) }];
        return cfg;
    }

    /* Cross-tab: the same card, split by the cross-tab question's options. */
    function specCrosstab(q, theme) {
        var groups = (q.crosstab && q.crosstab.groups) || [];
        var t = q.type;

        if (t === 'rating' || t === 'nps') {
            /* One comparable figure per group rather than an unreadable pile of
               distributions: mean for rating, NPS score for nps. */
            var cfg = baseCfg(theme, 'bar');
            cfg.xAxis.categories = groups.map(function (g) { return g.label; });
            cfg.yAxis.title = {
                text : t === 'nps' ? 'NPS score' : 'Mean rating',
                style: { color: theme.muted, fontSize: '11px' }
            };
            if (t === 'nps') { cfg.yAxis.min = -100; cfg.yAxis.max = 100; } else { cfg.yAxis.min = 0; }
            cfg.plotOptions.bar = {
                borderRadius: 4,
                dataLabels  : {
                    enabled  : true,
                    style    : labelStyle(theme),
                    formatter: function () { return num(this.y, 2); }
                }
            };
            cfg.tooltip.formatter = function () {
                var g = groups[this.point.index] || {};
                return '<b>' + esc(g.label) + '</b><br/>' +
                    (t === 'nps' ? 'Score' : 'Mean') + ': <b>' + num(this.y, 2) + '</b><br/>n = ' + (g.n || 0);
            };
            cfg.series = [{
                name : t === 'nps' ? 'NPS score' : 'Mean rating',
                color: theme.colors[0],
                data : groups.map(function (g) {
                    var a = g.agg || {};
                    var v = t === 'nps' ? a.score : a.mean;
                    return v === null || v === undefined ? 0 : Number(v);
                })
            }];
            return cfg;
        }

        /* Choice types: stacked counts, one series per cross-tab option. */
        var counts = (q.agg && q.agg.counts) || [];
        var cfg2 = baseCfg(theme, 'bar');
        cfg2.xAxis.categories = counts.map(function (c) { return c.label; });
        cfg2.yAxis.allowDecimals = false;
        cfg2.yAxis.min = 0;
        cfg2.legend.enabled = groups.length > 1;
        cfg2.plotOptions.series.stacking = 'normal';
        cfg2.plotOptions.bar = {
            borderWidth: 2,
            borderColor: theme.surface,
            dataLabels : {
                enabled  : true,
                style    : labelStyle(theme),
                formatter: function () { return this.y ? this.y : null; }
            }
        };
        cfg2.series = groups.map(function (g, i) {
            var byId = {};
            ((g.agg && g.agg.counts) || []).forEach(function (c) { byId[c.option_id] = c.count; });
            return {
                name : g.label,
                /* Fixed slot order, never cycled — past eight groups the ninth
                   would repeat, so cap the split at the palette length. */
                color: theme.colors[i],
                dataLabels: { style: labelStyleOn(theme, theme.colors[i]) },
                data : counts.map(function (c) { return byId[c.option_id] || 0; })
            };
        }).slice(0, theme.colors.length);
        return cfg2;
    }

    function specFor(q, theme) {
        if (q.crosstab && (q.crosstab.groups || []).length) { return specCrosstab(q, theme); }
        switch (q.type) {
            case 'single':
            case 'dropdown':
            case 'yesno':
            case 'multi':   return specChoice(q, theme);
            case 'rating':  return specRating(q, theme);
            case 'nps':     return specNps(q, theme);
            case 'matrix':  return specMatrix(q, theme);
            case 'ranking': return specRanking(q, theme);
            case 'number':  return specNumber(q, theme);
            case 'date':    return specDate(q, theme);
            default:        return null;
        }
    }

    /* ---------------------------------------------------------
       Callout figures under a chart
       --------------------------------------------------------- */

    function calloutsFor(q) {
        var a = q.agg || {};
        var out = [];
        switch (q.type) {
            case 'rating':
                out.push(['Mean', num(a.mean, 2)], ['Median', num(a.median, 2)], ['Scale', num(a.min) + '–' + num(a.max)]);
                break;
            case 'nps':
                out.push(['NPS score', num(a.score, 1), 'svr-nps-tile'],
                    ['Promoters', num(a.promoters)], ['Passives', num(a.passives)], ['Detractors', num(a.detractors)]);
                break;
            case 'number':
                out.push(['Mean', num(a.mean, 2)], ['Median', num(a.median, 2)],
                    ['Min', num(a.min, 2)], ['Max', num(a.max, 2)]);
                break;
            case 'date':
                out.push(['Earliest', a.min || '—'], ['Latest', a.max || '—']);
                break;
            case 'multi':
                out.push(['Mean picked', num(a.mean_selected, 2)]);
                break;
            case 'matrix':
                (a.rows || []).forEach(function (r) {
                    if (r.weighted_mean !== null && r.weighted_mean !== undefined) {
                        out.push([r.label, num(r.weighted_mean, 2)]);
                    }
                });
                break;
            default:
                break;
        }
        if (!out.length) { return ''; }
        var html = '<div class="svr-callouts">';
        out.forEach(function (c) {
            html += '<div class="svr-callout ' + (c[2] || '') + '">' +
                '<div class="svr-callout-value">' + esc(c[1]) + '</div>' +
                '<div class="svr-callout-label">' + esc(c[0]) + '</div></div>';
        });
        return html + '</div>';
    }

    /* ---------------------------------------------------------
       Card rendering
       --------------------------------------------------------- */

    function textListHtml(texts, prefix) {
        var shown = texts.slice(0, TEXT_PREVIEW);
        var html = '<ul class="svr-textlist" id="' + prefix + '-list">';
        shown.forEach(function (t) { html += '<li>' + esc(t) + '</li>'; });
        html += '</ul>';
        if (texts.length > TEXT_PREVIEW) {
            html += '<button type="button" class="sv-btn svr-showmore" data-more="' + prefix + '">' +
                'Show all ' + texts.length + ' responses</button>';
        }
        return html;
    }

    function cardHtml(q) {
        var a   = q.agg || {};
        var n   = Number(q.n || a.n || 0);
        var qid = q.question_id;
        var html = '<section class="rp-chart-card svr-card" data-qid="' + qid + '">' +
            '<div class="svr-card-head">' +
            '<div><h3 class="svr-card-title" id="svr-title-' + qid + '">' +
            esc(q.prompt || ('Question ' + qid)) + '</h3>' +
            '<span class="svr-card-type">' + esc(typeLabel(q.type)) + '</span></div>' +
            '<span class="svr-badge">n = ' + n + '</span>' +
            '</div>';

        if (!n) {
            html += '<div class="svr-empty">Not enough responses yet.</div></section>';
            return html;
        }

        if (TEXT_TYPES[q.type]) {
            html += textListHtml(a.texts || [], 'svr-txt-' + qid);
            html += '</section>';
            return html;
        }

        if (q.crosstab && (q.crosstab.groups || []).length) {
            html += '<p class="svr-field-hint">Split by: <strong>' + esc(q.crosstab.prompt) + '</strong></p>';
        }

        /* aria-labelledby, not aria-label: the Highcharts accessibility module
           writes its own aria-label onto this container, and labelledby wins
           the accessible-name computation, so every chart region is announced
           with the question it belongs to instead of a generic label. */
        html += '<div class="svr-chart' + (q.type === 'matrix' || q.type === 'ranking' ? ' svr-chart-tall' : '') +
            '" id="svr-chart-' + qid + '" aria-labelledby="svr-title-' + qid + '"></div>';
        html += calloutsFor(q);

        var others = a.other_texts || [];
        if (others.length) {
            html += '<details class="svr-other"><summary><i class="fas fa-comment-dots"></i> ' +
                '&ldquo;Other&rdquo; answers (' + others.length + ')</summary>' +
                textListHtml(others, 'svr-oth-' + qid) + '</details>';
        }

        html += '</section>';
        return html;
    }

    /* ---------------------------------------------------------
       State
       --------------------------------------------------------- */

    var state = {
        payload: null,
        charts : [],
        table  : null,
        loading: false
    };

    function destroyCharts() {
        state.charts.forEach(function (c) { try { c.destroy(); } catch (e) { /* already gone */ } });
        state.charts = [];
    }

    function afterPaint(fn) {
        var done = false;
        var run = function () {
            if (done) { return; }
            done = true;
            fn();
        };
        if (window.requestAnimationFrame) { window.requestAnimationFrame(run); }
        window.setTimeout(run, 250);
    }

    function buildCharts() {
        destroyCharts();
        var HC = window.SvHighcharts;
        if (!state.payload || !HC || !HC.Chart) { return; }
        var theme = svChartTheme();
        state.payload.questions.forEach(function (q) {
            var el = $('svr-chart-' + q.question_id);
            /* Highcharts #13 guard: never render into a missing or collapsed box. */
            if (!el || el.offsetParent === null || el.clientWidth <= 0) { return; }
            var cfg = specFor(q, theme);
            if (!cfg) { return; }
            cfg.chart.renderTo = el;
            cfg.accessibility = { description: q.prompt || ('Question ' + q.question_id) };
            try {
                state.charts.push(new HC.Chart(cfg));
            } catch (e) {
                el.innerHTML = '<div class="svr-empty">This chart could not be drawn.</div>';
            }
        });
    }

    /* ---------------------------------------------------------
       Filters
       --------------------------------------------------------- */

    function readFilters() {
        var kingdoms = [];
        Array.prototype.forEach.call(document.querySelectorAll('.svr-kingdom:checked'), function (cb) {
            var v = parseInt(cb.value, 10);
            if (v > 0) { kingdoms.push(v); }
        });
        var xt = $('svr-crosstab');
        return {
            kingdom_ids         : kingdoms,
            consent             : ($('svr-consent') || {}).value || 'any',
            date_from           : ($('svr-date-from') || {}).value || null,
            date_to             : ($('svr-date-to') || {}).value || null,
            crosstab_question_id: xt && xt.value ? parseInt(xt.value, 10) : null,
            include_test        : !!($('svr-include-test') || {}).checked
        };
    }

    function resetFilters() {
        Array.prototype.forEach.call(document.querySelectorAll('.svr-kingdom'), function (cb) { cb.checked = false; });
        if ($('svr-consent')) { $('svr-consent').value = 'any'; }
        if ($('svr-date-from')) { $('svr-date-from').value = ''; }
        if ($('svr-date-to')) { $('svr-date-to').value = ''; }
        if ($('svr-crosstab')) { $('svr-crosstab').value = ''; }
        if ($('svr-include-test')) { $('svr-include-test').checked = false; }
    }

    function syncExport(filters) {
        var a = $('svr-export');
        if (!a) { return; }
        a.setAttribute('href', UIR + 'Survey/export/' + SURVEY_ID +
            '&filters=' + encodeURIComponent(JSON.stringify(filters)));
    }

    /* ---------------------------------------------------------
       Transport
       --------------------------------------------------------- */

    function post(action, fields) {
        var fd = new FormData();
        Object.keys(fields).forEach(function (k) { fd.append(k, fields[k]); });
        return fetch(UIR + 'SurveyAjax/' + action, {
            method     : 'POST',
            body       : fd,
            credentials: 'same-origin'
        }).then(function (r) { return r.json(); });
    }

    function notice(msg, show) {
        var el = $('svr-notice');
        if (!el) { return; }
        if (!show) { el.hidden = true; el.innerHTML = ''; return; }
        /* Unhide first: a role="status" mutation inside a hidden element is not
           announced. */
        el.hidden = false;
        el.innerHTML = '<i class="fas fa-circle-info"></i><span>' + esc(msg) + '</span>';
    }

    /* Short screen-reader status line. The card grid itself is deliberately not
       a live region — re-rendering it would read every chart card aloud. */
    function announce(msg) {
        var el = $('svr-live');
        if (el) { el.textContent = msg; }
    }

    function statusMessage(r) {
        if (r.status === 5) { return 'Your session expired — log in again to see these results.'; }
        if (r.status === 3) { return 'You do not have permission to view these results.'; }
        return r.error || 'Something went wrong loading the results.';
    }

    /* ---------------------------------------------------------
       Summary + cards
       --------------------------------------------------------- */

    function renderSummary(s, filters) {
        $('svr-stat-responses').textContent = s.responses || 0;
        $('svr-stat-completion').textContent = s.responses ? pct((s.completion || 0) * 100) : '—';
        $('svr-stat-duration').textContent = duration(s.median_duration);
        var c = s.consent_breakdown || {};
        $('svr-stat-consent').innerHTML =
            '<span class="svr-consent-part"><b>' + (c.full || 0) + '</b> full</span>' +
            '<span class="svr-consent-part"><b>' + (c.partial || 0) + '</b> partial</span>' +
            '<span class="svr-consent-part"><b>' + (c.anonymous || 0) + '</b> anon</span>';

        var ex = parseInt(s.excluded_anonymous, 10) || 0;
        if (ex > 0 && filters.kingdom_ids.length) {
            notice(ex + (ex === 1 ? ' anonymous response is' : ' anonymous responses are') +
                ' excluded by the kingdom filter — anonymous responses carry no kingdom.', true);
        } else {
            notice('', false);
        }
    }

    function renderCards(questions) {
        var host = $('svr-cards');
        if (!questions.length) {
            host.innerHTML = '<div class="rp-chart-card svr-card"><div class="svr-empty">' +
                'This survey has no answerable questions yet.</div></div>';
            return;
        }
        host.innerHTML = questions.map(cardHtml).join('');
    }

    function announceCards(payload) {
        var qn = (payload.questions || []).length;
        var rn = parseInt((payload.summary || {}).responses, 10) || 0;
        announce(qn + (qn === 1 ? ' question' : ' questions') + ', ' +
            rn + (rn === 1 ? ' response' : ' responses') + ' shown.');
    }

    /* ---------------------------------------------------------
       Rows table
       --------------------------------------------------------- */

    function personaCell(row) {
        if (row.persona && row.mundane_id) {
            return '<a href="' + esc(UIR + 'Player/profile/' + row.mundane_id) + '">' + esc(row.persona) + '</a>';
        }
        if (row.persona) { return esc(row.persona); }
        return '<span class="svr-cell-anon">—</span>';
    }

    function rowArray(row, qids) {
        var out = [
            String(row.response_id),
            '<span class="svr-tag">' + esc(row.consent) + '</span>' +
                (row.is_test ? ' <span class="svr-tag">test</span>' : ''),
            personaCell(row),
            row.kingdom ? esc(row.kingdom) : '<span class="svr-cell-anon">—</span>',
            (row.tenure_years === null || row.tenure_years === undefined)
                ? '<span class="svr-cell-anon">—</span>'
                : esc(row.tenure_years + (row.tenure_years === 1 ? ' yr' : ' yrs')),
            esc(row.submitted_at || ''),
            duration(row.duration_seconds)
        ];
        qids.forEach(function (qid) {
            var v = (row.answers || {})[qid];
            out.push(v === undefined || v === null || v === '' ? '<span class="svr-cell-anon">—</span>' : esc(v));
        });
        return out;
    }

    function initRows() {
        var table = $('svr-rows');
        if (!table || !window.jQuery || !window.jQuery.fn || !window.jQuery.fn.DataTable) { return; }

        var qids  = QUESTIONS.map(function (q) { return q.question_id; });
        var heads = ['#', 'Consent', 'Persona', 'Kingdom', 'Tenure', 'Submitted', 'Time'].concat(
            QUESTIONS.map(function (q) { return q.prompt || ('Question ' + q.question_id); })
        );

        table.innerHTML = '<thead><tr>' + heads.map(function (h) {
            return '<th>' + esc(h) + '</th>';
        }).join('') + '</tr></thead><tbody></tbody>';

        state.table = window.jQuery(table).DataTable({
            serverSide  : true,
            processing  : true,
            searching   : false,
            ordering    : false,
            lengthChange: false,
            pageLength  : ROWS_PAGE,
            deferRender : true,
            autoWidth   : false,
            language    : {
                emptyTable : 'No responses match these filters.',
                processing : 'Loading…',
                info       : 'Showing _START_ to _END_ of _TOTAL_ responses',
                infoEmpty  : 'No responses',
                zeroRecords: 'No responses match these filters.'
            },
            ajax: function (data, callback) {
                post('rows', {
                    SurveyId: SURVEY_ID,
                    Filters : JSON.stringify(readFilters()),
                    Offset  : data.start,
                    Limit   : data.length
                }).then(function (r) {
                    if (r.status !== 0) {
                        notice(statusMessage(r), true);
                        callback({ draw: data.draw, recordsTotal: 0, recordsFiltered: 0, data: [] });
                        return;
                    }
                    callback({
                        draw           : data.draw,
                        recordsTotal   : r.total,
                        recordsFiltered: r.total,
                        data           : (r.rows || []).map(function (row) { return rowArray(row, qids); })
                    });
                }).catch(function () {
                    callback({ draw: data.draw, recordsTotal: 0, recordsFiltered: 0, data: [] });
                });
            }
        });
    }

    /* ---------------------------------------------------------
       Load
       --------------------------------------------------------- */

    function load() {
        if (state.loading) { return; }
        state.loading = true;
        var filters = readFilters();
        syncExport(filters);

        post('results', { SurveyId: SURVEY_ID, Filters: JSON.stringify(filters) })
            .then(function (r) {
                state.loading = false;
                if (r.status !== 0) {
                    notice(statusMessage(r), true);
                    $('svr-cards').innerHTML = '';
                    return;
                }
                state.payload = { summary: r.summary || {}, questions: r.questions || [] };
                renderSummary(state.payload.summary, filters);
                renderCards(state.payload.questions);
                announceCards(state.payload);
                /* Cards are in the DOM but not yet laid out; wait one frame so
                   every chart container has a real width. A context that is
                   never painted (hidden tab, print/screenshot harness, a
                   background restore) never fires that frame, so a timer backs
                   it up and whichever arrives first wins. */
                afterPaint(buildCharts);
            })
            .catch(function () {
                state.loading = false;
                notice('Could not reach the server. Check your connection and try again.', true);
            });
    }

    /* ---------------------------------------------------------
       Wiring
       --------------------------------------------------------- */

    /* Expands one truncated text list. The button is relabelled in place rather
       than removed: removing the element that currently has focus drops focus
       to <body> and throws a keyboard or screen-reader user back to the top of
       the page. */
    function expandTextList(btn, tell) {
        if (btn.getAttribute('aria-disabled') === 'true') { return; }
        var prefix = btn.getAttribute('data-more');
        var list   = $(prefix + '-list');
        if (!list || !state.payload) { return; }
        var qid = parseInt(prefix.replace(/^svr-(txt|oth)-/, ''), 10);
        var kind = prefix.indexOf('svr-oth-') === 0 ? 'other_texts' : 'texts';
        var q = null;
        state.payload.questions.forEach(function (x) { if (x.question_id === qid) { q = x; } });
        if (!q) { return; }
        var all = (q.agg && q.agg[kind]) || [];
        list.innerHTML = all.map(function (t) { return '<li>' + esc(t) + '</li>'; }).join('');
        btn.setAttribute('aria-disabled', 'true');
        btn.textContent = 'All ' + all.length + ' responses shown';
        if (tell) { announce('All ' + all.length + ' responses shown.'); }
    }

    /* Everything must be on the paper: expand every truncated list and open
       every collapsed "Other" block, and redraw the charts in the light theme
       because the browser drops the dark background. */
    function expandForPrint() {
        Array.prototype.forEach.call(document.querySelectorAll('.svr-showmore'), function (b) {
            expandTextList(b, false);
        });
        Array.prototype.forEach.call(document.querySelectorAll('details.svr-other'), function (d) {
            if (!d.open) { d.open = true; d.setAttribute('data-svr-print-open', '1'); }
        });
    }

    function restoreAfterPrint() {
        Array.prototype.forEach.call(document.querySelectorAll('details.svr-other[data-svr-print-open]'), function (d) {
            d.open = false;
            d.removeAttribute('data-svr-print-open');
        });
    }

    function onApply() {
        load();
        if (state.table) { state.table.ajax.reload(null, true); }
    }

    function boot() {
        if ($('svr-apply')) { $('svr-apply').addEventListener('click', onApply); }
        if ($('svr-reset')) {
            $('svr-reset').addEventListener('click', function () { resetFilters(); onApply(); });
        }

        /* "Show all" on a truncated text list. */
        document.addEventListener('click', function (e) {
            var btn = e.target.closest ? e.target.closest('.svr-showmore') : null;
            if (!btn) { return; }
            expandTextList(btn, true);
        });

        /* Redraw on a theme change — the toggle stamps html[data-theme], and the
           system setting moves without touching the attribute. */
        var observer = new MutationObserver(function () { buildCharts(); });
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
        if (window.matchMedia) {
            var mq = window.matchMedia('(prefers-color-scheme: dark)');
            if (mq.addEventListener) {
                mq.addEventListener('change', function () { buildCharts(); });
            } else if (mq.addListener) {
                mq.addListener(function () { buildCharts(); });
            }
        }

        window.addEventListener('beforeprint', function () {
            expandForPrint();
            if (svIsDark()) { printingLight = true; buildCharts(); }
        });

        window.addEventListener('afterprint', function () {
            restoreAfterPrint();
            if (printingLight) { printingLight = false; buildCharts(); }
        });

        /* Charts do not reflow on their own when the grid changes track count. */
        var rt = null;
        window.addEventListener('resize', function () {
            clearTimeout(rt);
            rt = setTimeout(buildCharts, 250);
        });

        load();
        initRows();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
