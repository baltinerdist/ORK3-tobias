<?php

/**
 * Model_Survey — thin snake_case facade over the three survey domain classes
 * (Survey, SurveyResponse, SurveyReport). No logic; every method is a one-line
 * delegate. This is the ONLY place under orkui/ that may instantiate those
 * classes (Global Constraints, spec §5 "Model").
 */
class Model_Survey extends Model
{
    // -----------------------------------------------------------------------
    // Survey — definition, lifecycle, auth, images
    // -----------------------------------------------------------------------

    public function is_ork_admin(int $uid): bool
    {
        return $this->_survey()->isOrkAdmin($uid);
    }

    public function can_create(int $uid, string $scopeType, int $scopeId): bool
    {
        return $this->_survey()->canCreate($uid, $scopeType, $scopeId);
    }

    public function can_manage(int $uid, array $surveyRow): bool
    {
        return $this->_survey()->canManage($uid, $surveyRow);
    }

    public function manageable_scopes(int $uid): array
    {
        return $this->_survey()->manageableScopes($uid);
    }

    public function scope_name(string $scopeType, int $scopeId): string
    {
        return $this->_survey()->scopeName($scopeType, $scopeId);
    }

    public function get_row(int $surveyId): ?array
    {
        return $this->_survey()->getRow($surveyId);
    }

    public function get_by_slug(string $slug): ?array
    {
        return $this->_survey()->getBySlug($slug);
    }

    public function survey_for_page(int $pageId): ?array
    {
        return $this->_survey()->surveyForPage($pageId);
    }

    public function survey_for_question(int $questionId): ?array
    {
        return $this->_survey()->surveyForQuestion($questionId);
    }

    public function survey_for_image(int $imageId): ?array
    {
        return $this->_survey()->surveyForImage($imageId);
    }

    public function is_structure_locked(array $surveyRow): bool
    {
        return $this->_survey()->isStructureLocked($surveyRow);
    }

    /** Message the domain uses when a structural mutation hits a locked survey. */
    public function locked_error(): string
    {
        return Survey::LOCKED_ERROR;
    }

    public function get(int $surveyId): array
    {
        return $this->_survey()->get($surveyId);
    }

    public function list_manageable(int $uid, ?string $scopeType = null, ?int $scopeId = null): array
    {
        return $this->_survey()->listManageable($uid, $scopeType, $scopeId);
    }

    public function create(int $uid, string $scopeType, int $scopeId, string $title): array
    {
        return $this->_survey()->create($uid, $scopeType, $scopeId, $title);
    }

    public function update(int $surveyId, array $fields): array
    {
        return $this->_survey()->update($surveyId, $fields);
    }

    public function set_status(int $surveyId, string $status): array
    {
        return $this->_survey()->setStatus($surveyId, $status);
    }

    public function clone_survey(int $surveyId, int $uid): array
    {
        return $this->_survey()->cloneSurvey($surveyId, $uid);
    }

    public function delete(int $surveyId): array
    {
        return $this->_survey()->delete($surveyId);
    }

    public function page_add(int $surveyId): array
    {
        return $this->_survey()->pageAdd($surveyId);
    }

    public function page_update(int $pageId, array $fields): array
    {
        return $this->_survey()->pageUpdate($pageId, $fields);
    }

    public function page_delete(int $pageId): array
    {
        return $this->_survey()->pageDelete($pageId);
    }

    public function page_reorder(int $surveyId, array $pageIds): array
    {
        return $this->_survey()->pageReorder($surveyId, $pageIds);
    }

    public function question_add(int $surveyId, int $pageId, string $type, ?int $afterQuestionId): array
    {
        return $this->_survey()->questionAdd($surveyId, $pageId, $type, $afterQuestionId);
    }

    public function question_update(int $questionId, array $fields): array
    {
        return $this->_survey()->questionUpdate($questionId, $fields);
    }

    public function question_delete(int $questionId): array
    {
        return $this->_survey()->questionDelete($questionId);
    }

    public function question_reorder(int $pageId, array $questionIds): array
    {
        return $this->_survey()->questionReorder($pageId, $questionIds);
    }

    public function question_move(int $questionId, int $pageId, int $index): array
    {
        return $this->_survey()->questionMove($questionId, $pageId, $index);
    }

    public function option_set(int $questionId, string $role, array $options): array
    {
        return $this->_survey()->optionSet($questionId, $role, $options);
    }

    public function image_add(int $surveyId, int $uid, string $tmpPath, string $clientName): array
    {
        return $this->_survey()->imageAdd($surveyId, $uid, $tmpPath, $clientName);
    }

    public function image_delete(int $imageId): array
    {
        return $this->_survey()->imageDelete($imageId);
    }

    public function image_url(array $imageRow): string
    {
        return $this->_survey()->imageUrl($imageRow);
    }

    public function render_markdown(?string $md): string
    {
        return $this->_survey()->renderMarkdown($md);
    }

    /**
     * The question type catalogue the builder and the runner draw from, so the
     * client never keeps its own copy of SurveyTypes (spec §4).
     *
     * @return array{types: string[], show_if_sources: string[], option_roles: array<string, string[]>, other_max_length: int}
     */
    public function type_catalog(): array
    {
        return [
            'types'            => SurveyTypes::TYPES,
            'show_if_sources'  => SurveyTypes::SHOW_IF_SOURCES,
            'option_roles'     => SurveyTypes::OPTION_ROLES,
            'other_max_length' => SurveyTypes::OTHER_MAX_LENGTH,
        ];
    }

    // -----------------------------------------------------------------------
    // SurveyResponse — eligibility, drafts, consent, submit
    // -----------------------------------------------------------------------

    /** Byte ceiling the domain applies to an answers JSON payload. */
    public function max_answer_bytes(): int
    {
        return SurveyResponse::MAX_DRAFT_BYTES;
    }

    public function tenure_months(int $uid): int
    {
        return $this->_response()->tenureMonths($uid);
    }

    public function eligibility(array $surveyRow, int $uid): array
    {
        return $this->_response()->eligibility($surveyRow, $uid);
    }

    public function definition_for_respondent(int $surveyId, int $uid, bool $preview): array
    {
        return $this->_response()->definitionForRespondent($surveyId, $uid, $preview);
    }

    public function draft_save(int $surveyId, int $uid, array $answers, int $pageIndex): array
    {
        return $this->_response()->draftSave($surveyId, $uid, $answers, $pageIndex);
    }

    public function draft_load(int $surveyId, int $uid): ?array
    {
        return $this->_response()->draftLoad($surveyId, $uid);
    }

    public function draft_delete(int $surveyId, int $uid): void
    {
        $this->_response()->draftDelete($surveyId, $uid);
    }

    public function validate_submission(array $definition, array $answers): array
    {
        return $this->_response()->validateSubmission($definition, $answers);
    }

    public function submit(int $surveyId, int $uid, array $answers, string $consent, int $durationSeconds, bool $isTest): array
    {
        return $this->_response()->submit($surveyId, $uid, $answers, $consent, $durationSeconds, $isTest);
    }

    public function available_for(int $uid): array
    {
        return $this->_response()->availableFor($uid);
    }

    public function banner_for(int $uid): ?array
    {
        return $this->_response()->bannerFor($uid);
    }

    public function dismiss_banner(int $surveyId, int $uid): void
    {
        $this->_response()->dismissBanner($surveyId, $uid);
    }

    // -----------------------------------------------------------------------
    // SurveyReport — aggregation, rows, CSV
    // -----------------------------------------------------------------------

    public function summary(int $surveyId, array $filters): array
    {
        return $this->_report()->summary($surveyId, $filters);
    }

    public function aggregate(int $surveyId, array $filters): array
    {
        return $this->_report()->aggregate($surveyId, $filters);
    }

    /** Composite for SurveyAjax/results: summary + per-question aggregation in one call. */
    public function results(int $surveyId, array $filters): array
    {
        $out = $this->_report()->aggregate($surveyId, $filters);
        $out['summary'] = $this->_report()->summary($surveyId, $filters);
        return $out;
    }

    public function rows(int $surveyId, array $filters, int $offset, int $limit): array
    {
        return $this->_report()->rows($surveyId, $filters, $offset, $limit);
    }

    public function csv(int $surveyId, array $filters): string
    {
        return $this->_report()->csv($surveyId, $filters);
    }

    // -----------------------------------------------------------------------
    // Factories
    // -----------------------------------------------------------------------

    private function _survey(): Survey
    {
        return new Survey();
    }

    private function _response(): SurveyResponse
    {
        return new SurveyResponse();
    }

    private function _report(): SurveyReport
    {
        return new SurveyReport();
    }
}
