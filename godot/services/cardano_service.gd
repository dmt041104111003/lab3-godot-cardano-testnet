extends Node
## Cardano integration service (autoload).
## Talks to the hosted/local bridge. Godot never holds signing keys.

var bridge_url := "http://127.0.0.1:8787"
var network := "preprod"
var explorer_base := "https://preprod.cardanoscan.io/transaction"

func _ready() -> void:
	if OS.has_feature("web"):
		bridge_url = "https://lab3-godot-cardano-bridge.vercel.app"
	# Allow an OS-level override for desktop/local testing.
	var v := OS.get_environment("LAB3_BRIDGE_URL")
	if v != "":
		bridge_url = v

func explorer_url(tx_hash: String) -> String:
	return "%s/%s" % [explorer_base, tx_hash]

func _request(method: int, path: String, body: Dictionary, cb: Callable) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 25.0
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, b: PackedByteArray) -> void:
		var data = null
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			data = JSON.parse_string(b.get_string_from_utf8())
		cb.call(result, code, data)
	)
	var payload := JSON.stringify(body) if body.size() > 0 else ""
	var err := req.request(bridge_url + path, ["Content-Type: application/json"], method, payload)
	if err != OK:
		cb.call(HTTPRequest.RESULT_CANT_CONNECT, 0, null)

func post(path: String, body: Dictionary, cb: Callable) -> void:
	_request(HTTPClient.METHOD_POST, path, body, cb)

func get_json(path: String, cb: Callable) -> void:
	_request(HTTPClient.METHOD_GET, path, {}, cb)

# ---- typed helpers ----------------------------------------------------------
func complete_quest(quest_id: String, player_address: String, cb: Callable) -> void:
	post("/api/quest/complete", { "questId": quest_id, "playerAddress": player_address }, cb)

func attest_prepare(payload: Dictionary, cb: Callable) -> void:
	post("/api/attestation/prepare", payload, cb)

func attest_create(payload: Dictionary, cb: Callable) -> void:
	post("/api/attestation/create", payload, cb)

func attest_verify(payload: Dictionary, cb: Callable) -> void:
	post("/api/attestation/verify", payload, cb)

func tx_status(tx_hash: String, cb: Callable) -> void:
	get_json("/api/tx/" + tx_hash, cb)