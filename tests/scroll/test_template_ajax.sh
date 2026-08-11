#!/usr/bin/env bash
# Smoke test for ScrollTemplateAjax CRUD endpoints.
# Expects the dev app at http://localhost:19080/orkui/.
BASE='http://localhost:19080/orkui/index.php?Route=ScrollTemplateAjax'

echo "== list (expect valid JSON: {\"Status\":0,\"Templates\":[...]} or a login Status) =="
curl -s "$BASE/list&kingdom_id=1" | head -c 300; echo

echo "== save unauth (expect Status 5 — rejected) =="
curl -s -X POST "$BASE/save" -H 'Content-Type: application/json' \
	-d '{"name":"x","kingdom_id":1,"slots":[],"zones":[]}' | head -c 300; echo
