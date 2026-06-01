<?php
/**
 * class.TournamentExport.php
 *
 * Read-only builder that composes a multi-tab .xlsx workbook for a single
 * tournament: a "Summary & Standings" tab followed by one tab per bracket,
 * formatted by the bracket's method.
 *
 * Reuses existing library methods (no new SQL):
 *   Ork3::$Lib->report->TournamentReport(['TournamentId'=>..])      -> tournament header
 *   Ork3::$Lib->tournament->GetBrackets(['TournamentId'=>..])       -> brackets
 *   Ork3::$Lib->tournament->GetStandings(['BracketId'=>..])         -> ranked standings (routes to points/ironman)
 *   Ork3::$Lib->tournament->GetMatches(['BracketId'=>..])           -> match records
 *   Ork3::$Lib->tournamentreport->GetBracketPlacements(['BracketId'=>..]) -> podium 1/2/3
 *
 * Quick CLI check (from anywhere):
 *   docker exec -i ork3-php8-app php -r 'chdir("/var/www/ork.amtgard.com"); require "/var/www/ork.amtgard.com/startup.php";
 *     $r=(new TournamentExport())->BuildWorkbook(["TournamentId"=>14]);
 *     echo $r["Path"]."\n".$r["Filename"]."\n";'
 */
require_once(__DIR__ . '/../vendor/SimpleXlsx.php');

class TournamentExport {

    /** Friendly labels for bracket methods. */
    private static $METHOD_LABELS = [
        'single'      => 'Single Elimination',
        'double'      => 'Double Elimination',
        'swiss'       => 'Swiss',
        'round-robin' => 'Round Robin',
        'ironman'     => 'Ironman',
        'points'      => "Judge's Score",
    ];

    /** Generic column widths used by every bracket sheet (extra entries are ignored). */
    private static $WIDTHS = [8, 26, 18, 30, 9, 9, 9, 9, 12, 12, 12, 12, 12, 12];

    /**
     * Build the workbook for a tournament.
     * @return array ['Status'=>..., 'Path'=>tmpfile|null, 'Filename'=>name|null]
     */
    public function BuildWorkbook($request) {
        $tid = (int)($request['TournamentId'] ?? 0);
        if (!valid_id($tid)) {
            return ['Status' => InvalidParameter('TournamentId required'), 'Path' => null, 'Filename' => null];
        }

        $tr = Ork3::$Lib->report->TournamentReport(['TournamentId' => $tid]);
        $t  = $tr['Tournaments'][0] ?? null;
        if (!$t) {
            return ['Status' => InvalidParameter('Tournament not found'), 'Path' => null, 'Filename' => null];
        }

        $br       = Ork3::$Lib->tournament->GetBrackets(['TournamentId' => $tid]);
        $brackets = $br['Detail'] ?? [];

        $bundles = [];
        foreach ($brackets as $b) {
            $bid    = (int)$b['BracketId'];
            $method = (string)($b['Method'] ?? '');
            $st     = Ork3::$Lib->tournament->GetStandings(['BracketId' => $bid]);
            $pl     = Ork3::$Lib->tournamentreport->GetBracketPlacements(['BracketId' => $bid]);
            $mt     = Ork3::$Lib->tournament->GetMatches(['BracketId' => $bid]);
            $bundles[] = [
                'Bracket'    => $b,
                'Method'     => $method,
                'IsTeam'     => (($b['Participants'] ?? 'individual') === 'team'),
                'Standings'  => $st['Detail'] ?? [],
                'Placements' => $pl['Placements'] ?? [],
                'Matches'    => $mt['Detail'] ?? [],
            ];
        }

        $xlsx = new SimpleXlsx();
        $this->addSummarySheet($xlsx, $t, $bundles);
        foreach ($bundles as $bundle) {
            $this->addBracketSheet($xlsx, $bundle);
        }

        $tmp = tempnam(sys_get_temp_dir(), 'tnxlsx');
        $xlsx->writeToFile($tmp);

        return ['Status' => Success(), 'Path' => $tmp, 'Filename' => $this->fileName($t)];
    }

    // ---- Summary sheet ---------------------------------------------------

    private function addSummarySheet($xlsx, $t, $bundles) {
        $rows = [];
        $rows[] = [['v' => (string)($t['Name'] ?? 'Tournament'), 's' => SimpleXlsx::S_TITLE]];

        $date = $this->fmtDate($t['DateTime'] ?? ($t['Date'] ?? ''));
        if ($date !== '') $rows[] = [['v' => 'Date', 's' => SimpleXlsx::S_LABEL], $date];

        $loc = (string)($t['KingdomName'] ?? '');
        if (!empty($t['ParkName'])) $loc = trim($loc . ' / ' . $t['ParkName']);
        if ($loc !== '') $rows[] = [['v' => 'Location', 's' => SimpleXlsx::S_LABEL], $loc];

        if (!empty($t['EventName'])) $rows[] = [['v' => 'Event', 's' => SimpleXlsx::S_LABEL], (string)$t['EventName']];

        $totParts = 0; $totMatches = 0;
        foreach ($bundles as $b) { $totParts += count($b['Standings']); $totMatches += count($b['Matches']); }
        $rows[] = [['v' => 'Brackets', 's' => SimpleXlsx::S_LABEL], (int)count($bundles)];
        $rows[] = [['v' => 'Participants', 's' => SimpleXlsx::S_LABEL], (int)$totParts];
        $rows[] = [['v' => 'Matches', 's' => SimpleXlsx::S_LABEL], (int)$totMatches];
        $rows[] = [];

        $rows[] = $this->styleHeader(['Bracket', 'Format', 'Type', 'Participants', 'Matches', 'Status', 'Champion', '2nd', '3rd']);
        foreach ($bundles as $b) {
            $bk   = $b['Bracket'];
            $pods = $this->podium($b['Placements']);
            $rows[] = [
                (string)$this->bracketLabel($bk),
                (string)$this->methodLabel($b['Method']),
                $b['IsTeam'] ? 'Team' : 'Individual',
                (int)count($b['Standings']),
                (int)count($b['Matches']),
                ucfirst((string)($bk['Status'] ?? '')),
                ['v' => $pods[1] ?? '', 's' => SimpleXlsx::S_GOLD],
                ['v' => $pods[2] ?? '', 's' => SimpleXlsx::S_SILVER],
                ['v' => $pods[3] ?? '', 's' => SimpleXlsx::S_BRONZE],
            ];
        }

        $xlsx->addSheet('Summary & Standings', $rows, [
            'colWidths' => [26, 18, 12, 13, 9, 12, 22, 22, 22],
        ]);
    }

    // ---- Per-bracket dispatch (by method) --------------------------------

    private function addBracketSheet($xlsx, $bundle) {
        $bk     = $bundle['Bracket'];
        $method = $bundle['Method'];
        $isTeam = $bundle['IsTeam'];

        $rows = [];
        $rows[] = [['v' => $this->bracketLabel($bk), 's' => SimpleXlsx::S_TITLE]];
        $meta   = $this->methodLabel($method) . ' · ' . ($isTeam ? 'Team' : 'Individual');
        if (!empty($bk['Style'])) $meta .= ' · ' . $bk['Style'];
        $rows[] = [['v' => $meta, 's' => SimpleXlsx::S_LABEL]];
        $rows[] = [];

        if (empty($bundle['Standings']) && empty($bundle['Matches'])) {
            $rows[] = [['v' => 'No matches recorded yet.', 's' => SimpleXlsx::S_DEFAULT]];
            $xlsx->addSheet($this->bracketLabel($bk), $rows, ['colWidths' => self::$WIDTHS]);
            return;
        }

        if ($method === 'points') {
            $info = $this->buildPointsRows($rows, $bundle, $isTeam);
        } elseif ($method === 'ironman') {
            $info = $this->buildIronmanRows($rows, $bundle, $isTeam);
        } elseif ($method === 'single' || $method === 'double') {
            $info = $this->buildEliminationRows($rows, $bundle, $isTeam);
        } else { // round-robin, swiss, and any unknown method
            $info = $this->buildStandingsRows($rows, $bundle, $isTeam, $method);
            if ($method === 'round-robin') {
                $rows[] = [];
                $this->buildRoundRobinGrid($rows, $bundle);
            }
        }

        $opts = ['colWidths' => self::$WIDTHS];
        if ($info && !empty($info['headerRow'])) {
            $opts['freezeRow'] = $info['headerRow'];
            if (!empty($info['autoFilter'])) {
                $opts['autoFilterRef'] = 'A' . $info['headerRow'] . ':'
                    . SimpleXlsx::colName($info['cols']) . $info['lastRow'];
            }
        }
        $xlsx->addSheet($this->bracketLabel($bk), $rows, $opts);
    }

    /**
     * Generic ranked standings table. Appends to $rows by reference.
     * @return array ['headerRow'=>int, 'lastRow'=>int, 'cols'=>int, 'autoFilter'=>bool]
     */
    private function buildStandingsRows(&$rows, $bundle, $isTeam, $method) {
        $includeByes = ($method === 'round-robin' || $method === 'ironman' || $method === '');
        $header = ['Rank', 'Competitor', 'Park'];
        if ($isTeam) $header[] = 'Members';
        $header = array_merge($header, ['W', 'L', 'T']);
        if ($includeByes) $header[] = 'Byes';
        $header[] = 'Points';

        $headerRow = count($rows) + 1;
        $rows[] = $this->styleHeader($header);
        foreach ($bundle['Standings'] as $s) {
            $rank = (int)($s['Rank'] ?? 0);
            $row = [$rank, (string)($s['Alias'] ?? ''), (string)($s['ParkName'] ?? '')];
            if ($isTeam) $row[] = $this->teamMembers($s);
            $row[] = (int)($s['Wins'] ?? 0);
            $row[] = (int)($s['Losses'] ?? 0);
            $row[] = (int)($s['Ties'] ?? 0);
            if ($includeByes) $row[] = (int)($s['Byes'] ?? 0);
            $row[] = (int)($s['Points'] ?? 0);
            $rows[] = $this->tintRow($row, $rank);
        }
        return ['headerRow' => $headerRow, 'lastRow' => count($rows), 'cols' => count($header), 'autoFilter' => true];
    }

    /** Points / Judge's Score: Place, Competitor, [Members], R1..Rn, Total. */
    private function buildPointsRows(&$rows, $bundle, $isTeam) {
        $st = $bundle['Standings'];
        $nr = 0;
        foreach ($st as $s) { $nr = max($nr, count($s['RoundScores'] ?? [])); }

        $header = ['Place', 'Competitor'];
        if ($isTeam) $header[] = 'Members';
        for ($i = 1; $i <= $nr; $i++) $header[] = 'R' . $i;
        $header[] = 'Total';

        $headerRow = count($rows) + 1;
        $rows[] = $this->styleHeader($header);
        foreach ($st as $s) {
            $place = $s['Place'] ?? null;
            $row = [($place === null) ? '' : (int)$place, (string)($s['Alias'] ?? '')];
            if ($isTeam) $row[] = $this->teamMembers($s);
            $scores = $s['RoundScores'] ?? [];
            for ($i = 0; $i < $nr; $i++) {
                $v = $scores[$i] ?? null;
                $row[] = ($v === null || $v === '') ? '' : ['v' => (float)$v, 's' => SimpleXlsx::S_NUM2, 't' => 'n'];
            }
            $row[] = ['v' => (float)($s['Total'] ?? 0), 's' => SimpleXlsx::S_NUM2, 't' => 'n'];
            $rows[] = $this->tintRow($row, is_int($place) ? $place : 0);
        }
        return ['headerRow' => $headerRow, 'lastRow' => count($rows), 'cols' => count($header), 'autoFilter' => true];
    }

    /** Ironman: Rank, Competitor, Park, [Members], Wins, Max Streak, Current Streak, Points. */
    private function buildIronmanRows(&$rows, $bundle, $isTeam) {
        $header = ['Rank', 'Competitor', 'Park'];
        if ($isTeam) $header[] = 'Members';
        $header = array_merge($header, ['Wins', 'Max Streak', 'Current Streak', 'Points']);

        $headerRow = count($rows) + 1;
        $rows[] = $this->styleHeader($header);
        foreach ($bundle['Standings'] as $s) {
            $rank = (int)($s['Rank'] ?? 0);
            $row = [$rank, (string)($s['Alias'] ?? ''), (string)($s['ParkName'] ?? '')];
            if ($isTeam) $row[] = $this->teamMembers($s);
            $row[] = (int)($s['Wins'] ?? 0);
            $row[] = (int)($s['MaxStreak'] ?? ($s['ImMaxStreak'] ?? 0));
            $row[] = (int)($s['CurrentStreak'] ?? ($s['ImCurStreak'] ?? 0));
            $row[] = (int)($s['Points'] ?? 0);
            $rows[] = $this->tintRow($row, $rank);
        }
        return ['headerRow' => $headerRow, 'lastRow' => count($rows), 'cols' => count($header), 'autoFilter' => true];
    }

    /** Single/Double elimination: podium block, final standings, then bracket results. */
    private function buildEliminationRows(&$rows, $bundle, $isTeam) {
        $pods = $this->podium($bundle['Placements']);
        if ($pods) {
            $rows[] = [['v' => 'Podium', 's' => SimpleXlsx::S_LABEL]];
            $labels = [1 => '1st', 2 => '2nd', 3 => '3rd'];
            $fills  = [1 => SimpleXlsx::S_GOLD, 2 => SimpleXlsx::S_SILVER, 3 => SimpleXlsx::S_BRONZE];
            foreach ([1, 2, 3] as $p) {
                if (isset($pods[$p])) {
                    $rows[] = [['v' => $labels[$p], 's' => $fills[$p]], ['v' => $pods[$p], 's' => $fills[$p]]];
                }
            }
            $rows[] = [];
        }

        $rows[] = [['v' => 'Final Standings', 's' => SimpleXlsx::S_LABEL]];
        $header = ['Rank', 'Competitor', 'Park'];
        if ($isTeam) $header[] = 'Members';
        $header = array_merge($header, ['W', 'L', 'Byes', 'Points']);
        $headerRow = count($rows) + 1;
        $rows[] = $this->styleHeader($header);
        foreach ($bundle['Standings'] as $s) {
            $rank = (int)($s['Rank'] ?? 0);
            $row = [$rank, (string)($s['Alias'] ?? ''), (string)($s['ParkName'] ?? '')];
            if ($isTeam) $row[] = $this->teamMembers($s);
            $row[] = (int)($s['Wins'] ?? 0);
            $row[] = (int)($s['Losses'] ?? 0);
            $row[] = (int)($s['Byes'] ?? 0);
            $row[] = (int)($s['Points'] ?? 0);
            $rows[] = $this->tintRow($row, $rank);
        }

        $rows[] = [];
        $rows[] = [['v' => 'Bracket Results', 's' => SimpleXlsx::S_LABEL]];
        $rows[] = $this->styleHeader(['Round', 'Side', 'Competitor 1', 'Competitor 2', 'Winner']);
        foreach ($bundle['Matches'] as $m) {
            $p1 = (string)($m['Participant1Alias'] ?? '');
            $p2 = (string)($m['Participant2Alias'] ?? '');
            if ($p1 === '') $p1 = ((int)($m['Participant1Id'] ?? 0) > 0) ? ('#' . (int)$m['Participant1Id']) : 'BYE';
            if ($p2 === '') $p2 = ((int)($m['Participant2Id'] ?? 0) > 0) ? ('#' . (int)$m['Participant2Id']) : 'BYE';
            $rows[] = [
                (string)($m['Round'] ?? ''),
                $this->sideLabel((string)($m['BracketSide'] ?? '')),
                $p1,
                $p2,
                $this->winnerLabel($m),
            ];
        }
        // autoFilter is omitted: this sheet has multiple tables (standings + results)
        // so a single filter range would wrongly span both. Freeze the standings header only.
        return ['headerRow' => $headerRow, 'lastRow' => count($rows), 'cols' => count($header), 'autoFilter' => false];
    }

    /** Round-robin results cross-table: competitors on both axes, cell = W/L/T. */
    private function buildRoundRobinGrid(&$rows, $bundle) {
        $st = $bundle['Standings'];
        if (count($st) < 2) return;

        $ids = [];
        $labels = [];
        foreach ($st as $s) {
            $pid = (int)($s['ParticipantId'] ?? 0);
            if ($pid <= 0) continue;
            $ids[] = $pid;
            $labels[$pid] = (string)($s['Alias'] ?? '');
        }

        $cell = [];
        foreach ($bundle['Matches'] as $m) {
            $p1 = (int)($m['Participant1Id'] ?? 0);
            $p2 = (int)($m['Participant2Id'] ?? 0);
            $res = (string)($m['Result'] ?? '');
            if (!$p1 || !$p2) continue;
            if ($res === '1-wins') { $cell["$p1:$p2"] = 'W'; $cell["$p2:$p1"] = 'L'; }
            elseif (in_array($res, ['2-wins', 'forfeit', 'disqualified'], true)) { $cell["$p1:$p2"] = 'L'; $cell["$p2:$p1"] = 'W'; }
            elseif ($res === 'tie') { $cell["$p1:$p2"] = 'T'; $cell["$p2:$p1"] = 'T'; }
        }

        $rows[] = [['v' => 'Results Grid', 's' => SimpleXlsx::S_LABEL]];
        $head = [['v' => '', 's' => SimpleXlsx::S_HEADER]];
        foreach ($ids as $pid) $head[] = ['v' => $labels[$pid], 's' => SimpleXlsx::S_HEADER];
        $rows[] = $head;
        foreach ($ids as $r) {
            $row = [['v' => $labels[$r], 's' => SimpleXlsx::S_HEADER]];
            foreach ($ids as $c) {
                $row[] = ($r === $c) ? ['v' => '—', 's' => SimpleXlsx::S_DEFAULT] : ($cell["$r:$c"] ?? '');
            }
            $rows[] = $row;
        }
    }

    private function sideLabel($side) {
        switch ($side) {
            case 'winners':        return 'Winners';
            case 'losers':         return 'Losers';
            case 'grand-final':    return 'Grand Final';
            case 'tiebreaker-3rd': return '3rd Place';
            default:               return $side !== '' ? ucfirst($side) : '';
        }
    }

    private function winnerLabel($m) {
        $res = (string)($m['Result'] ?? '');
        $a1 = (string)($m['Participant1Alias'] ?? '');
        $a2 = (string)($m['Participant2Alias'] ?? '');
        if ($res === '1-wins') return $a1;
        if (in_array($res, ['2-wins', 'forfeit', 'disqualified'], true)) return $a2;
        if ($res === 'tie') return 'Tie';
        return '';
    }

    // ---- shared helpers --------------------------------------------------

    private function styleHeader(array $labels) {
        $out = [];
        foreach ($labels as $l) $out[] = ['v' => $l, 's' => SimpleXlsx::S_HEADER];
        return $out;
    }

    /** Tint the rank + competitor cells of a row for podium ranks 1-3. */
    private function tintRow(array $row, $rank) {
        $fill = $this->podiumFill($rank);
        if ($fill === null) return $row;
        foreach ([0, 1] as $i) {
            if (!array_key_exists($i, $row)) continue;
            $c = $row[$i];
            if (is_array($c)) { $c['s'] = $fill; }
            else { $c = ['v' => $c, 's' => $fill, 't' => (is_int($c) || is_float($c)) ? 'n' : 's']; }
            $row[$i] = $c;
        }
        return $row;
    }

    private function podiumFill($rank) {
        if ($rank === 1) return SimpleXlsx::S_GOLD;
        if ($rank === 2) return SimpleXlsx::S_SILVER;
        if ($rank === 3) return SimpleXlsx::S_BRONZE;
        return null;
    }

    /** First-occurrence alias for places 1..3. */
    private function podium($placements) {
        $out = [];
        foreach ($placements as $p) {
            $place = (int)($p['Place'] ?? 0);
            if ($place >= 1 && $place <= 3 && !isset($out[$place])) {
                $out[$place] = (string)($p['Alias'] ?? '');
            }
        }
        return $out;
    }

    private function teamMembers($s) {
        $m = $s['Members'] ?? [];
        if (!is_array($m) || !$m) return '';
        $names = [];
        foreach ($m as $mem) {
            if (is_array($mem)) {
                $names[] = (string)($mem['Alias'] ?? $mem['MundaneName'] ?? $mem['Name'] ?? '');
            } else {
                $names[] = (string)$mem;
            }
        }
        return implode(', ', array_filter($names));
    }

    private function bracketLabel($bk) {
        $name = trim((string)($bk['Name'] ?? ''));
        if ($name !== '') return $name;
        $style = trim((string)($bk['Style'] ?? ''));
        return $style !== '' ? $style : ('Bracket ' . (int)($bk['BracketId'] ?? 0));
    }

    private function methodLabel($m) {
        if (isset(self::$METHOD_LABELS[$m])) return self::$METHOD_LABELS[$m];
        return $m !== '' ? ucfirst($m) : '—';
    }

    private function fmtDate($raw) {
        $raw = (string)$raw;
        if ($raw === '' || strpos($raw, '0000-00-00') === 0) return '';
        $ts = strtotime($raw);
        return $ts ? date('F j, Y', $ts) : $raw;
    }

    private function fileName($t) {
        $base = (string)($t['Name'] ?? 'tournament');
        $safe = preg_replace('/[^a-z0-9]/i', '-', $base);
        $safe = trim(preg_replace('/-+/', '-', $safe), '-');
        if ($safe === '') $safe = 'tournament';
        return $safe . '-results.xlsx';
    }
}
