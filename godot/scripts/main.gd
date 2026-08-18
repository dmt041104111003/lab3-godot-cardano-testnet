extends Control
## LAB3 Godot × Cardano Testnet
##
## A Godot 4 application that:
##   1. Reads LIVE Cardano testnet (Preprod) data from public APIs.
##   2. Lets the player complete a quest.
##   3. Submits a REAL testnet transaction (metadata under label 674) through the
##      signing bridge (backend/) — Godot initiates the flow, the bridge signs
##      with a funded testnet wallet and submits on-chain.
##   4. Polls the chain until the transaction is confirmed and opens the explorer.
##
## All data is REAL and read live from the Cardano Preprod network — there is no
## simulated or offline path in this app.
##
## Read source is chosen automatically:
##   - Desktop build -> Koios public API (https://preprod.koios.rest/api/v1).
##   - Web (browser) build -> the hosted bridge
##     (https://lab3-godot-cardano-bridge.vercel.app), which proxies the same
##     live reads with CORS enabled.

# ---------------------------------------------------------------------------
# Configuration (override via OS environment variables where noted)
# ---------------------------------------------------------------------------
const BRIDGE_URL_LOCAL := "http://127.0.0.1:8787"  # desktop/local dev
const BRIDGE_URL_HOSTED := "https://lab3-godot-cardano-bridge.vercel.app"  # web build
const KOIOS_URL_DEFAULT := "https://preprod.koios.rest/api/v1"
const NETWORK_DEFAULT := "preprod"
const EXPLORER_DEFAULT := "https://preprod.cardanoscan.io/transaction"
const QUEST_ID_DEFAULT := "quest_001"

const POLL_INTERVAL_SECONDS := 3.0
const MAX_POLLS := 20

const COLOR_TITLE := Color("#22c1a6")
const COLOR_OK := Color("#4ade80")
const COLOR_WARN := Color("#fbbf24")
const COLOR_ERR := Color("#f87171")
const COLOR_INFO := Color("#a5b4fc")

var bridge_url: String
var koios_url: String
var network_name: String
var explorer_base: String
var quest_id: String
var read_mode := "koios"  # "koios" (desktop) | "bridge" (web)

var quest_completed := false
var tx_hash := ""
var poll_count := 0
var polling := false
var submitting := false
var minting := false

var http_tip: HTTPRequest
var http_addr: HTTPRequest
var http_submit: HTTPRequest
var http_mint: HTTPRequest
var http_tx: HTTPRequest
var poll_timer: Timer

var ui := {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_load_config()
	_build_ui()
	_log("LAB3 Godot × Cardano Testnet — live build", COLOR_INFO)
	_log("Network: %s | reads via %s" % [network_name, read_mode], COLOR_INFO)
	_log("Bridge: %s" % bridge_url, COLOR_INFO)
	_refresh_data()

func _load_config() -> void:
	var on_web := OS.has_feature("web")
	bridge_url = _env_or("LAB3_BRIDGE_URL", BRIDGE_URL_HOSTED if on_web else BRIDGE_URL_LOCAL)
	koios_url = _env_or("LAB3_KOIOS_URL", KOIOS_URL_DEFAULT)
	network_name = _env_or("LAB3_NETWORK", NETWORK_DEFAULT)
	explorer_base = _env_or("LAB3_EXPLORER", EXPLORER_DEFAULT)
	quest_id = _env_or("LAB3_QUEST_ID", QUEST_ID_DEFAULT)
	read_mode = "bridge" if on_web else "koios"

func _env_or(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback

func _exit_tree() -> void:
	if poll_timer:
		poll_timer.stop()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 24)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	var title := _label("LAB3 Godot × Cardano Testnet", 26, COLOR_TITLE)
	vbox.add_child(title)

	var subtitle := _label("Live Cardano Preprod data + real on-chain transactions", 13, Color("#94a3b8"))
	vbox.add_child(subtitle)

	vbox.add_child(_hr())

	# ---- About / description ----
	vbox.add_child(_section("ABOUT"))
	var about := RichTextLabel.new()
	about.bbcode_enabled = true
	about.fit_content = true
	about.custom_minimum_size.y = 78
	about.append_text(
		"[color=#cbd5e1]This is a functional Godot 4 application interacting with the " +
		"[b][color=#4ade80]Cardano Preprod testnet[/color][/b].\n" +
		"It retrieves live on-chain data, completes a gameplay quest, submits a [b]real[/b] " +
		"testnet transaction carrying metadata (label 674), and verifies confirmation on-chain.\n" +
		"All values are fetched live — nothing is simulated.[/color]"
	)
	vbox.add_child(about)

	# ---- Architecture ----
	vbox.add_child(_section("ARCHITECTURE"))
	var arch := RichTextLabel.new()
	arch.bbcode_enabled = true
	arch.fit_content = true
	arch.custom_minimum_size.y = 96
	arch.append_text(
		"[color=#94a3b8]Godot (browser)[/color] [color=#22c1a6]⟶ Blockfrost/bridge[/color] [color=#94a3b8]⟶ Cardano Preprod\n" +
		"[color=#94a3b8]  reads   tip · balance · tx status\n" +
		"[color=#94a3b8]Godot[/color] [color=#22c1a6]⟶ bridge (Node + Mesh SDK)[/color] [color=#94a3b8]⟶ build · sign · submit[/color]\n" +
		"[color=#94a3b8]Desktop reads Koios · Web reads hosted bridge\n" +
		"[color=#94a3b8]Browser: https://lab3-godot-cardano-bridge.vercel.app[/color]"
	)
	vbox.add_child(arch)

	vbox.add_child(_hr())

	# ---- Player profile ----
	vbox.add_child(_section("PLAYER PROFILE"))

	var name_row := _row()
	var name_label := _label("Player name:", 14)
	name_label.custom_minimum_size.x = 150
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = "Player One"
	name_edit.custom_minimum_size.x = 300
	name_row.add_child(name_edit)
	vbox.add_child(name_row)

	var addr_row := _row()
	var addr_label := _label("Wallet address:", 14)
	addr_label.custom_minimum_size.x = 150
	addr_row.add_child(addr_label)
	var addr_edit := LineEdit.new()
	addr_edit.placeholder_text = "addr_test1... (paste a preprod/preview address)"
	addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_row.add_child(addr_edit)
	vbox.add_child(addr_row)
	ui.addr_edit = addr_edit

	# ---- Cardano network status ----
	vbox.add_child(_section("CARDANO NETWORK STATUS"))
	var net_row := _row()
	var net_label := _label("Network:", 14)
	net_label.custom_minimum_size.x = 150
	net_row.add_child(net_label)
	ui.network = _label(network_name, 14)
	net_row.add_child(ui.network)
	vbox.add_child(net_row)

	var bal_row := _row()
	var bal_label := _label("Current balance:", 14)
	bal_label.custom_minimum_size.x = 150
	bal_row.add_child(bal_label)
	ui.balance = _label("-- tADA", 14, COLOR_INFO)
	bal_row.add_child(ui.balance)
	vbox.add_child(bal_row)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Cardano Data"
	refresh_btn.pressed.connect(_refresh_data)
	ui.refresh_btn = refresh_btn
	vbox.add_child(refresh_btn)

	vbox.add_child(_hr())

	# ---- Quest ----
	vbox.add_child(_section("QUEST"))
	var quest_row := _row()
	var quest_btn := Button.new()
	quest_btn.text = "Complete Quest  (%s)" % quest_id
	quest_btn.pressed.connect(_on_quest_pressed)
	ui.quest_btn = quest_btn
	quest_row.add_child(quest_btn)
	ui.quest_status = _label("Not started", 14, COLOR_WARN)
	quest_row.add_child(ui.quest_status)
	vbox.add_child(quest_row)

	# ---- Proof on Cardano ----
	vbox.add_child(_section("PROOF ON CARDANO"))
	var proof_row := _row()
	var submit_btn := Button.new()
	submit_btn.text = "Submit Testnet Proof"
	submit_btn.disabled = true
	submit_btn.pressed.connect(_on_submit_pressed)
	ui.submit_btn = submit_btn
	proof_row.add_child(submit_btn)
	ui.submit_status = _label("Complete a quest first", 14, COLOR_WARN)
	proof_row.add_child(ui.submit_status)
	vbox.add_child(proof_row)

	ui.tx_hash_label = _label("Transaction hash: —", 14, COLOR_INFO)
	vbox.add_child(ui.tx_hash_label)

	ui.tx_conf_label = _label("Confirmation: —", 14, COLOR_INFO)
	vbox.add_child(ui.tx_conf_label)

	var explorer_btn := Button.new()
	explorer_btn.text = "Open Explorer"
	explorer_btn.disabled = true
	explorer_btn.pressed.connect(_on_explorer_pressed)
	ui.explorer_btn = explorer_btn
	vbox.add_child(explorer_btn)

	vbox.add_child(_hr())

	# ---- CIP-68 achievement NFT ----
	vbox.add_child(_section("ACHIEVEMENT NFT (CIP-68)"))
	var nft_row := _row()
	var nft_btn := Button.new()
	nft_btn.text = "Mint Achievement NFT"
	nft_btn.disabled = true
	nft_btn.pressed.connect(_on_mint_pressed)
	ui.nft_btn = nft_btn
	nft_row.add_child(nft_btn)
	ui.nft_status = _label("Complete a quest first", 14, COLOR_WARN)
	nft_row.add_child(ui.nft_status)
	vbox.add_child(nft_row)

	ui.nft_info = _label("NFT: —", 13, COLOR_INFO)
	vbox.add_child(ui.nft_info)

	vbox.add_child(_hr())

	# ---- Log console ----
	vbox.add_child(_section("LOG"))
	ui.log = RichTextLabel.new()
	ui.log.bbcode_enabled = true
	ui.log.scroll_active = true
	ui.log.custom_minimum_size.y = 130
	ui.log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(ui.log)

	# ---- HTTP plumbing ----
	http_tip = HTTPRequest.new()
	http_addr = HTTPRequest.new()
	http_submit = HTTPRequest.new()
	http_mint = HTTPRequest.new()
	http_tx = HTTPRequest.new()
	for h in [http_tip, http_addr, http_submit, http_mint, http_tx]:
		add_child(h)
	http_tip.request_completed.connect(_on_tip_done)
	http_addr.request_completed.connect(_on_addr_done)
	http_submit.request_completed.connect(_on_submit_done)
	http_mint.request_completed.connect(_on_mint_done)
	http_tx.request_completed.connect(_on_tx_done)

	poll_timer = Timer.new()
	poll_timer.wait_time = POLL_INTERVAL_SECONDS
	poll_timer.one_shot = true
	poll_timer.timeout.connect(_poll_confirmation)
	add_child(poll_timer)

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _hr() -> HSeparator:
	return HSeparator.new()

func _section(text: String) -> Label:
	return _label("■ " + text, 16, COLOR_TITLE)

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	return r

func _log(text: String, color: Color) -> void:
	ui.log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])

func _set_ui_status(key: String, text: String, color: Color) -> void:
	ui[key].text = text
	ui[key].add_theme_color_override("font_color", color)

# ---------------------------------------------------------------------------
# Live Cardano reads (real data, no simulated path)
# ---------------------------------------------------------------------------
func _request_tip() -> void:
	if read_mode == "bridge":
		http_tip.request(bridge_url + "/api/tip", [], HTTPClient.METHOD_GET)
	else:
		http_tip.request(koios_url + "/tip", [], HTTPClient.METHOD_GET)

func _request_address(addr: String) -> void:
	var payload := JSON.stringify({"_addresses": [addr]})
	var headers := ["Content-Type: application/json"]
	if read_mode == "bridge":
		http_addr.request(bridge_url + "/api/address_info", headers, HTTPClient.METHOD_POST, payload)
	else:
		http_addr.request(koios_url + "/address_info", headers, HTTPClient.METHOD_POST, payload)

func _request_tx_status() -> void:
	var payload := JSON.stringify({"_tx_hashes": [tx_hash]})
	var headers := ["Content-Type: application/json"]
	if read_mode == "bridge":
		http_tx.request(bridge_url + "/api/tx_info", headers, HTTPClient.METHOD_POST, payload)
	else:
		http_tx.request(koios_url + "/tx_info", headers, HTTPClient.METHOD_POST, payload)

func _refresh_data() -> void:
	ui.refresh_btn.disabled = true
	_set_ui_status("network", "checking…", COLOR_WARN)
	_request_tip()

func _address() -> String:
	return ui.addr_edit.text.strip_edges()

func _on_tip_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_log("Tip request failed (HTTP %d, result %d)" % [response_code, result], COLOR_ERR)
		_set_ui_status("network", "unreachable", COLOR_ERR)
		ui.refresh_btn.disabled = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var tip_height := 0
	if data is Array and data.size() > 0:
		tip_height = int(data[0].get("block_height", 0))
	elif data is Dictionary:
		tip_height = int(data.get("height", 0))
	if tip_height > 0:
		_set_ui_status("network", "%s  (tip height %d)" % [network_name, tip_height], COLOR_OK)
		_log("Chain reachable — tip height %d" % tip_height, COLOR_OK)
	else:
		_set_ui_status("network", "unexpected response", COLOR_ERR)
	_refresh_balance()

func _refresh_balance() -> void:
	var addr := _address()
	if addr == "":
		_set_ui_status("balance", "no address entered", COLOR_WARN)
		ui.refresh_btn.disabled = false
		return
	_request_address(addr)

func _on_addr_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_log("address lookup failed (HTTP %d, result %d)" % [response_code, result], COLOR_ERR)
		_set_ui_status("balance", "query failed", COLOR_ERR)
		ui.refresh_btn.disabled = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var balance := 0
	if data is Array and data.size() > 0:
		balance = int(data[0].get("balance", 0))
	elif data is Dictionary:
		for amt in data.get("amount", []):
			if amt.get("unit", "") == "lovelace":
				balance = int(amt.get("quantity", 0))
				break
	_on_addr_data(balance)

func _on_addr_data(balance: int) -> void:
	if balance > 0:
		ui.balance.text = "%.6f tADA  (%d lovelace)" % [balance / 1000000.0, balance]
		ui.balance.add_theme_color_override("font_color", COLOR_OK)
		_log("Address balance: %.6f tADA" % (balance / 1000000.0), COLOR_OK)
	else:
		_set_ui_status("balance", "0 tADA (no UTxOs found)", COLOR_WARN)
		_log("No UTxOs found for this address.", COLOR_WARN)
	ui.refresh_btn.disabled = false

# ---------------------------------------------------------------------------
# Quest + proof submission
# ---------------------------------------------------------------------------
func _on_quest_pressed() -> void:
	quest_completed = true
	_set_ui_status("quest_status", "Completed ✓", COLOR_OK)
	_log("Quest '%s' completed." % quest_id, COLOR_OK)
	ui.submit_btn.disabled = false
	ui.nft_btn.disabled = false
	_set_ui_status("submit_status", "Ready to submit", COLOR_INFO)
	_set_ui_status("nft_status", "Ready to mint", COLOR_INFO)

func _on_submit_pressed() -> void:
	if submitting:
		return
	var addr := _address()
	if addr != "" and not addr.begins_with("addr_test"):
		_log("Address does not look like a testnet address (addr_test1...).", COLOR_WARN)
	submitting = true
	ui.submit_btn.disabled = true
	_set_ui_status("submit_status", "submitting…", COLOR_WARN)
	_log("Submitting testnet proof to bridge: %s" % bridge_url, COLOR_INFO)
	var payload := JSON.stringify({
		"questId": quest_id,
		"playerAddress": addr,
	})
	var headers := ["Content-Type: application/json"]
	http_submit.request(bridge_url + "/api/quest/complete", headers, HTTPClient.METHOD_POST, payload)

func _on_submit_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	submitting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Bridge unreachable at %s." % bridge_url, COLOR_ERR)
		_set_ui_status("submit_status", "bridge unreachable", COLOR_ERR)
		ui.submit_btn.disabled = false
		return
	if response_code != 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		var msg := "HTTP %d" % response_code if data == null else str(data.get("error", "HTTP %d" % response_code))
		_log("Bridge returned: %s" % msg, COLOR_ERR)
		_set_ui_status("submit_status", msg, COLOR_ERR)
		ui.submit_btn.disabled = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	_on_submit_result(data)

func _on_submit_result(res) -> void:
	if res == null or not res.get("ok", false):
		var msg := "submit failed" if res == null else str(res.get("error", "unknown error"))
		_log("Bridge returned: %s" % msg, COLOR_ERR)
		_set_ui_status("submit_status", msg, COLOR_ERR)
		ui.submit_btn.disabled = false
		return
	tx_hash = res.get("txHash", "")
	_log("Transaction submitted! Hash: %s" % tx_hash, COLOR_OK)
	ui.tx_hash_label.text = "Transaction hash: " + tx_hash
	ui.tx_hash_label.add_theme_color_override("font_color", COLOR_OK)
	ui.explorer_btn.disabled = false
	_set_ui_status("submit_status", "submitted — awaiting confirmation", COLOR_WARN)
	poll_count = 0
	polling = true
	poll_timer.start(POLL_INTERVAL_SECONDS)

# ---------------------------------------------------------------------------
# CIP-68 achievement NFT mint
# ---------------------------------------------------------------------------
func _on_mint_pressed() -> void:
	if submitting or minting:
		return
	minting = true
	ui.nft_btn.disabled = true
	_set_ui_status("nft_status", "minting…", COLOR_WARN)
	_log("Minting CIP-68 achievement NFT via bridge…", COLOR_INFO)
	var payload := JSON.stringify({
		"questId": quest_id,
		"playerAddress": _address(),
	})
	var headers := ["Content-Type: application/json"]
	http_mint.request(bridge_url + "/api/quest/complete-nft", headers, HTTPClient.METHOD_POST, payload)

func _on_mint_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	minting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Bridge unreachable at %s." % bridge_url, COLOR_ERR)
		_set_ui_status("nft_status", "bridge unreachable", COLOR_ERR)
		ui.nft_btn.disabled = false
		return
	if response_code != 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		var msg := "HTTP %d" % response_code if data == null else str(data.get("error", "HTTP %d" % response_code))
		_log("Bridge returned: %s" % msg, COLOR_ERR)
		_set_ui_status("nft_status", msg, COLOR_ERR)
		ui.nft_btn.disabled = false
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or not data.get("ok", false):
		_set_ui_status("nft_status", "mint failed", COLOR_ERR)
		ui.nft_btn.disabled = false
		return
	var mint_tx := str(data.get("txHash", ""))
	var policy := str(data.get("policyId", ""))
	var asset := str(data.get("assetName", ""))
	_log("CIP-68 NFT minted! Tx: %s" % mint_tx, COLOR_OK)
	_log("Policy: %s" % policy, COLOR_INFO)
	ui.nft_info.text = "NFT: %s.%s  (policy %s)" % [policy.substr(0, 12) + "…", asset, policy.substr(0, 12) + "…"]
	ui.nft_info.add_theme_color_override("font_color", COLOR_OK)
	_set_ui_status("nft_status", "minted ✓", COLOR_OK)
	tx_hash = mint_tx
	ui.tx_hash_label.text = "Transaction hash: " + mint_tx
	ui.tx_hash_label.add_theme_color_override("font_color", COLOR_OK)
	ui.explorer_btn.disabled = false
	_set_ui_status("submit_status", "submitted — awaiting confirmation", COLOR_WARN)
	poll_count = 0
	polling = true
	poll_timer.start(POLL_INTERVAL_SECONDS)

# ---------------------------------------------------------------------------
# Confirmation polling (real on-chain reads)
# ---------------------------------------------------------------------------
func _poll_confirmation() -> void:
	if not polling:
		return
	poll_count += 1
	if poll_count > MAX_POLLS:
		polling = false
		_log("Timed out waiting for confirmation after %d polls." % MAX_POLLS, COLOR_ERR)
		_set_ui_status("submit_status", "confirmation timeout", COLOR_ERR)
		return
	_request_tx_status()

func _on_tx_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Status request failed — will retry.", COLOR_WARN)
		_set_ui_status("submit_status", "pending (%d/%d) — retrying…" % [poll_count, MAX_POLLS], COLOR_WARN)
		poll_timer.start(POLL_INTERVAL_SECONDS)
		return
	if response_code != 200:
		_log("Status request failed (HTTP %d) — will retry." % response_code, COLOR_WARN)
		_set_ui_status("submit_status", "pending (%d/%d) — retrying…" % [poll_count, MAX_POLLS], COLOR_WARN)
		poll_timer.start(POLL_INTERVAL_SECONDS)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var block_height := -1
	if data is Array and data.size() > 0:
		block_height = int(data[0].get("block_height", -1))
	elif data is Dictionary:
		block_height = int(data.get("block_height", -1))
	_handle_tx_info(block_height)

func _handle_tx_info(block_height: int) -> void:
	if block_height > 0:
		polling = false
		_log("CONFIRMED on-chain (block height %d)" % block_height, COLOR_OK)
		ui.tx_conf_label.text = "Confirmation: CONFIRMED (block height %d)" % block_height
		ui.tx_conf_label.add_theme_color_override("font_color", COLOR_OK)
		_set_ui_status("submit_status", "confirmed ✓", COLOR_OK)
	else:
		_set_ui_status("submit_status", "pending (%d/%d)…" % [poll_count, MAX_POLLS], COLOR_WARN)
		poll_timer.start(POLL_INTERVAL_SECONDS)

func _on_explorer_pressed() -> void:
	if tx_hash == "":
		return
	var url := "%s/%s" % [explorer_base, tx_hash]
	_log("Opening explorer: %s" % url, COLOR_INFO)
	OS.shell_open(url)