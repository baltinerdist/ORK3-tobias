<?php

declare(strict_types=1);

/**
 * Ephemeral DB fixtures for Court Planner Thread 0 tests.
 * Every row created here is tracked and removed by cleanup().
 */
final class CourtFixture
{
    private const MARKER = 'T0CRT';

    /** @var list<int> */
    private array $mundaneIds = [];
    /** @var list<int> */
    private array $courtIds = [];
    /** @var list<int> */
    private array $awardIds = [];
    /** @var list<int> */
    private array $officerIds = [];

    public function __construct(private readonly PDO $pdo)
    {
    }

    public static function create(): self
    {
        $pdo = new PDO(
            sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8', DB_HOSTNAME, DB_PORT, DB_DATABASE),
            DB_USERNAME,
            DB_PASSWORD,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION],
        );

        return new self($pdo);
    }

    public function pdo(): PDO
    {
        return $this->pdo;
    }

    public function firstKingdomId(): int
    {
        return (int) $this->pdo->query(
            'SELECT kingdom_id FROM ' . DB_PREFIX . "kingdom WHERE active = 'Active' ORDER BY kingdom_id ASC LIMIT 1"
        )->fetchColumn();
    }

    public function firstParkId(int $kingdomId): int
    {
        return (int) $this->pdo->query(
            'SELECT park_id FROM ' . DB_PREFIX . 'park WHERE kingdom_id = ' . $kingdomId . ' ORDER BY park_id ASC LIMIT 1'
        )->fetchColumn();
    }

    /**
     * Clone an existing mundane row, then override what we care about.
     * ork_mundane has ~15 NOT NULL columns with no defaults (given_name,
     * surname, username, email, token, ...), so a bare three-column INSERT
     * throws. Mirrors KingdomProfileFixture's INSERT ... SELECT approach,
     * building the column list dynamically so it survives schema drift.
     */
    public function createPlayer(string $tag, int $kingdomId, int $parkId = 0): array
    {
        $template = (int) $this->pdo->query(
            'SELECT mundane_id FROM ' . DB_PREFIX . 'mundane ORDER BY mundane_id ASC LIMIT 1'
        )->fetchColumn();

        if ($template <= 0) {
            throw new RuntimeException('No template mundane row to clone.');
        }

        $cols = $this->pdo->query('SHOW COLUMNS FROM ' . DB_PREFIX . 'mundane')
            ->fetchAll(PDO::FETCH_COLUMN, 0);
        $cols = array_values(array_filter($cols, static fn ($c) => $c !== 'mundane_id'));
        $list = '`' . implode('`, `', $cols) . '`';

        $st = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'mundane (' . $list . ')
             SELECT ' . $list . ' FROM ' . DB_PREFIX . 'mundane WHERE mundane_id = ?'
        );
        $st->execute([$template]);
        $id = (int) $this->pdo->lastInsertId();
        $this->mundaneIds[] = $id;

        $persona = self::MARKER . '-' . $tag . '-' . bin2hex(random_bytes(3));
        $up = $this->pdo->prepare(
            'UPDATE ' . DB_PREFIX . 'mundane
                SET persona = ?, username = ?, kingdom_id = ?, park_id = ?
              WHERE mundane_id = ?'
        );
        $up->execute([$persona, $persona, $kingdomId, $parkId, $id]);

        return ['mundane_id' => $id, 'persona' => $persona];
    }

    public function createCourt(array $overrides = []): int
    {
        $row = array_merge([
            'kingdom_id'   => 0,
            'park_id'      => 0,
            'name'         => self::MARKER . '-court',
            'court_date'   => null,
            'status'       => 'published',
            'mode'         => 'plan',
            'created_by'   => 0,
        ], $overrides);

        $st = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'court (kingdom_id, park_id, name, court_date, status, mode, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?)'
        );
        $st->execute([
            $row['kingdom_id'], $row['park_id'], $row['name'], $row['court_date'],
            $row['status'], $row['mode'], $row['created_by'],
        ]);
        $id = (int) $this->pdo->lastInsertId();
        $this->courtIds[] = $id;

        return $id;
    }

    public function createAward(int $courtId, int $mundaneId, array $overrides = []): int
    {
        $row = array_merge([
            'kingdomaward_id' => 1,
            'rank'            => 0,
            'status'          => 'planned',
            'sort_order'      => 0,
            'notes'           => '',
            'public_comment'  => '',
            'pass_to_local'   => 0,
            'scroll_maker_id' => null,
            'regalia_maker_id' => null,
        ], $overrides);

        $st = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'court_award
             (court_id, mundane_id, kingdomaward_id, rank, status, sort_order, notes, public_comment,
              pass_to_local, scroll_maker_id, regalia_maker_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $st->execute([
            $courtId, $mundaneId, $row['kingdomaward_id'], $row['rank'], $row['status'],
            $row['sort_order'], $row['notes'], $row['public_comment'], $row['pass_to_local'],
            $row['scroll_maker_id'], $row['regalia_maker_id'],
        ]);
        $id = (int) $this->pdo->lastInsertId();
        $this->awardIds[] = $id;

        return $id;
    }

    public function insertOfficer(int $mundaneId, int $kingdomId, int $parkId, string $role): void
    {
        // system and authorization_id are NOT NULL without defaults — match
        // ReportsFixture and pass 0 for both.
        $st = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'officer
             (kingdom_id, park_id, mundane_id, role, system, authorization_id)
             VALUES (?, ?, ?, ?, 0, 0)'
        );
        $st->execute([$kingdomId, $parkId, $mundaneId, $role]);
        $this->officerIds[] = (int) $this->pdo->lastInsertId();
    }

    public function fetchCourt(int $courtId): array
    {
        $st = $this->pdo->prepare('SELECT * FROM ' . DB_PREFIX . 'court WHERE court_id = ?');
        $st->execute([$courtId]);

        return $st->fetch(PDO::FETCH_ASSOC) ?: [];
    }

    public function fetchAward(int $courtAwardId): array
    {
        $st = $this->pdo->prepare('SELECT * FROM ' . DB_PREFIX . 'court_award WHERE court_award_id = ?');
        $st->execute([$courtAwardId]);

        return $st->fetch(PDO::FETCH_ASSOC) ?: [];
    }

    public function cleanup(): void
    {
        $this->deleteIn('court_award', 'court_award_id', $this->awardIds);
        $this->deleteIn('court', 'court_id', $this->courtIds);
        $this->deleteIn('officer', 'officer_id', $this->officerIds);
        $this->deleteIn('mundane', 'mundane_id', $this->mundaneIds);
        $this->awardIds = $this->courtIds = $this->officerIds = $this->mundaneIds = [];
    }

    private function deleteIn(string $table, string $pk, array $ids): void
    {
        if (!$ids) {
            return;
        }
        $this->pdo->exec(
            'DELETE FROM ' . DB_PREFIX . $table . ' WHERE ' . $pk . ' IN (' . implode(',', array_map('intval', $ids)) . ')'
        );
    }
}
