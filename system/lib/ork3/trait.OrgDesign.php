<?php

/**
 * Shared profile-design + milestone engine for org library classes
 * (Kingdom, Park, Unit). Behavior-identical extraction of the
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
            // Idempotent seed: a concurrent first-read may have already inserted the
            // 1:1 design row, so use INSERT IGNORE (the FK is unique) to avoid a
            // duplicate-key error on the race, then re-find the authoritative row.
            $this->db->Clear();
            $this->db->query(
                'INSERT IGNORE INTO ' . DB_PREFIX . $cfg['design_table']
                . ' (' . $fk . ', hero_overlay) VALUES (' . (int)$id . ", 'med')"
            );
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
                // yapo drops nulls from UPDATE — assign '' to actually clear the column.
                $design->$col = '';
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
            $design->name_font = $nf === '' ? '' : $nf;
        }
        if (array_key_exists('MilestoneConfig', $request)) {
            $mc = (string)$request['MilestoneConfig'];
            if ($mc !== '') {
                $decoded = json_decode($mc, true);
                if (!is_array($decoded)) {
                    return InvalidParameter('Milestone config must be valid JSON.');
                }
            }
            $design->milestone_config = $mc === '' ? '' : $mc;
        }

        if (array_key_exists('Tagline', $request)) {
            $tg = trim((string)$request['Tagline']);
            if (strlen($tg) > 160) {
                return InvalidParameter('Tagline is limited to 160 characters.');
            }
            if ($tg !== '' && $pf->containsProfanity($tg)) {
                return InvalidParameter('Tagline', ProfanityFilter::ERROR_MESSAGE);
            }
            $design->tagline = $tg === '' ? '' : $tg;
        }

        if (array_key_exists('SocialLinks', $request)) {
            $sl = trim((string)$request['SocialLinks']);
            $cleanLinks = [];
            if ($sl !== '') {
                $decoded = json_decode($sl, true);
                if (!is_array($decoded)) {
                    return InvalidParameter('SocialLinks must be valid JSON.');
                }
                // Per-slug host allow-list: a "discord" link must actually point at a
                // discord host, etc. — otherwise a manager could spoof a platform icon
                // onto an arbitrary URL. Keys are the accepted slugs; a null value means
                // any https host is allowed (generic website/other).
                $hostAllow = [
                    'discord'   => ['discord.gg', 'discord.com'],
                    'facebook'  => ['facebook.com'],
                    'instagram' => ['instagram.com'],
                    'threads'   => ['threads.net'],
                    'bluesky'   => ['bsky.app'],
                    'twitter'   => ['x.com', 'twitter.com'],
                    'youtube'   => ['youtube.com', 'youtu.be'],
                    'amtwiki'   => ['amtwiki.net'],
                ];
                foreach ($decoded as $slug => $url) {
                    if (!array_key_exists($slug, $hostAllow)) {
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
                    $allowedHosts = $hostAllow[$slug];
                    // A null allow-list means "any https host" (generic website/other).
                    if (is_array($allowedHosts)) {
                        $host = strtolower((string)parse_url($url, PHP_URL_HOST));
                        if ($host === '') {
                            return InvalidParameter('SocialLinks.' . $slug . ' is not a valid URL.');
                        }
                        if (strpos($host, 'www.') === 0) {
                            $host = substr($host, 4);
                        }
                        $ok = false;
                        foreach ($allowedHosts as $allowedHost) {
                            if ($host === $allowedHost || substr($host, -(strlen($allowedHost) + 1)) === '.' . $allowedHost) {
                                $ok = true;
                                break;
                            }
                        }
                        if (!$ok) {
                            return InvalidParameter('SocialLinks.' . $slug . ' must link to ' . implode(' or ', $allowedHosts) . '.');
                        }
                    }
                    $cleanLinks[$slug] = $url;
                }
            }
            // yapo drops nulls from UPDATE — assign '' to actually clear the column.
            $design->social_links = empty($cleanLinks) ? '' : json_encode($cleanLinks);
        }

        if (array_key_exists('Announcement', $request)) {
            $an = trim((string)$request['Announcement']);
            if (strlen($an) > 280) {
                return InvalidParameter('Announcement is limited to 280 characters.');
            }
            if ($an !== '' && $pf->containsProfanity($an)) {
                return InvalidParameter('Announcement', ProfanityFilter::ERROR_MESSAGE);
            }
            $design->announcement = $an === '' ? '' : $an;
        }

        if (array_key_exists('AnnouncementUntil', $request)) {
            $au = trim((string)$request['AnnouncementUntil']);
            if ($au === '') {
                // yapo drops nulls from UPDATE; '' persists as '0000-00-00', which templates treat as empty.
                $design->announcement_until = '';
            } else {
                $ts = strtotime($au);
                if ($ts === false) {
                    return InvalidParameter('AnnouncementUntil must be a valid date.');
                }
                $design->announcement_until = date('Y-m-d', $ts);
            }
        }

        if (array_key_exists('AnnouncementStarts', $request)) {
            $as = trim((string)$request['AnnouncementStarts']);
            if ($as === '') {
                // yapo drops nulls from UPDATE; '' persists as '0000-00-00', which templates treat as empty.
                $design->announcement_starts = '';
            } else {
                $ts = strtotime($as);
                if ($ts === false) {
                    return InvalidParameter('AnnouncementStarts must be a valid date.');
                }
                $design->announcement_starts = date('Y-m-d', $ts);
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
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_CREATE)) {
            return NoAuthorization();
        }
        require_once(__DIR__ . '/class.ProfanityFilter.php');
        $pf = new ProfanityFilter();
        $desc = trim((string)($request['Description'] ?? ''));
        if ($desc === '') {
            return InvalidParameter('Description is required.');
        }
        if (mb_strlen($desc, 'UTF-8') > 500) {
            $desc = mb_substr($desc, 0, 500, 'UTF-8');
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
        $ms->created_by     = (int)$mundane_id;
        $ms->save();
        if ((int)$ms->milestone_id <= 0) {
            return ProcessingError('Failed to save milestone.');
        }
        return Success((int)$ms->milestone_id);
    }

    /**
     * Edit an existing custom milestone (auth + profanity + date + icon
     * validation). Ownership is enforced by loading the row by milestone_id +
     * $fk = $id; a mismatch yields 'Milestone not found.'. created_by is NOT
     * touched on update (audit trail preserves the original author).
     *
     * @param int   $id
     * @param array $request
     * @return mixed Success() or an error response
     */
    protected function UpdateDesignMilestone($id, $request)
    {
        $cfg = $this->getDesignConfig();
        $fk  = $cfg['fk'];
        $id  = (int)$id;
        if ($id <= 0) {
            return InvalidParameter($this->fkLabel($fk) . ' is required.');
        }
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_CREATE)) {
            return NoAuthorization();
        }
        $milestone_id = (int)($request['MilestoneId'] ?? 0);
        if ($milestone_id <= 0) {
            return InvalidParameter('MilestoneId is required.');
        }
        $this->db->Clear();
        $ms = new yapo($this->db, DB_PREFIX . $cfg['milestone_table']);
        $ms->clear();
        $ms->milestone_id = $milestone_id;
        $ms->$fk          = $id;
        if (!$ms->find()) {
            return InvalidParameter('Milestone not found.');
        }
        require_once(__DIR__ . '/class.ProfanityFilter.php');
        $pf = new ProfanityFilter();
        $desc = trim((string)($request['Description'] ?? ''));
        if ($desc === '') {
            return InvalidParameter('Description is required.');
        }
        if (mb_strlen($desc, 'UTF-8') > 500) {
            $desc = mb_substr($desc, 0, 500, 'UTF-8');
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
        $ms->description    = $desc;
        $ms->icon           = $icon;
        $ms->milestone_date = date('Y-m-d', $ts);
        $ms->save();
        return Success();
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
        if (!($mundane_id > 0) || !Ork3::$Lib->authorization->HasAuthority($mundane_id, $cfg['auth'], $id, AUTH_CREATE)) {
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

    /**
     * Merge custom (stored) + derived milestones into one timeline-ready list,
     * sorted ascending by date via strcmp. Returns a PLAIN LIST (not wrapped in
     * ['Milestones'=>...]), replicating exactly what the org controllers built
     * inline before this was hoisted into the trait.
     *
     * The derived result is passed in already-fetched so each org supplies it
     * through its own GetDerived*Milestones (preserving the per-org cache
     * namespace); the derived rows are expected under $derivedResult['Milestones'].
     *
     * @param int   $id
     * @param array $derivedResult ['Milestones'=>[...]] from the org's derived fetch
     * @return array plain list of merged milestone rows
     */
    protected function GetMergedDesignMilestones($id, $derivedResult)
    {
        $id         = (int)$id;
        $milestones = [];
        $custom     = $this->GetDesignMilestones($id);
        foreach (($custom['Milestones'] ?? []) as $m) {
            $milestones[] = [
                'MilestoneId'   => (int)$m['MilestoneId'],
                'Type'          => 'custom',
                'Icon'          => $m['Icon'],
                'Description'   => $m['Description'],
                'MilestoneDate' => $m['MilestoneDate'],
                'IsDerived'     => false,
            ];
        }
        foreach ((is_array($derivedResult) ? ($derivedResult['Milestones'] ?? []) : []) as $m) {
            $milestones[] = $m + ['MilestoneId' => 0, 'IsDerived' => true];
        }
        usort($milestones, function ($a, $b) {
            return strcmp($a['MilestoneDate'], $b['MilestoneDate']);
        });
        return $milestones;
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
            return InvalidParameter($this->fkLabel($cfg['fk']) . ' is required.');
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
