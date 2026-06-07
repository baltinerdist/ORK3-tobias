<?php

class Controller_InventoryAjax extends Controller
{
    public function handle($p = null)
    {
        header('Content-Type: application/json');
        $parts      = explode('/', $p ?? '');
        $owner_type = ($parts[0] ?? '') === 'park' ? 'park' : 'kingdom';
        $owner_id   = (int)preg_replace('/[^0-9]/', '', $parts[1] ?? '');
        $action     = $parts[2] ?? '';

        if (!isset($this->session->user_id)) {
            echo json_encode(['status' => 5, 'error' => 'Not logged in']);
            exit;
        }
        if (!valid_id($owner_id)) {
            echo json_encode(['status' => 4, 'error' => 'Invalid org']);
            exit;
        }

        $this->load_model('Inventory');
        $tok = $this->session->token;

        switch ($action) {
            case 'items':
                return $this->out($this->Inventory->get_items($tok, $owner_type, $owner_id, $this->itemFilters()));
            case 'summary':
                return $this->out($this->Inventory->get_summary($tok, $owner_type, $owner_id, [
                    'category' => $_GET['category'] ?? null, 'condition' => $_GET['condition'] ?? null,
                    'q' => $_GET['q'] ?? null,
                ]));
            case 'rev':
                return $this->out($this->Inventory->get_revision($tok, $owner_type, $owner_id));
            case 'getitem':
                return $this->out($this->Inventory->get_item($tok, $owner_type, $owner_id, (int)($_GET['id'] ?? 0)));
            case 'additem':
            case 'edititem':
                $data = $this->itemData($owner_type, $owner_id);
                if ($action === 'edititem') {
                    $data['id'] = (int)($_POST['id'] ?? 0);
                }
                return $this->out($this->Inventory->save_item($tok, $data));
            case 'removeitem':
                return $this->out($this->Inventory->remove_item(
                    $tok,
                    $owner_type,
                    $owner_id,
                    (int)($_POST['id'] ?? 0),
                    $_POST['removal_reason'] ?? '',
                    $_POST['removal_note'] ?? ''
                ));
            case 'restoreitem':
                return $this->out($this->Inventory->restore_item($tok, $owner_type, $owner_id, (int)($_POST['id'] ?? 0)));
            case 'deleteitem':
                return $this->out($this->Inventory->delete_item($tok, $owner_type, $owner_id, (int)($_POST['id'] ?? 0)));
            case 'export':
                return $this->exportCsv($tok, $owner_type, $owner_id);
            default:
                echo json_encode(['status' => 4, 'error' => 'Unknown action']);
                exit;
        }
    }

    private function itemFilters()
    {
        return [
            'category' => $_GET['category'] ?? null, 'condition' => $_GET['condition'] ?? null,
            'q' => $_GET['q'] ?? null, 'status' => $_GET['status'] ?? 'active',
            'sort' => $_GET['sort'] ?? 'name', 'dir' => $_GET['dir'] ?? 'asc',
            'page' => $_GET['page'] ?? 1, 'per' => $_GET['per'] ?? 25,
        ];
    }

    private function itemData($owner_type, $owner_id)
    {
        return [
            'owner_type' => $owner_type, 'owner_id' => $owner_id,
            'name' => $_POST['name'] ?? '', 'category' => $_POST['category'] ?? '',
            'quantity' => $_POST['quantity'] ?? 1, 'condition' => $_POST['condition'] ?? 'good',
            'unit_value' => $_POST['unit_value'] ?? 0, 'location' => $_POST['location'] ?? '',
            'held_by' => $_POST['held_by'] ?? '', 'held_by_player_id' => $_POST['held_by_player_id'] ?? 0,
            'acquired_date' => $_POST['acquired_date'] ?? '', 'notes' => $_POST['notes'] ?? '',
        ];
    }

    /** Map a lib Service response to UI JSON {status,error,detail}. */
    private function out($res)
    {
        $status = isset($res['Status']) ? (int)$res['Status'] : 4;
        echo json_encode([
            'status' => $status,
            'error'  => $status === 0 ? null : ($res['Error'] ?? 'Error') . (isset($res['Detail']) && is_string($res['Detail']) ? ': ' . $res['Detail'] : ''),
            'detail' => $res['Detail'] ?? null,
        ]);
        exit;
    }

    private function exportCsv($tok, $owner_type, $owner_id)
    {
        $filters = $this->itemFilters();
        $filters['per'] = 100000;
        $filters['page'] = 1;
        $res = $this->Inventory->get_items($tok, $owner_type, $owner_id, $filters);
        if (($res['Status'] ?? 4) !== 0) {
            echo json_encode(['status' => $res['Status'] ?? 4, 'error' => 'Denied']);
            exit;
        }
        header('Content-Type: text/csv');
        header('Content-Disposition: attachment; filename="inventory_' . $owner_type . '_' . $owner_id . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Name', 'Category', 'Quantity', 'Condition', 'Unit Value', 'Total Value',
            'Location', 'Held By', 'Acquired', 'Notes', 'Status', 'Removal Reason', 'Removal Note']);
        foreach ($res['Detail']['Rows'] as $r) {
            fputcsv($out, [$r['Name'], $r['Category'], $r['Quantity'], $r['Condition'],
                number_format($r['UnitValue'], 2, '.', ''), number_format($r['TotalValue'], 2, '.', ''),
                $r['Location'], $r['HeldBy'], $r['AcquiredDate'], $r['Notes'],
                $r['RemovedAt'] ? 'Removed' : 'Active', $r['RemovalReason'], $r['RemovalNote']]);
        }
        fclose($out);
        exit;
    }
}
