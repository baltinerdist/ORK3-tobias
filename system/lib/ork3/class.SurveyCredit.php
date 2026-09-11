<?php

/**
 * SurveyCredit — attendance credits for completing a survey
 * (docs/superpowers/specs/2026-09-10-survey-sharing-and-credits-design.md §3).
 *
 * A config (ork_survey_credit) is one org's PERMANENT promise to credit the
 * players it covers; the ledger (ork_survey_credit_grant) holds at most one
 * credit per player per survey. Only non-test `full` responses are ever
 * credited (D1): a dated public credit beside a day-stamped partial or
 * anonymous response would re-identify it.
 *
 * All credit SQL lives here. Attendance and event rows are written by
 * Attendance::AddSystemCredit() and EventPlanning::CreateSystemEvent(), which
 * trust this class to have authorized the write.
 */
class SurveyCredit
{
    public const MODES = ['home_park', 'event'];

    /** ork_class row for Color: the credit class for a player with no attendance yet. */
    public const COLOR_CLASS_ID = 6;

    public const EVENT_PREFIX = 'Survey Credit - ';

    /** ork_event.name is varchar(100). */
    public const EVENT_NAME_MAX = 100;

    private $db;

    /** @var array<int,int>|null kingdom_id => parent_kingdom_id, non-zero parents only */
    private ?array $parentMemo = null;

    /** @var array<string,array{0:int,1:int}> "type:id" => [kingdom_id, parent_kingdom_id] */
    private array $orgMemo = [];

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
    }

    // -----------------------------------------------------------------------
    // Pure
    // -----------------------------------------------------------------------

    /** ork_attendance.note for a survey credit; <= 20 chars for any 10-digit id. */
    public static function noteFor(int $surveyId): string
    {
        return 'Survey #' . $surveyId;
    }

    /** "Survey Credit - {title}", cut to ork_event.name's 100 characters. */
    public static function eventName(string $title): string
    {
        $name = self::EVENT_PREFIX . trim($title);
        if (mb_strlen($name) <= self::EVENT_NAME_MAX) {
            return $name;
        }
        return rtrim(mb_substr($name, 0, self::EVENT_NAME_MAX - 1)) . '…';
    }

    /**
     * 'Y-m-d' the survey started: DATE(opened_at), or DATE(open_at) when later;
     * null if never opened. A zero date ('0000-00-00 …', which sql_mode='' can
     * write for '') parses to a negative timestamp and counts as unset.
     */
    public static function startDate(array $surveyRow): ?string
    {
        $opened = strtotime((string) ($surveyRow['opened_at'] ?? ''));
        if (!$opened || $opened <= 0) {
            return null;
        }
        $scheduled = strtotime((string) ($surveyRow['open_at'] ?? ''));
        return date('Y-m-d', ($scheduled && $scheduled > $opened) ? $scheduled : $opened);
    }

    /** The player's last class, or Color when they have no attendance. */
    public static function classFor(int $lastClassId): int
    {
        return $lastClassId > 0 ? $lastClassId : self::COLOR_CLASS_ID;
    }

    /**
     * Does the survey reach this org? The same answer decides who may grant
     * credits (§3.2) and, one level down, who may see shared results (§2).
     * $grantorKingdom is the org's kingdom (a park's own kingdom); $grantorParent
     * is that kingdom's parent, 0 for none.
     */
    public static function grantorReaches(array $surveyRow, string $type, int $id, int $grantorKingdom, int $grantorParent): bool
    {
        if ($id <= 0 || $grantorKingdom <= 0 || !in_array($type, ['kingdom', 'park'], true)) {
            return false;
        }
        $scopeId = (int) ($surveyRow['scope_id'] ?? 0);
        switch ((string) ($surveyRow['scope_type'] ?? '')) {
            case 'park':
                return $type === 'park' && $id === $scopeId;
            case 'kingdom':
                return $grantorKingdom === $scopeId || ($grantorParent > 0 && $grantorParent === $scopeId);
            case 'ork':
                $list = SurveyResponse::kingdomIdList($surveyRow['audience_kingdom_ids'] ?? null);
                return $list === null
                    || in_array($grantorKingdom, $list, true)
                    || ($grantorParent > 0 && in_array($grantorParent, $list, true));
        }
        return false;
    }

    /**
     * Which config credits this respondent (§3.2)? The earliest enabled_at wins,
     * ties to the lower credit_id. A park config covers its snapshotted park; a
     * kingdom config covers its kingdom and that kingdom's principalities; the
     * OWNER's event config covers everyone (event audiences bring visitors). A
     * home_park config cannot place a respondent with no park: it is skipped
     * (a later config may still cover them) and no_home_park reports why.
     *
     * @param list<array<string,mixed>> $configs    ork_survey_credit rows
     * @param array<string,mixed>       $respondent ['park_id'=>?int, 'kingdom_id'=>?int] from the response
     * @param array<int,int>            $parentOf   kingdom_id => parent_kingdom_id
     * @return array{credit_id:?int, no_home_park:bool}
     */
    public static function coverage(array $configs, array $respondent, array $surveyRow, array $parentOf): array
    {
        usort($configs, static function (array $a, array $b): int {
            return [(string) $a['enabled_at'], (int) $a['credit_id']] <=> [(string) $b['enabled_at'], (int) $b['credit_id']];
        });

        $park      = (int) ($respondent['park_id'] ?? 0);
        $kingdom   = (int) ($respondent['kingdom_id'] ?? 0);
        $parent    = $kingdom > 0 ? (int) ($parentOf[$kingdom] ?? 0) : 0;
        $ownerType = (string) ($surveyRow['scope_type'] ?? '');
        $ownerId   = (int) ($surveyRow['scope_id'] ?? 0);
        $noPark    = false;

        foreach ($configs as $c) {
            $type = (string) $c['grantor_type'];
            $gid  = (int) $c['grantor_id'];
            $mode = (string) $c['mode'];

            if ($mode === 'event' && $type === $ownerType && $gid === $ownerId) {
                return ['credit_id' => (int) $c['credit_id'], 'no_home_park' => false];
            }
            $mine = ($type === 'park' && $park > 0 && $park === $gid)
                || ($type === 'kingdom' && $kingdom > 0 && ($kingdom === $gid || ($parent > 0 && $parent === $gid)));
            if (!$mine) {
                continue;
            }
            if ($mode === 'home_park' && $park <= 0) {
                $noPark = true;
                continue;
            }
            return ['credit_id' => (int) $c['credit_id'], 'no_home_park' => false];
        }
        return ['credit_id' => null, 'no_home_park' => $noPark];
    }

    // -----------------------------------------------------------------------
    // Org lookups
    // -----------------------------------------------------------------------

    /** @return array<int,int> kingdom_id => parent_kingdom_id for every kingdom with a parent */
    public function parentMap(): array
    {
        if ($this->parentMemo === null) {
            $this->parentMemo = [];
            foreach ($this->fetchAll('SELECT kingdom_id, parent_kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                      WHERE parent_kingdom_id > 0') as $r) {
                $this->parentMemo[(int) $r['kingdom_id']] = (int) $r['parent_kingdom_id'];
            }
        }
        return $this->parentMemo;
    }

    /** [kingdom_id, parent_kingdom_id] of an ACTIVE park or kingdom, or [0, 0]. */
    public function orgKingdom(string $type, int $id): array
    {
        $key = $type . ':' . $id;
        if (isset($this->orgMemo[$key])) {
            return $this->orgMemo[$key];
        }
        $row = null;
        if ($type === 'park' && $id > 0) {
            $row = $this->fetchRow('SELECT p.kingdom_id, COALESCE(k.parent_kingdom_id, 0) AS parent_kingdom_id
                                      FROM ' . DB_PREFIX . 'park p
                                      JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = p.kingdom_id
                                     WHERE p.park_id = ' . $id . ' AND p.active = \'Active\'');
        } elseif ($type === 'kingdom' && $id > 0) {
            $row = $this->fetchRow('SELECT kingdom_id, parent_kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                     WHERE kingdom_id = ' . $id . ' AND active = \'Active\'');
        }
        return $this->orgMemo[$key] = $row ? [(int) $row['kingdom_id'], (int) $row['parent_kingdom_id']] : [0, 0];
    }

    /** May this org grant credits on (and, one level down, receive shared results of) this survey? */
    public function validGrantor(array $surveyRow, string $type, int $id): bool
    {
        [$kingdom, $parent] = $this->orgKingdom($type, $id);
        return self::grantorReaches($surveyRow, $type, $id, $kingdom, $parent);
    }

    /** @return array<string,true> "<survey_id>:<grantor_type>:<grantor_id>" for every config of these surveys */
    public function configKeys(array $surveyIds): array
    {
        $ids = array_values(array_filter(array_map('intval', $surveyIds)));
        if (!$ids) {
            return [];
        }
        $out = [];
        foreach ($this->fetchAll('SELECT survey_id, grantor_type, grantor_id FROM ' . DB_PREFIX . 'survey_credit
                                  WHERE survey_id IN (' . implode(',', $ids) . ')') as $r) {
            $out[(int) $r['survey_id'] . ':' . $r['grantor_type'] . ':' . (int) $r['grantor_id']] = true;
        }
        return $out;
    }

    // -----------------------------------------------------------------------
    // SQL helpers (same contract as class.Survey.php)
    // -----------------------------------------------------------------------

    /** @return list<array<string, mixed>> */
    private function fetchAll(string $sql): array
    {
        $this->db->Clear();
        $rs  = $this->db->DataSet($sql);
        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $out[] = $rs->CurrentFieldSet();
            }
        }
        return $out;
    }

    /** @return array<string, mixed>|null */
    private function fetchRow(string $sql): ?array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet($sql);
        if ($rs && $rs->Next()) {
            return $rs->CurrentFieldSet();
        }
        return null;
    }

    /**
     * Run one write. Returns false when the statement really failed, so a
     * transactional block can ROLLBACK instead of committing a half-mutation
     * (Execute() alone reports nothing — PDO runs in ERRMODE_WARNING).
     */
    private function exec(string $sql): bool
    {
        $this->db->Clear();
        if (method_exists($this->db, 'ExecuteChecked')) {
            return (bool) $this->db->ExecuteChecked($sql);
        }
        $this->db->Execute($sql);
        return true;
    }

    /** @param array<string, mixed> $payload */
    private function ok(array $payload = []): array
    {
        return ['Status' => 0, 'Error' => ''] + $payload;
    }

    private function fail(string $error): array
    {
        return ['Status' => 1, 'Error' => $error];
    }

    private function denied(string $error): array
    {
        return ['Status' => 3, 'Error' => $error];
    }

    private function esc($v)
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], (string) $v);
    }
}
