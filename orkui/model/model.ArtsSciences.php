<?php

class Model_ArtsSciences extends Model {

	function __construct() {
		parent::__construct();
		$this->AS = new APIModel('ArtsSciences');
	}

	function list_competitions($request)   { return $this->AS->ListCompetitions($request); }
	function get_competition($request)     { return $this->AS->GetCompetition($request); }
	function create_competition($request)  { return $this->AS->CreateCompetition($request); }
	function update_competition($request)  { return $this->AS->UpdateCompetition($request); }
	function delete_competition($request)  { return $this->AS->DeleteCompetition($request); }

	function get_taxonomy($request)        { return $this->AS->GetTaxonomy($request); }
	function save_taxonomy($request)       { return $this->AS->SaveTaxonomy($request); }
	function delete_taxonomy($request)     { return $this->AS->DeleteTaxonomy($request); }
	function reorder_taxonomy($request)    { return $this->AS->ReorderTaxonomy($request); }

	function get_criteria($request)        { return $this->AS->GetCriteria($request); }
	function save_criterion($request)      { return $this->AS->SaveCriterion($request); }
	function delete_criterion($request)    { return $this->AS->DeleteCriterion($request); }

	function get_participants($request)    { return $this->AS->GetParticipants($request); }
	function save_participant($request)    { return $this->AS->SaveParticipant($request); }
	function delete_participant($request)  { return $this->AS->DeleteParticipant($request); }

	function get_judges($request)          { return $this->AS->GetJudges($request); }
	function save_judge($request)          { return $this->AS->SaveJudge($request); }
	function delete_judge($request)        { return $this->AS->DeleteJudge($request); }

	function get_entries($request)         { return $this->AS->GetEntries($request); }
	function save_entry($request)          { return $this->AS->SaveEntry($request); }
	function delete_entry($request)        { return $this->AS->DeleteEntry($request); }

	function get_scores($request)          { return $this->AS->GetScores($request); }
	function save_score($request)          { return $this->AS->SaveScore($request); }

	function get_awards($request)          { return $this->AS->GetAwards($request); }
	function save_award($request)          { return $this->AS->SaveAward($request); }
	function delete_award($request)        { return $this->AS->DeleteAward($request); }

	function get_rec_context($request)     { return $this->AS->GetRecContext($request); }
	function save_rec($request)            { return $this->AS->SaveRec($request); }
	function delete_rec($request)          { return $this->AS->DeleteRec($request); }

	function compute_results($request)     { return $this->AS->ComputeResults($request); }
	function preview_award($request)       { return $this->AS->PreviewAward($request); }

	function list_presets($request)            { return $this->AS->ListPresets($request); }
	function get_preset($request)              { return $this->AS->GetPreset($request); }
	function delete_preset($request)           { return $this->AS->DeletePreset($request); }
	function save_taxonomy_preset($request)    { return $this->AS->SaveTaxonomyPreset($request); }
	function save_award_preset($request)       { return $this->AS->SaveAwardPreset($request); }
	function preview_load_preset($request)     { return $this->AS->PreviewLoadPreset($request); }
	function load_taxonomy_preset($request)    { return $this->AS->LoadTaxonomyPreset($request); }
	function load_award_preset($request)       { return $this->AS->LoadAwardPreset($request); }
}
