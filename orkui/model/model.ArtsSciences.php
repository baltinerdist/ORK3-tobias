<?php

class Model_ArtsSciences extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->AS = new APIModel('ArtsSciences');
    }

    public function list_competitions($request)
    {
        return $this->AS->ListCompetitions($request);
    }
    public function get_competition($request)
    {
        return $this->AS->GetCompetition($request);
    }
    public function create_competition($request)
    {
        return $this->AS->CreateCompetition($request);
    }
    public function update_competition($request)
    {
        return $this->AS->UpdateCompetition($request);
    }
    public function delete_competition($request)
    {
        return $this->AS->DeleteCompetition($request);
    }

    public function get_taxonomy($request)
    {
        return $this->AS->GetTaxonomy($request);
    }
    public function save_taxonomy($request)
    {
        return $this->AS->SaveTaxonomy($request);
    }
    public function delete_taxonomy($request)
    {
        return $this->AS->DeleteTaxonomy($request);
    }
    public function reorder_taxonomy($request)
    {
        return $this->AS->ReorderTaxonomy($request);
    }

    public function get_criteria($request)
    {
        return $this->AS->GetCriteria($request);
    }
    public function save_criterion($request)
    {
        return $this->AS->SaveCriterion($request);
    }
    public function delete_criterion($request)
    {
        return $this->AS->DeleteCriterion($request);
    }

    public function get_participants($request)
    {
        return $this->AS->GetParticipants($request);
    }
    public function save_participant($request)
    {
        return $this->AS->SaveParticipant($request);
    }
    public function delete_participant($request)
    {
        return $this->AS->DeleteParticipant($request);
    }

    public function get_judges($request)
    {
        return $this->AS->GetJudges($request);
    }
    // F6: two positional scalars ($token, $competition_id) — forwarded verbatim by
    // APIModel::__call (call_user_func_array) to the lib's self_judge_id($token, $cid),
    // which resolves the caller's OWN judge_id (never redacted), else 0.
    public function self_judge_id($token, $competition_id)
    {
        return $this->AS->self_judge_id($token, $competition_id);
    }
    public function save_judge($request)
    {
        return $this->AS->SaveJudge($request);
    }
    public function delete_judge($request)
    {
        return $this->AS->DeleteJudge($request);
    }

    public function get_entries($request)
    {
        return $this->AS->GetEntries($request);
    }
    public function save_entry($request)
    {
        return $this->AS->SaveEntry($request);
    }
    public function delete_entry($request)
    {
        return $this->AS->DeleteEntry($request);
    }

    public function get_scores($request)
    {
        return $this->AS->GetScores($request);
    }

    // #40: entrant self-service. Two positional scalars forwarded verbatim by APIModel::__call
    // (call_user_func_array) to the lib, which enforces ownership + closed status + the
    // competition's share_with_entrants setting and keeps judge identity blind. No SQL here.
    public function get_my_entries($token)
    {
        return $this->AS->GetMyEntries($token);
    }
    public function get_my_entry_results($token, $entry_id)
    {
        return $this->AS->GetMyEntryResults($token, $entry_id);
    }
    public function save_score($request)
    {
        return $this->AS->SaveScore($request);
    }

    public function get_awards($request)
    {
        return $this->AS->GetAwards($request);
    }
    public function save_award($request)
    {
        return $this->AS->SaveAward($request);
    }
    public function delete_award($request)
    {
        return $this->AS->DeleteAward($request);
    }

    public function get_rec_context($request)
    {
        return $this->AS->GetRecContext($request);
    }
    public function save_rec($request)
    {
        return $this->AS->SaveRec($request);
    }
    public function delete_rec($request)
    {
        return $this->AS->DeleteRec($request);
    }

    public function compute_results($request)
    {
        return $this->AS->ComputeResults($request);
    }
    public function preview_award($request)
    {
        return $this->AS->PreviewAward($request);
    }

    public function future_events($request)
    {
        return $this->AS->FutureEvents($request);
    }
    public function player_search($request)
    {
        return $this->AS->PlayerSearch($request);
    }

    public function list_presets($request)
    {
        return $this->AS->ListPresets($request);
    }
    public function get_preset($request)
    {
        return $this->AS->GetPreset($request);
    }
    public function delete_preset($request)
    {
        return $this->AS->DeletePreset($request);
    }
    public function save_taxonomy_preset($request)
    {
        return $this->AS->SaveTaxonomyPreset($request);
    }
    public function save_award_preset($request)
    {
        return $this->AS->SaveAwardPreset($request);
    }
    public function preview_load_preset($request)
    {
        return $this->AS->PreviewLoadPreset($request);
    }
    public function load_taxonomy_preset($request)
    {
        return $this->AS->LoadTaxonomyPreset($request);
    }
    public function load_award_preset($request)
    {
        return $this->AS->LoadAwardPreset($request);
    }
}
