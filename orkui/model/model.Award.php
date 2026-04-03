<?php

class Model_Award extends Model {

    function __construct() {
        parent::__construct();
        $this->Award = new APIModel('Award');
        $this->Kingdom = new APIModel('Kingdom');
    }

    private static function compareAwardsByName($a, $b) {
        return strcmp($a["KingdomAwardName"], $b["KingdomAwardName"]);
    }

    // Canonical award_ids for association-type awards (Squire, Man-At-Arms, Page, Lord's Page)
    private static $associateAwardIds = [13, 14, 15, 16];

    // Ordering: Squire first, then Man-At-Arms, Page, Lord's Page
    private static $associateOrder = [16 => 0, 14 => 1, 15 => 2, 13 => 3];

    function fetch_associate_award_list($kingdom_id = 0) {
        if (!valid_id($kingdom_id)) return [];
        $cacheKey = Ork3::$Lib->ghettocache->key(['KingdomId' => (int)$kingdom_id, 'type' => 'assoc']);
        if (($cached = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $cacheKey, 1200)) !== false)
            return $cached;
        $all = $this->Kingdom->GetAwardList([
            'IsLadder'    => null,
            'IsTitle'     => null,
            'KingdomId'   => $kingdom_id,
            'OfficerRole' => 'Awards',
        ]);
        $awards = [];
        if (!empty($all['Awards'])) {
            foreach ($all['Awards'] as $a) {
                if (in_array((int)$a['AwardId'], self::$associateAwardIds)) {
                    $awards[] = [
                        'KingdomAwardId' => (int)$a['KingdomAwardId'],
                        'Name'           => $a['KingdomAwardName'],
                        'AwardId'        => (int)$a['AwardId'],
                    ];
                }
            }
            usort($awards, function($a, $b) {
                $oa = self::$associateOrder[$a['AwardId']] ?? 99;
                $ob = self::$associateOrder[$b['AwardId']] ?? 99;
                return $oa - $ob;
            });
        }
        return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $cacheKey, $awards);
    }

    function fetch_award_option_list($kingdom_id = 0, $officer_role = null) {
        $cacheKey = Ork3::$Lib->ghettocache->key(['KingdomId' => (int)$kingdom_id, 'OfficerRole' => $officer_role]);
        if (($cached = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $cacheKey, 1200)) !== false)
            return $cached;
        if (valid_id($kingdom_id)) {
            $awards = $this->Kingdom->GetAwardList(array(
                    'IsLadder' => null,
                    'IsTitle' => null,
                    'KingdomId' => $kingdom_id,
                    'OfficerRole' => $officer_role
                ));
        } else {
            $awards = $this->Award->GetAwardList(array(
                    'IsLadder' => null,
                    'IsTitle' => null,
                    'OfficerRole' => $officer_role
                ));
        }
            
        if ($awards['Status']['Status'] == 0) {
            uasort($awards['Awards'], array('Model_Award','compareAwardsByName'));

            $ladder = array();
            $other  = array();
            foreach ($awards['Awards'] as $award) {
                if (!empty($award['IsLadder'])) {
                    $ladder[] = $award;
                } else {
                    $other[] = $award;
                }
            }

            $options = '';
            if (!empty($ladder)) {
                $options .= "<optgroup label='Common Awards'>";
                foreach ($ladder as $award) {
                    $options .= "<option value='" . htmlspecialchars($award['KingdomAwardId'], ENT_QUOTES) . "' data-is-ladder='1' data-award-id='" . htmlspecialchars($award['AwardId'], ENT_QUOTES) . "'>" . htmlspecialchars($award['KingdomAwardName'], ENT_QUOTES) . "</option>";
                }
                $options .= "</optgroup>";
            }
            if (!empty($other)) {
                $options .= "<optgroup label='Awards'>";
                foreach ($other as $award) {
                    $options .= "<option value='" . htmlspecialchars($award['KingdomAwardId'], ENT_QUOTES) . "'>" . htmlspecialchars($award['KingdomAwardName'], ENT_QUOTES) . "</option>";
                }
                $options .= "</optgroup>";
            }
            return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $cacheKey, $options);
        } else {
            return false;
        }
    }

    
}

?>