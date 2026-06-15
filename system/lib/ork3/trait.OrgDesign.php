<?php

/**
 * Shared profile-design + milestone engine for org library classes
 * (Kingdom, Park, Unit) and Player. Behavior-identical extraction of the
 * design-row seeding, field validators, custom-milestone CRUD, and
 * derived-milestone orchestration that were previously copy-pasted per org.
 *
 * A consuming class composes this trait with `use OrgDesign;` and implements
 * getDesignConfig(), returning the per-org contract:
 *
 *   [
 *     'design_table'    => 'kingdom_design',     // supplemental 1:1 design table (no DB_PREFIX)
 *     'fk'              => 'kingdom_id',          // FK column on both design + milestone tables
 *     'milestone_table' => 'kingdom_milestones',  // custom-milestone table (no DB_PREFIX)
 *     'auth'            => AUTH_KINGDOM,           // HasAuthority scope for design/milestone writes
 *     'profanity_fields'=> [...],                  // (reference only — validators take pf explicitly)
 *     'char_limits'     => [...],                  // (reference only — limits applied inline below)
 *     'derived'         => callable($id):array,    // returns the derived-milestone rows for this org
 *   ]
 *
 * The trait does NOT change any threshold, query, validation rule, or return
 * shape relative to the original per-org implementations.
 */
trait OrgDesign
{
    /**
     * Per-org design contract. MUST be implemented by the consuming class.
     *
     * @return array
     */
    abstract public function getDesignConfig();

    // ---------------------------------------------------------------------
    // Design-row bootstrap
    // ---------------------------------------------------------------------

    /**
     * Find-or-insert the always-present 1:1 design row for $id, returning the
     * located/created yapo. Mirrors the seeding that was duplicated across the
     * info-read, create, and Set*Design paths.
     *
     * @param int $id
     * @return yapo
     */
    protected function seedDesignRow($id)
    {
        $cfg = $this->getDesignConfig();
        $fk  = $cfg['fk'];
        $this->db->Clear();
        $design = new yapo($this->db, DB_PREFIX . $cfg['design_table']);
        $design->clear();
        $design->$fk = $id;
        if (!$design->find()) {
            $design->clear();
            $design->$fk          = $id;
            $design->hero_overlay = 'med';
            $design->save();
            $design->clear();
            $this->db->Clear();
            $design->$fk = $id;
            $design->find();
        }
        return $design;
    }

    // ---------------------------------------------------------------------
    // Reusable field validators
    //
    // Each returns true on success or an InvalidParameter() response on
    // failure. On success the validated value is written to $design->$col.
    // Callers MUST short-circuit and return the response when one is returned.
    // ---------------------------------------------------------------------

    /**
     * Apply the shared, org-common design fields (about/history markdown, hex
     * colors, hero overlay, font, milestone-config JSON, tagline, social links,
     * announcement + until). Any validation failure returns an InvalidParameter
     * response which the caller MUST return immediately. On success returns null.
     *
     * @param yapo           $design
     * @param array          $request
     * @param ProfanityFilter $pf
     * @return mixed null on success, or an InvalidParameter() response array
     */
    protected function applyCommonDesignFields($design, $request, $pf)
    {
        $ABOUT_LIMIT = 10000;
        foreach (['AboutText' => 'about_text', 'OurHistory' => 'our_history'] as $req => $col) {
            if (isset($request[$req])) {
                $v = (string)$request[$req];
                if (strlen($v) > $ABOUT_LIMIT) {
                    return InvalidParameter($req . ' is limited to ' . number_format($ABOUT_LIMIT) . ' characters.');
                }
                $design->$col = $v;
            }
        }
        $hexCols = ['ColorPrimary' => 'color_primary', 'ColorAccent' => 'color_accent', 'ColorSecondary' => 'color_secondary'];
        foreach ($hexCols as $req => $col) {
            if (!array_key_exists($req, $request)) {
                continue;
            }
            $v = trim((string)$request[$req]);
            if ($v === '') {
                $design->$col = null;
                continue;
            }
            if (!preg_match('/^#[0-9a-fA-F]{6}$/', $v)) {
                return InvalidParameter($req . ' must be a 6-digit hex color (e.g. #2c5282).');
            }
            $design->$col = strtolower($v);
        }
        if (array_key_exists('HeroOverlay', $request)) {
            $ho = strtolower(trim((string)$request['HeroOverlay']));
            if (!in_array($ho, ['low', 'med', 'high', 'vignette'], true)) {
                $ho = 'med';
            }
            $design->hero_overlay = $ho;
        }
        if (array_key_exists('NameFont', $request)) {
            $nf = trim((string)$request['NameFont']);
            if ($nf !== '' && !preg_match('/^[A-Za-z0-9 ]{1,100}$/', $nf)) {
                return InvalidParameter('Font name contains unexpected characters.');
            }
            $design->name_font = $nf === '' ? null : $nf;
        }
        if (array_key_exists('MilestoneConfig', $request)) {
            $mc = (string)$request['MilestoneConfig'];
            if ($mc !== '') {
                $decoded = json_decode($mc, true);
                if (!is_array($decoded)) {
                    return InvalidParameter('Milestone config must be valid JSON.');
                }
            }
            $design->milestone_config = $mc === '' ? null : $mc;
        }

        if (array_key_exists('Tagline', $request)) {
            $tg = trim((string)$request['Tagline']);
            if (strlen($tg) > 160) {
                return InvalidParameter('Tagline is limited to 160 characters.');
            }
            if ($tg !== '' && $pf->containsProfanity($tg)) {
                return InvalidParameter('Tagline', ProfanityFilter::ERROR_MESSAGE);
            }
            $design->tagline = $tg === '' ? null : $tg;
        }

        if (array_key_exists('SocialLinks', $request)) {
            $sl = trim((string)$request['SocialLinks']);
            $cleanLinks = [];
            if ($sl !== '') {
                $decoded = json_decode($sl, true);
                if (!is_array($decoded)) {
                    return InvalidParameter('SocialLinks must be valid JSON.');
                }
                $allowed = ['discord', 'facebook', 'instagram', 'threads', 'bluesky', 'twitter', 'youtube', 'amtwiki'];
                foreach ($decoded as $slug => $url) {
                    if (!in_array($slug, $allowed, true)) {
                        continue;
                    }
                    $url = trim((string)$url);
                    if ($url === '') {
                        continue;
                    }
                    if (preg_match('#^http://#i', $url)) {
                        $url = 'https://' . substr($url, 7);
                    } elseif (!preg_match('#^https://#i', $url)) {
                        $url = 'https://' . ltrim($url, '/');
                    }
                    if (strlen($url) > 500) {
                        return InvalidParameter('SocialLinks.' . $slug . ' URL too long.');
                    }
                    if (!filter_var($url, FILTER_VALIDATE_URL)) {
                        return InvalidParameter('SocialLinks.' . $slug . ' is not a valid URL.');
                    }
                    $cleanLinks[$slug] = $url;
                }
            }
            $design->social_links = empty($cleanLinks) ? null : json_encode($cleanLinks);
        }

        if (array_key_exists('Announcement', $request)) {
            $an = trim((string)$request['Announcement']);
            if (strlen($an) > 280) {
                return InvalidParameter('Announcement is limited to 280 characters.');
            }
            if ($an !== '' && $pf->containsProfanity($an)) {
                return InvalidParameter('Announcement', ProfanityFilter::ERROR_MESSAGE);
            }
            $design->announcement = $an === '' ? null : $an;
        }

        if (array_key_exists('AnnouncementUntil', $request)) {
            $au = trim((string)$request['AnnouncementUntil']);
            if ($au === '') {
                $design->announcement_until = null;
            } else {
                $ts = strtotime($au);
                if ($ts === false) {
                    return InvalidParameter('AnnouncementUntil must be a valid date.');
                }
                $design->announcement_until = date('Y-m-d', $ts);
            }
        }

        return null;
    }

    // ---------------------------------------------------------------------
    // Custom-milestone CRUD (generic)
    // ---------------------------------------------------------------------

    /**
     * Read custom milestones for $id. 100% generic.
     *
     * @param int $id
     * @return array ['Status'=>Success(), 'Milestones'=>[...]]
     */
    protected function GetDesignMilestones($id)
    {
        $cfg = $this->getDesignConfig();
        $fk  = $cfg['fk'];
        $id  = (int)$id;
        if ($id <= 0) {
            return InvalidParameter($this->fkLabel($fk) . ' is required.');
        }
        $this->db->Clear();
        $ms = new yapo($this->db, DB_PREFIX . $cfg['milestone_table']);
        $ms->clear();
        $ms->$fk = $id;
        $rows = [];
        if ($ms->find()) {
            do {
                $rows[] = [
                    'MilestoneId'   => (int)$ms->milestone_id,
                    $this->fkLabel($fk) => (int)$ms->$fk,
                    'Icon'          => $ms->icon,
                    'Description'   => $ms->description,
                    'MilestoneDate' => $ms->milestone_date,
                ];
            } while ($ms->next());
        }
        return ['Status' => Success(), 'Milestones' => $rows];
    }

    /**
     * Create a custom milestone (auth + profanity + date + icon validation).
     *
     * @param int   $id
     * @param array $request
     * @return mixed Success((int)$milestone_id) or an error response
     */
    protected function AddDesignMilestone($id, $request)
    {
        $cfg = $this->getDesignConfig();
        $fk  = $cfg['fk'];
        $id  = (int)$id;
        if ($id <= 0) {
            return InvalidParameter($this->fkLabel($fk) . ' is required.');
        }
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_EDIT)) {
            return NoAuthorization();
        }
        require_once(__DIR__ . '/class.ProfanityFilter.php');
        $pf = new ProfanityFilter();
        $desc = trim((string)($request['Description'] ?? ''));
        if ($desc === '') {
            return InvalidParameter('Description is required.');
        }
        if (strlen($desc) > 500) {
            $desc = substr($desc, 0, 500);
        }
        if ($pf->containsProfanity($desc)) {
            return InvalidParameter('Description', ProfanityFilter::ERROR_MESSAGE);
        }
        $dateRaw = trim((string)($request['MilestoneDate'] ?? ''));
        if ($dateRaw === '') {
            return InvalidParameter('Date is required.');
        }
        $ts = strtotime($dateRaw);
        if ($ts === false) {
            return InvalidParameter('Invalid date.');
        }
        $icon = trim((string)($request['Icon'] ?? 'fa-star'));
        if (!preg_match('/^fa-[a-z0-9-]+$/', $icon)) {
            $icon = 'fa-star';
        }
        $this->db->Clear();
        $ms = new yapo($this->db, DB_PREFIX . $cfg['milestone_table']);
        $ms->clear();
        $ms->$fk            = $id;
        $ms->icon           = $icon;
        $ms->description    = $desc;
        $ms->milestone_date = date('Y-m-d', $ts);
        $ms->save();
        return Success((int)$ms->milestone_id);
    }

    /**
     * Edit an existing custom milestone (auth + profanity + date + icon
     * validation). Provided generically for Player; orgs do not expose it.
     *
     * @param int   $id
     * @param array $request
     * @return mixed Success((int)$milestone_id) or an error response
     */
    protected function UpdateDesignMilestone($id, $request)
    {
        $cfg          = $this->getDesignConfig();
        $fk           = $cfg['fk'];
        $id           = (int)$id;
        $milestone_id = (int)($request['MilestoneId'] ?? 0);
        if ($id <= 0 || $milestone_id <= 0) {
            return InvalidParameter($this->fkLabel($fk) . ' and MilestoneId required.');
        }
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_EDIT)) {
            return NoAuthorization();
        }
        require_once(__DIR__ . '/class.ProfanityFilter.php');
        $pf = new ProfanityFilter();
        $desc = trim((string)($request['Description'] ?? ''));
        if ($desc === '') {
            return InvalidParameter('Description is required.');
        }
        if (strlen($desc) > 500) {
            $desc = substr($desc, 0, 500);
        }
        if ($pf->containsProfanity($desc)) {
            return InvalidParameter('Description', ProfanityFilter::ERROR_MESSAGE);
        }
        $dateRaw = trim((string)($request['MilestoneDate'] ?? ''));
        if ($dateRaw === '') {
            return InvalidParameter('Date is required.');
        }
        $ts = strtotime($dateRaw);
        if ($ts === false) {
            return InvalidParameter('Invalid date.');
        }
        $icon = trim((string)($request['Icon'] ?? 'fa-star'));
        if (!preg_match('/^fa-[a-z0-9-]+$/', $icon)) {
            $icon = 'fa-star';
        }
        $this->db->Clear();
        $ms = new yapo($this->db, DB_PREFIX . $cfg['milestone_table']);
        $ms->clear();
        $ms->milestone_id = $milestone_id;
        $ms->$fk          = $id;
        if (!$ms->find()) {
            return InvalidParameter('Milestone not found.');
        }
        $ms->icon           = $icon;
        $ms->description    = $desc;
        $ms->milestone_date = date('Y-m-d', $ts);
        $ms->save();
        return Success((int)$ms->milestone_id);
    }

    /**
     * Delete a custom milestone.
     *
     * @param int   $id
     * @param array $request
     * @return mixed Success() or an error response
     */
    protected function DeleteDesignMilestone($id, $request)
    {
        $cfg          = $this->getDesignConfig();
        $fk           = $cfg['fk'];
        $id           = (int)$id;
        $milestone_id = (int)($request['MilestoneId'] ?? 0);
        if ($id <= 0 || $milestone_id <= 0) {
            return InvalidParameter($this->fkLabel($fk) . ' and MilestoneId required.');
        }
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_EDIT)) {
            return NoAuthorization();
        }
        $this->db->Clear();
        $ms = new yapo($this->db, DB_PREFIX . $cfg['milestone_table']);
        $ms->clear();
        $ms->milestone_id = $milestone_id;
        $ms->$fk          = $id;
        if (!$ms->find()) {
            return InvalidParameter('Milestone not found.');
        }
        $ms->delete();
        return Success();
    }

    // ---------------------------------------------------------------------
    // Derived-milestone orchestration (caching) — query delegated to config
    // ---------------------------------------------------------------------

    /**
     * Caching orchestration for derived milestones. Delegates the actual row
     * computation to the org's `derived` callable; the rows are returned in the
     * exact order the callable produced (no re-sorting). The cache namespace +
     * function name are supplied by the caller so the cache bucket is identical
     * to the original per-org method (where __CLASS__/__FUNCTION__ were used).
     *
     * @param int    $id
     * @param string $cacheClass    namespace component (original __CLASS__)
     * @param string $cacheFunction namespace component (original __FUNCTION__)
     * @return array ['Status'=>..., 'Milestones'=>[...]]
     */
    protected function GetDerivedDesignMilestones($id, $cacheClass, $cacheFunction)
    {
        $cfg = $this->getDesignConfig();
        $id  = (int)$id;
        if ($id <= 0) {
            return ['Status' => InvalidParameter($this->fkLabel($cfg['fk']) . ' is required.'), 'Milestones' => []];
        }
        $key = Ork3::$Lib->ghettocache->key([$this->fkLabel($cfg['fk']) => $id]);
        if (($cache = Ork3::$Lib->ghettocache->get($cacheClass . '.' . $cacheFunction, $key, 300)) !== false) {
            return $cache;
        }
        $out      = call_user_func($cfg['derived'], $id);
        $response = ['Status' => Success(), 'Milestones' => $out];
        return Ork3::$Lib->ghettocache->cache($cacheClass . '.' . $cacheFunction, $key, $response);
    }

    /**
     * The request-key label used in the derived-milestone cache key. Kept as the
     * org's PascalCase request param (e.g. 'KingdomId') to match the original
     * cache key exactly. Derivable from the config so each org need not repeat it.
     *
     * @param array $cfg
     * @return string
     */
    private function fkLabel($fk)
    {
        // fk 'kingdom_id' -> 'KingdomId', 'park_id' -> 'ParkId', etc.
        $parts = array_map('ucfirst', explode('_', $fk));
        return implode('', $parts);
    }
}
