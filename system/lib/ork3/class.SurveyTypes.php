<?php

/**
 * SurveyTypes — the survey module's question type catalog.
 *
 * Pure logic: no DB, no globals, no superglobals. This is the single shared
 * table the builder, the runner and the aggregator all consult, so they cannot
 * disagree about what a type means (design spec §4).
 *
 * Responsibilities:
 *  - the canonical type list and which types accept answers,
 *  - per-type `settings` defaults, validation and coercion,
 *  - the options auto-seeded with a new question and the minimum option counts,
 *  - normalising one raw answer into `ork_survey_answer` rows,
 *  - the one-level `show_if` rule shared by client and server.
 *
 * NOTE: startup.php instantiates every class in system/lib/ork3, so the
 * constructor must stay public/default even though every method is static.
 */
final class SurveyTypes
{
    /** Every question type, in builder palette order. */
    public const TYPES = [
        'single', 'multi', 'dropdown', 'yesno', 'rating', 'nps', 'matrix', 'ranking',
        'short_text', 'paragraph', 'number', 'date', 'section', 'image',
    ];

    /** Types that record answers (TYPES minus the presentational 'section' and 'image'). */
    public const ANSWERABLE = [
        'single', 'multi', 'dropdown', 'yesno', 'rating', 'nps', 'matrix', 'ranking',
        'short_text', 'paragraph', 'number', 'date',
    ];

    /** Types a show_if condition may depend on (condition = option selected). */
    public const SHOW_IF_SOURCES = ['single', 'dropdown', 'yesno', 'multi'];

    /** Option roles each type owns; absent types own no options. */
    public const OPTION_ROLES = [
        'single'   => ['choice'],
        'multi'    => ['choice'],
        'dropdown' => ['choice'],
        'yesno'    => ['choice'],
        'matrix'   => ['row', 'column'],
        'ranking'  => ['choice'],
    ];

    /** Maximum stored length of an "Other (please specify)" write-in (column is VARCHAR(255)). */
    public const OTHER_MAX_LENGTH = 255;

    /** Fixed NPS scale. */
    public const NPS_MIN = 0;
    public const NPS_MAX = 10;

    public static function isType(string $type): bool
    {
        return in_array($type, self::TYPES, true);
    }

    public static function isAnswerable(string $type): bool
    {
        return in_array($type, self::ANSWERABLE, true);
    }

    /**
     * Default `settings` for a type (spec §4). Unknown type => [].
     *
     * @return array<string, mixed>
     */
    public static function defaultSettings(string $type): array
    {
        switch ($type) {
            case 'single':
                return ['randomize' => false];
            case 'multi':
                return ['randomize' => false, 'min_select' => 0, 'max_select' => 0];
            case 'rating':
                return ['min' => 1, 'max' => 5, 'min_label' => '', 'max_label' => '', 'icon' => 'star'];
            case 'nps':
                return ['min_label' => 'Not likely', 'max_label' => 'Very likely'];
            case 'matrix':
                return ['require_all_rows' => false];
            case 'ranking':
                return ['rank_all' => true];
            case 'short_text':
                return ['max_length' => 200, 'placeholder' => ''];
            case 'paragraph':
                return ['max_length' => 4000, 'placeholder' => ''];
            case 'number':
                return ['min' => null, 'max' => null, 'step' => 1, 'unit' => ''];
            case 'date':
                return ['min' => null, 'max' => null];
            case 'image':
                return ['caption' => ''];
            case 'dropdown':
            case 'yesno':
            case 'section':
            default:
                return [];
        }
    }

    /**
     * Merge submitted settings over the defaults, coerce types, drop unknown keys.
     *
     * @param  string             $type
     * @param  array|string|null  $settings  array, JSON object string, or null
     * @return array{ok: bool, settings: array<string, mixed>, error: ?string}
     */
    public static function validateSettings(string $type, $settings): array
    {
        if (!self::isType($type)) {
            return ['ok' => false, 'settings' => [], 'error' => 'Unknown question type.'];
        }

        $in = $settings;
        if (is_string($in)) {
            $trimmed = trim($in);
            if ('' === $trimmed) {
                $in = [];
            } else {
                $decoded = json_decode($trimmed, true);
                if (!is_array($decoded)) {
                    return ['ok' => false, 'settings' => [], 'error' => 'Settings must be a JSON object.'];
                }
                $in = $decoded;
            }
        }
        if (null === $in) {
            $in = [];
        }
        if (!is_array($in)) {
            return ['ok' => false, 'settings' => [], 'error' => 'Settings must be a JSON object.'];
        }

        $out = self::defaultSettings($type);

        switch ($type) {
            case 'single':
                $out['randomize'] = self::toBool($in['randomize'] ?? $out['randomize']);
                break;

            case 'multi':
                $out['randomize'] = self::toBool($in['randomize'] ?? $out['randomize']);
                $out['min_select'] = self::toInt($in['min_select'] ?? $out['min_select']);
                $out['max_select'] = self::toInt($in['max_select'] ?? $out['max_select']);
                if ($out['min_select'] < 0 || $out['max_select'] < 0) {
                    return self::settingsError('Selection limits cannot be negative.');
                }
                if ($out['max_select'] > 0 && $out['min_select'] > $out['max_select']) {
                    return self::settingsError('Minimum selections cannot exceed maximum selections.');
                }
                break;

            case 'rating':
                $out['min'] = self::toInt($in['min'] ?? $out['min']);
                $out['max'] = self::toInt($in['max'] ?? $out['max']);
                $out['min_label'] = self::toStr($in['min_label'] ?? $out['min_label']);
                $out['max_label'] = self::toStr($in['max_label'] ?? $out['max_label']);
                $out['icon'] = self::toStr($in['icon'] ?? $out['icon']);
                if (!in_array($out['icon'], ['star', 'number'], true)) {
                    return self::settingsError('Rating icon must be "star" or "number".');
                }
                if ($out['max'] <= $out['min']) {
                    return self::settingsError('Rating maximum must be greater than the minimum.');
                }
                if ($out['max'] - $out['min'] > 20) {
                    return self::settingsError('A rating scale may span at most 20 points.');
                }
                break;

            case 'nps':
                $out['min_label'] = self::toStr($in['min_label'] ?? $out['min_label']);
                $out['max_label'] = self::toStr($in['max_label'] ?? $out['max_label']);
                break;

            case 'matrix':
                $out['require_all_rows'] = self::toBool($in['require_all_rows'] ?? $out['require_all_rows']);
                break;

            case 'ranking':
                $out['rank_all'] = self::toBool($in['rank_all'] ?? $out['rank_all']);
                break;

            case 'short_text':
            case 'paragraph':
                $hardCap = ('short_text' === $type) ? 255 : 65535;
                $out['max_length'] = self::toInt($in['max_length'] ?? $out['max_length']);
                $out['placeholder'] = self::toStr($in['placeholder'] ?? $out['placeholder']);
                if ($out['max_length'] < 1) {
                    return self::settingsError('Maximum length must be at least 1.');
                }
                if ($out['max_length'] > $hardCap) {
                    return self::settingsError('Maximum length may not exceed ' . $hardCap . '.');
                }
                break;

            case 'number':
                $out['min'] = self::toNullableFloat($in['min'] ?? $out['min']);
                $out['max'] = self::toNullableFloat($in['max'] ?? $out['max']);
                $out['step'] = self::toFloat($in['step'] ?? $out['step']);
                $out['unit'] = self::toStr($in['unit'] ?? $out['unit']);
                if ($out['step'] <= 0) {
                    return self::settingsError('Step must be greater than zero.');
                }
                if (null !== $out['min'] && null !== $out['max'] && $out['min'] > $out['max']) {
                    return self::settingsError('Minimum cannot be greater than maximum.');
                }
                // Keep whole steps as ints so the JSON round-trip stays tidy.
                $out['step'] = self::tidyNumber($out['step']);
                $out['min'] = (null === $out['min']) ? null : self::tidyNumber($out['min']);
                $out['max'] = (null === $out['max']) ? null : self::tidyNumber($out['max']);
                break;

            case 'date':
                $out['min'] = self::toNullableDate($in['min'] ?? $out['min']);
                $out['max'] = self::toNullableDate($in['max'] ?? $out['max']);
                if (false === $out['min'] || false === $out['max']) {
                    return self::settingsError('Dates must be ISO YYYY-MM-DD.');
                }
                if (null !== $out['min'] && null !== $out['max'] && $out['min'] > $out['max']) {
                    return self::settingsError('Earliest date cannot be after the latest date.');
                }
                break;

            case 'image':
                $out['caption'] = self::toStr($in['caption'] ?? $out['caption']);
                break;

            case 'dropdown':
            case 'yesno':
            case 'section':
            default:
                break;
        }

        return ['ok' => true, 'settings' => $out, 'error' => null];
    }

    /**
     * Options created alongside a new question.
     *
     * @return list<array{role: string, label: string}>
     */
    public static function seedOptions(string $type): array
    {
        switch ($type) {
            case 'yesno':
                return [
                    ['role' => 'choice', 'label' => 'Yes'],
                    ['role' => 'choice', 'label' => 'No'],
                ];
            case 'single':
            case 'multi':
            case 'dropdown':
            case 'ranking':
                return [
                    ['role' => 'choice', 'label' => 'Option 1'],
                    ['role' => 'choice', 'label' => 'Option 2'],
                ];
            case 'matrix':
                return [
                    ['role' => 'row', 'label' => 'Row 1'],
                    ['role' => 'row', 'label' => 'Row 2'],
                    ['role' => 'column', 'label' => 'Disagree'],
                    ['role' => 'column', 'label' => 'Neutral'],
                    ['role' => 'column', 'label' => 'Agree'],
                ];
            default:
                return [];
        }
    }

    /**
     * Minimum option count per role for a type (spec §4).
     *
     * @return array<string, int>
     */
    public static function minOptions(string $type): array
    {
        switch ($type) {
            case 'single':
            case 'multi':
            case 'dropdown':
            case 'yesno':
            case 'ranking':
                return ['choice' => 2];
            case 'matrix':
                return ['row' => 1, 'column' => 2];
            default:
                return [];
        }
    }

    /**
     * Validate one raw answer and normalise it into ork_survey_answer rows.
     *
     * @param  array{type: string, required?: int|bool, settings?: array|string|null} $question
     * @param  list<array{option_id: int|string, role?: string, is_other?: int|bool, label?: string}> $options
     * @param  mixed $value  raw answer per spec §6 "Answers JSON shape" (already json_decoded)
     * @return array{ok: bool, error: ?string, rows: list<array{option_id: ?int, row_option_id: ?int, value_text: ?string, value_num: ?float}>}
     */
    public static function validateAnswer(array $question, array $options, $value): array
    {
        $type = (string) ($question['type'] ?? '');
        if (!self::isType($type)) {
            return self::answerError('Unknown question type.');
        }
        if (!self::isAnswerable($type)) {
            // section / image record nothing and are never required.
            return self::answerOk([]);
        }

        $required = !empty($question['required']);
        $sv = self::validateSettings($type, $question['settings'] ?? []);
        $settings = $sv['ok'] ? $sv['settings'] : self::defaultSettings($type);

        if (self::isEmptyValue($value)) {
            if ($required) {
                return self::answerError('This question is required.');
            }
            return self::answerOk([]);
        }

        switch ($type) {
            case 'single':
            case 'dropdown':
            case 'yesno':
                return self::validateChoice($options, $value);

            case 'multi':
                return self::validateMulti($options, $value, $settings, $required);

            case 'rating':
                return self::validateScale($value, (int) $settings['min'], (int) $settings['max']);

            case 'nps':
                return self::validateScale($value, self::NPS_MIN, self::NPS_MAX);

            case 'matrix':
                return self::validateMatrix($options, $value, $settings);

            case 'ranking':
                return self::validateRanking($options, $value, $settings);

            case 'short_text':
            case 'paragraph':
                return self::validateText($value, (int) $settings['max_length']);

            case 'number':
                return self::validateNumber($value, $settings);

            case 'date':
                return self::validateDate($value, $settings);
        }

        return self::answerError('Unknown question type.');
    }

    /**
     * One-level show_if: is this page/question shown given the answers so far?
     *
     * @param  array<string, mixed>    $item     anything carrying show_if_question_id / show_if_option_id
     * @param  array<int|string, mixed> $answers  [question_id => raw value]
     */
    public static function isShown(array $item, array $answers): bool
    {
        $qid = isset($item['show_if_question_id']) ? (int) $item['show_if_question_id'] : 0;
        $oid = isset($item['show_if_option_id']) ? (int) $item['show_if_option_id'] : 0;
        if ($qid <= 0 || $oid <= 0) {
            return true;
        }
        if (!array_key_exists($qid, $answers)) {
            return false;
        }
        return self::selects($answers[$qid], $oid);
    }

    /**
     * Does this raw answer select $optionId? Handles scalars, ['option_id'=>..] and lists of either.
     *
     * @param mixed $value
     */
    public static function selects($value, int $optionId): bool
    {
        if (null === $value || is_bool($value)) {
            return false;
        }
        if (is_array($value)) {
            if (array_key_exists('option_id', $value)) {
                return self::selects($value['option_id'], $optionId);
            }
            foreach ($value as $entry) {
                if (self::selects($entry, $optionId)) {
                    return true;
                }
            }
            return false;
        }
        if (!is_numeric($value)) {
            return false;
        }
        return (int) $value === $optionId;
    }

    // ------------------------------------------------------------------ answers

    /**
     * @param  list<array<string, mixed>> $options
     * @param  mixed $value
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateChoice(array $options, $value): array
    {
        $row = self::choiceRow($options, $value, 'choice');
        if (isset($row['error'])) {
            return self::answerError((string) $row['error']);
        }
        return self::answerOk([$row['row']]);
    }

    /**
     * @param  list<array<string, mixed>> $options
     * @param  mixed $value
     * @param  array<string, mixed> $settings
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateMulti(array $options, $value, array $settings, bool $required): array
    {
        $entries = is_array($value) && !array_key_exists('option_id', $value) ? array_values($value) : [$value];

        $rows = [];
        $seen = [];
        foreach ($entries as $entry) {
            $row = self::choiceRow($options, $entry, 'choice');
            if (isset($row['error'])) {
                return self::answerError((string) $row['error']);
            }
            $id = (int) $row['row']['option_id'];
            if (isset($seen[$id])) {
                continue;
            }
            $seen[$id] = true;
            $rows[] = $row['row'];
        }

        $count = count($rows);
        $min = (int) ($settings['min_select'] ?? 0);
        $max = (int) ($settings['max_select'] ?? 0);
        if ($required && $min < 1) {
            $min = 1;
        }
        if ($count < $min) {
            return self::answerError('Please select at least ' . $min . ' ' . ($min === 1 ? 'option' : 'options') . '.');
        }
        if ($max > 0 && $count > $max) {
            return self::answerError('Please select at most ' . $max . ' ' . ($max === 1 ? 'option' : 'options') . '.');
        }

        return self::answerOk($rows);
    }

    /**
     * @param  mixed $value
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateScale($value, int $min, int $max): array
    {
        if (is_array($value) || is_bool($value) || !is_numeric($value)) {
            return self::answerError('Please choose a value.');
        }
        $num = (float) $value;
        if ($num !== floor($num)) {
            return self::answerError('Please choose a whole number.');
        }
        $int = (int) $num;
        if ($int < $min || $int > $max) {
            return self::answerError('Please choose a value between ' . $min . ' and ' . $max . '.');
        }
        return self::answerOk([self::row(null, null, null, (float) $int)]);
    }

    /**
     * @param  list<array<string, mixed>> $options
     * @param  mixed $value
     * @param  array<string, mixed> $settings
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateMatrix(array $options, $value, array $settings): array
    {
        if (!is_array($value)) {
            return self::answerError('Please answer the grid.');
        }
        $rowIds = self::optionIds($options, 'row');
        $colIds = self::optionIds($options, 'column');

        $rows = [];
        $answered = [];
        foreach ($value as $rowKey => $colValue) {
            if (self::isEmptyValue($colValue)) {
                continue;
            }
            $rowId = (int) $rowKey;
            if (!in_array($rowId, $rowIds, true)) {
                return self::answerError('Unknown row in this grid.');
            }
            if (is_array($colValue) || is_bool($colValue) || !is_numeric($colValue)) {
                return self::answerError('Unknown answer in this grid.');
            }
            $colId = (int) $colValue;
            if (!in_array($colId, $colIds, true)) {
                return self::answerError('Unknown answer in this grid.');
            }
            if (isset($answered[$rowId])) {
                continue;
            }
            $answered[$rowId] = true;
            $rows[] = self::row($colId, $rowId, null, null);
        }

        if (!empty($settings['require_all_rows']) && count($rows) < count($rowIds)) {
            return self::answerError('Please answer every row.');
        }
        if (0 === count($rows)) {
            return self::answerError('Please answer at least one row.');
        }

        return self::answerOk($rows);
    }

    /**
     * @param  list<array<string, mixed>> $options
     * @param  mixed $value
     * @param  array<string, mixed> $settings
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateRanking(array $options, $value, array $settings): array
    {
        if (!is_array($value)) {
            return self::answerError('Please rank the options.');
        }
        $choiceIds = self::optionIds($options, 'choice');

        $rows = [];
        $seen = [];
        $rank = 0;
        foreach (array_values($value) as $entry) {
            if (self::isEmptyValue($entry)) {
                continue;
            }
            if (is_array($entry) && array_key_exists('option_id', $entry)) {
                $entry = $entry['option_id'];
            }
            if (is_array($entry) || is_bool($entry) || !is_numeric($entry)) {
                return self::answerError('Unknown option in this ranking.');
            }
            $id = (int) $entry;
            if (!in_array($id, $choiceIds, true)) {
                return self::answerError('Unknown option in this ranking.');
            }
            if (isset($seen[$id])) {
                return self::answerError('Each option may be ranked only once.');
            }
            $seen[$id] = true;
            ++$rank;
            $rows[] = self::row($id, null, null, (float) $rank);
        }

        if (!empty($settings['rank_all']) && count($rows) < count($choiceIds)) {
            return self::answerError('Please rank every option.');
        }
        if (0 === count($rows)) {
            return self::answerError('Please rank at least one option.');
        }

        return self::answerOk($rows);
    }

    /**
     * @param  mixed $value
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateText($value, int $maxLength): array
    {
        if (is_array($value) || is_bool($value)) {
            return self::answerError('Please enter a response.');
        }
        $text = trim((string) $value);
        if ('' === $text) {
            return self::answerError('Please enter a response.');
        }
        if (mb_strlen($text) > $maxLength) {
            return self::answerError('Please keep this under ' . $maxLength . ' characters.');
        }
        return self::answerOk([self::row(null, null, $text, null)]);
    }

    /**
     * @param  mixed $value
     * @param  array<string, mixed> $settings
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateNumber($value, array $settings): array
    {
        if (is_array($value) || is_bool($value) || !is_numeric($value)) {
            return self::answerError('Please enter a number.');
        }
        $num = (float) $value;
        $min = isset($settings['min']) && null !== $settings['min'] ? (float) $settings['min'] : null;
        $max = isset($settings['max']) && null !== $settings['max'] ? (float) $settings['max'] : null;
        $step = isset($settings['step']) ? (float) $settings['step'] : 1.0;

        if (null !== $min && $num < $min) {
            return self::answerError('Please enter a number of at least ' . self::tidyNumber($min) . '.');
        }
        if (null !== $max && $num > $max) {
            return self::answerError('Please enter a number no greater than ' . self::tidyNumber($max) . '.');
        }
        if ($step > 0) {
            $base = (null !== $min) ? $min : 0.0;
            $ratio = ($num - $base) / $step;
            if (abs($ratio - round($ratio)) > 1e-9) {
                return self::answerError('Please enter a number in steps of ' . self::tidyNumber($step) . '.');
            }
        }

        return self::answerOk([self::row(null, null, null, $num)]);
    }

    /**
     * @param  mixed $value
     * @param  array<string, mixed> $settings
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function validateDate($value, array $settings): array
    {
        if (is_array($value) || is_bool($value)) {
            return self::answerError('Please enter a date as YYYY-MM-DD.');
        }
        $date = self::toNullableDate($value);
        if (false === $date || null === $date) {
            return self::answerError('Please enter a date as YYYY-MM-DD.');
        }
        $min = isset($settings['min']) ? $settings['min'] : null;
        $max = isset($settings['max']) ? $settings['max'] : null;
        if (null !== $min && '' !== $min && $date < $min) {
            return self::answerError('Please choose a date on or after ' . $min . '.');
        }
        if (null !== $max && '' !== $max && $date > $max) {
            return self::answerError('Please choose a date on or before ' . $max . '.');
        }
        return self::answerOk([self::row(null, null, $date, null)]);
    }

    // ------------------------------------------------------------------ helpers

    /**
     * Resolve one choice entry (scalar id or ['option_id'=>..,'other'=>..]) into a row.
     *
     * @param  list<array<string, mixed>> $options
     * @param  mixed $entry
     * @return array{row?: array<string, mixed>, error?: string}
     */
    private static function choiceRow(array $options, $entry, string $role): array
    {
        $other = null;
        if (is_array($entry)) {
            if (!array_key_exists('option_id', $entry)) {
                return ['error' => 'Please choose an option.'];
            }
            $other = $entry['other'] ?? null;
            $entry = $entry['option_id'];
        }
        if (is_array($entry) || is_bool($entry) || !is_numeric($entry)) {
            return ['error' => 'Please choose an option.'];
        }
        $id = (int) $entry;

        $match = null;
        foreach ($options as $opt) {
            if ((int) ($opt['option_id'] ?? 0) === $id && $role === (string) ($opt['role'] ?? 'choice')) {
                $match = $opt;
                break;
            }
        }
        if (null === $match) {
            return ['error' => 'That option is not part of this question.'];
        }

        $text = null;
        if (!empty($match['is_other'])) {
            $text = is_scalar($other) ? trim((string) $other) : '';
            if ('' === $text) {
                return ['error' => 'Please fill in the "other" box.'];
            }
            if (mb_strlen($text) > self::OTHER_MAX_LENGTH) {
                $text = mb_substr($text, 0, self::OTHER_MAX_LENGTH);
            }
        }

        return ['row' => self::row($id, null, $text, null)];
    }

    /**
     * @param  list<array<string, mixed>> $options
     * @return list<int>
     */
    private static function optionIds(array $options, string $role): array
    {
        $ids = [];
        foreach ($options as $opt) {
            if ($role === (string) ($opt['role'] ?? 'choice')) {
                $ids[] = (int) ($opt['option_id'] ?? 0);
            }
        }
        return $ids;
    }

    /** @return array{option_id: ?int, row_option_id: ?int, value_text: ?string, value_num: ?float} */
    private static function row(?int $optionId, ?int $rowOptionId, ?string $valueText, ?float $valueNum): array
    {
        return [
            'option_id'     => $optionId,
            'row_option_id' => $rowOptionId,
            'value_text'    => $valueText,
            'value_num'     => $valueNum,
        ];
    }

    /**
     * @param  list<array<string, mixed>> $rows
     * @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>}
     */
    private static function answerOk(array $rows): array
    {
        return ['ok' => true, 'error' => null, 'rows' => $rows];
    }

    /** @return array{ok: bool, error: ?string, rows: list<array<string, mixed>>} */
    private static function answerError(string $message): array
    {
        return ['ok' => false, 'error' => $message, 'rows' => []];
    }

    /** @return array{ok: bool, settings: array<string, mixed>, error: ?string} */
    private static function settingsError(string $message): array
    {
        return ['ok' => false, 'settings' => [], 'error' => $message];
    }

    /**
     * "No answer": null, empty string/whitespace, or empty array. Note 0 and "0" are answers.
     *
     * @param mixed $value
     */
    private static function isEmptyValue($value): bool
    {
        if (null === $value) {
            return true;
        }
        if (is_string($value)) {
            return '' === trim($value);
        }
        if (is_array($value)) {
            return 0 === count($value);
        }
        return false;
    }

    /** @param mixed $v */
    private static function toBool($v): bool
    {
        if (is_string($v)) {
            return !in_array(strtolower(trim($v)), ['', '0', 'false', 'no', 'off'], true);
        }
        return (bool) $v;
    }

    /** @param mixed $v */
    private static function toInt($v): int
    {
        return is_numeric($v) ? (int) $v : 0;
    }

    /** @param mixed $v */
    private static function toFloat($v): float
    {
        return is_numeric($v) ? (float) $v : 0.0;
    }

    /** @param mixed $v */
    private static function toNullableFloat($v): ?float
    {
        if (null === $v || '' === $v || !is_numeric($v)) {
            return null;
        }
        return (float) $v;
    }

    /** @param mixed $v */
    private static function toStr($v): string
    {
        return is_scalar($v) ? trim((string) $v) : '';
    }

    /**
     * @param  mixed $v
     * @return string|null|false  ISO date, null when blank, false when malformed
     */
    private static function toNullableDate($v)
    {
        if (null === $v) {
            return null;
        }
        if (!is_scalar($v)) {
            return false;
        }
        $s = trim((string) $v);
        if ('' === $s) {
            return null;
        }
        if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $s, $m)) {
            return false;
        }
        if (!checkdate((int) $m[2], (int) $m[3], (int) $m[1])) {
            return false;
        }
        return $s;
    }

    /**
     * Whole floats become ints so JSON round-trips stay tidy.
     *
     * @return int|float
     */
    private static function tidyNumber(float $n)
    {
        return ($n === floor($n) && abs($n) < PHP_INT_MAX) ? (int) $n : $n;
    }
}
