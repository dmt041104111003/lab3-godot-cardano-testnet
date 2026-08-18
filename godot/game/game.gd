extends Control
## LAB3 Godot x Cardano Game - main controller.
## Screens: menu, profile, play (platformer world), verify, achievements, settings.

const QUEST_NAMES := [
	"Quest 1: Collect 5 Coins",
	"Quest 2: Activate 2 Terminals",
	"Quest 3: Reach the Exit",
]
const QUEST_IDS := ["quest_1", "quest_2", "quest_3"]

const COLOR_TITLE := Color("#22c1a6")
const COLOR_OK := Color("#4ade80")
const COLOR_WARN := Color("#fbbf24")
const COLOR_ERR := Color("#f87171")
const COLOR_INFO := Color("#a5b4fc")

var screens := {}
var ui := {}
var world: Node2D
var current_quest := 0
var in_flow := false
var flow_quest := 0
var proof_tx_hash := ""
var attest_tx_hash := ""
var pending_attest_hash := ""
var poll_timer: Timer
var poll_hash := ""
var poll_phase := ""
var poll_count := 0

func _ready() -> void:
	_build_screens()
	_show_screen("menu")
	_apply_profile_to_ui()

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	return r

func _screen(name: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	add_child(c)
	screens[name] = c
	return c

func _show_screen(name: String) -> void:
	for k in screens.keys():
		screens[k].visible = (k == name)

func _set_label(d: Dictionary, key: String, text: String, color: Color) -> void:
	if d.has(key) and d[key] is Label:
		d[key].text = text
		d[key].add_theme_color_override("font_color", color)

# ---------------------------------------------------------------------------
# Screens
# ---------------------------------------------------------------------------
func _build_screens() -> void:
	_build_menu()
	_build_profile()
	_build_play()
	_build_verify()
	_build_achievements()
	_build_settings()

func _build_menu() -> void:
	var s := _screen("menu")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_top", 60)
	s.add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	v.add_child(_label("LAB3 Godot x Cardano Game", 34, COLOR_TITLE))
	v.add_child(_label("Run, jump, complete quests and earn verifiable Cardano achievements.", 16, Color("#94a3b8")))
	v.add_child(Label.new())
	ui.menu_player = _label("", 16, COLOR_INFO)
	v.add_child(ui.menu_player)
	v.add_child(_button("Play", func(): _start_run()))
	v.add_child(_button("Player Profile", func(): _show_screen("profile")))
	v.add_child(_button("Achievements", func(): _refresh_achievements(); _show_screen("achievements")))
	v.add_child(_button("Settings / About", func(): _show_screen("settings")))

func _build_profile() -> void:
	var s := _screen("profile")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 60)
	root.add_theme_constant_override("margin_top", 50)
	s.add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	v.add_child(_label("Player Profile", 28, COLOR_TITLE))
	var rn := _row()
	rn.add_child(_label("Name:", 16))
	ui.profile_name = LineEdit.new()
	ui.profile_name.custom_minimum_size.x = 300
	rn.add_child(ui.profile_name)
	v.add_child(rn)
	var ra := _row()
	ra.add_child(_label("Wallet address:", 16))
	ui.profile_addr = LineEdit.new()
	ui.profile_addr.placeholder_text = "addr_test1... (Cardano Preprod)"
	ui.profile_addr.custom_minimum_size.x = 380
	ra.add_child(ui.profile_addr)
	v.add_child(ra)
	ui.profile_stats = _label("", 15, COLOR_INFO)
	v.add_child(ui.profile_stats)
	var rb := _row()
	rb.add_child(_button("Save", func():
		profile.player_name = ui.profile_name.text.strip_edges()
		profile.address = ui.profile_addr.text.strip_edges()
		profile.save_profile()
		_apply_profile_to_ui()
		_cloud_save()
		_set_label(ui, "profile_msg", "Profile saved OK", COLOR_OK)
	))
	rb.add_child(_button("Login with Wallet (CIP-30)", func(): _login_wallet()))
	rb.add_child(_button("Back", func(): _show_screen("menu")))
	v.add_child(rb)
	ui.profile_msg = _label("", 14)
	v.add_child(ui.profile_msg)

func _build_play() -> void:
	var s := _screen("play")
	var top := MarginContainer.new()
	top.anchor_right = 1.0
	top.offset_top = 8
	top.offset_bottom = 40
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	s.add_child(top)
	var h := HBoxContainer.new()
	top.add_child(h)
	ui.play_quest = _label("", 17, COLOR_TITLE)
	h.add_child(ui.play_quest)
	ui.play_progress = _label("", 14, COLOR_INFO)
	h.add_child(ui.play_progress)
	h.add_child(Label.new())
	var back := _button("Exit to Menu", func(): _stop_run())
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(back)

func _build_verify() -> void:
	var s := _screen("verify")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 80)
	root.add_theme_constant_override("margin_top", 90)
	s.add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	v.add_child(_label("Milestone Complete!", 30, COLOR_OK))
	ui.verify_quest = _label("", 18)
	v.add_child(ui.verify_quest)
	ui.verify_xp = _label("", 16, COLOR_INFO)
	v.add_child(ui.verify_xp)
	v.add_child(HSeparator.new())
	v.add_child(_label("Cardano verification", 20, COLOR_TITLE))
	ui.verify_status = _label("", 15, COLOR_WARN)
	v.add_child(ui.verify_status)
	ui.verify_proof = _label("", 13, COLOR_INFO)
	v.add_child(ui.verify_proof)
	ui.verify_attest = _label("", 13, COLOR_INFO)
	v.add_child(ui.verify_attest)
	var row_btn := _row()
	var open_proof := _button("Open Proof Tx", func():
		if proof_tx_hash != "":
			OS.shell_open(cardano_service.explorer_url(proof_tx_hash))
	)
	open_proof.disabled = true
	ui.open_proof = open_proof
	row_btn.add_child(open_proof)
	var open_attest := _button("Open Attestation Tx", func():
		if attest_tx_hash != "":
			OS.shell_open(cardano_service.explorer_url(attest_tx_hash))
	)
	open_attest.disabled = true
	ui.open_attest = open_attest
	row_btn.add_child(open_attest)
	v.add_child(row_btn)
	ui.cip30_status = _label("", 13, COLOR_WARN)
	v.add_child(ui.cip30_status)
	var row2 := _row()
	var cip30_btn := _button("Connect Wallet (CIP-30)", func(): _connect_cip30())
	ui.cip30_btn = cip30_btn
	row2.add_child(cip30_btn)
	var retry := _button("Retry", func(): _start_cardano_flow(flow_quest))
	retry.disabled = true
	ui.retry_btn = retry
	row2.add_child(retry)
	v.add_child(row2)
	var cont := _button("Continue", func(): _continue_after_verify())
	ui.cont_btn = cont
	cont.disabled = true
	v.add_child(cont)

func _build_achievements() -> void:
	var s := _screen("achievements")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 60)
	root.add_theme_constant_override("margin_top", 50)
	s.add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.add_child(_label("Achievements", 28, COLOR_TITLE))
	ui.achievements_list = VBoxContainer.new()
	v.add_child(ui.achievements_list)
	v.add_child(_button("Back", func(): _show_screen("menu")))

func _build_settings() -> void:
	var s := _screen("settings")
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 60)
	root.add_theme_constant_override("margin_top", 50)
	s.add_child(root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	root.add_child(v)
	v.add_child(_label("Settings / About", 28, COLOR_TITLE))
	v.add_child(_label("Network: " + cardano_service.network, 16))
	v.add_child(_label("Bridge: " + cardano_service.bridge_url, 14, COLOR_INFO))
	v.add_child(_label("Godot platformer with Cardano Preprod integration. Gameplay stays off-chain; only quest milestones anchor on Cardano (label 674 + CIP-0170 attestation label 1701).", 14, Color("#94a3b8")))
	v.add_child(_button("Back", func(): _show_screen("menu")))

# ---------------------------------------------------------------------------
# Profile / cloud
# ---------------------------------------------------------------------------
func _apply_profile_to_ui() -> void:
	ui.profile_name.text = profile.player_name
	ui.profile_addr.text = profile.address
	_set_label(ui, "profile_stats", "Level %d  -  XP %d/%d  -  Coins %d  -  Terminals %d" % [profile.level, profile.xp, profile.level * 100, profile.fragments, profile.terminals], COLOR_INFO)
	var who := "Player" if profile.player_name == "" else profile.player_name
	ui.menu_player.text = "%s  -  Level %d  -  %d/%d XP" % [who, profile.level, profile.xp, profile.level * 100]

func _cloud_save() -> void:
	if profile.address == "":
		return
	var data := {
		"name": profile.player_name,
		"xp": profile.xp,
		"level": profile.level,
		"quests": profile.quests,
		"verified": profile.verified,
		"fragments": profile.fragments,
		"terminals": profile.terminals,
	}
	cardano_service.save_player(profile.address, data, func(_r: int, _c: int, _d): pass)

func _login_wallet() -> void:
	if not cip30.is_available():
		_set_label(ui, "profile_msg", "No CIP-30 wallet in this browser. Enter an address manually.", COLOR_WARN)
		return
	_set_label(ui, "profile_msg", "Connecting wallet...", COLOR_WARN)
	cip30.connect_wallet(_cb_login_wallet)

func _cb_login_wallet(data) -> void:
	if not cip30.apply_connect_result(data):
		_set_label(ui, "profile_msg", "Wallet connect failed", COLOR_ERR)
		return
	ui.profile_addr.text = cip30.address
	profile.address = cip30.address
	profile.save_profile()
	_load_cloud_profile()

func _load_cloud_profile() -> void:
	_set_label(ui, "profile_msg", "Loading cloud profile...", COLOR_WARN)
	cardano_service.load_player(profile.address, _cb_load_cloud)

func _cb_load_cloud(result: int, code: int, data) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and data is Dictionary and data.get("ok", false) and data.get("data") != null:
		var d = data.get("data")
		profile.player_name = str(d.get("name", profile.player_name))
		profile.xp = int(d.get("xp", profile.xp))
		profile.level = int(d.get("level", profile.level))
		var q = d.get("quests", {})
		if q is Dictionary:
			for k in profile.quests.keys():
				profile.quests[k] = bool(q.get(k, profile.quests[k]))
		var v = d.get("verified", {})
		if v is Dictionary:
			for k in profile.verified.keys():
				profile.verified[k] = bool(v.get(k, profile.verified[k]))
		profile.save_profile()
		_apply_profile_to_ui()
		_set_label(ui, "profile_msg", "Cloud profile loaded for " + profile.address.substr(0, 20) + "... OK", COLOR_OK)
	else:
		_set_label(ui, "profile_msg", "New player - no cloud profile yet. Save to create it.", COLOR_INFO)

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
func _start_run() -> void:
	quest_state.reset_run()
	current_quest = 0
	_in_play()
	_show_screen("play")

func _in_play() -> void:
	if world != null:
		world.queue_free()
	world = preload("res://game/world.gd").new()
	add_child(world)
	world.coins_collected.connect(_on_coins)
	world.terminals_activated.connect(_on_terminals)
	world.exit_reached.connect(_on_exit)
	world.player_damaged.connect(_on_player_damaged)
	_update_quest_hud()

func _stop_run() -> void:
	if world != null:
		world.queue_free()
		world = null
	_show_screen("menu")
	_apply_profile_to_ui()

func _update_quest_hud() -> void:
	ui.play_quest.text = QUEST_NAMES[current_quest]
	if world != null:
		ui.play_progress.text = "Coins %d/%d   Terminals %d/%d" % [8 - int(world.coins_left), 8, 2 - int(world.terminals_left), 2]

func _on_coins(n: int) -> void:
	var collected := 8 - n
	profile.fragments = maxi(profile.fragments, collected)
	if current_quest == 0 and collected >= 5:
		_complete_quest(0)
	else:
		_update_quest_hud()

func _on_terminals(n: int) -> void:
	var activated := 2 - n
	profile.terminals = maxi(profile.terminals, activated)
	if current_quest == 1 and activated >= 2:
		_complete_quest(1)
	else:
		_update_quest_hud()

func _on_exit() -> void:
	if current_quest == 2:
		_complete_quest(2)

func _on_player_damaged() -> void:
	world.reset_player()

func _complete_quest(index: int) -> void:
	quest_state.milestone_reached = true
	var id: String = QUEST_IDS[index]
	profile.add_xp(50 + index * 25)
	if index < 2:
		profile.complete_quest(id)
	profile.save_profile()
	_cloud_save()
	flow_quest = index
	ui.verify_quest.text = QUEST_NAMES[index]
	ui.verify_xp.text = "XP +%d  ->  Level %d" % [50 + index * 25, profile.level]
	ui.verify_status.text = "Preparing Cardano verification..."
	ui.verify_proof.text = ""
	ui.verify_attest.text = ""
	ui.open_proof.disabled = true
	ui.open_attest.disabled = true
	ui.retry_btn.disabled = true
	ui.cont_btn.disabled = true
	ui.cip30_status.text = ""
	_show_screen("verify")
	_start_cardano_flow(index)

# ---------------------------------------------------------------------------
# Cardano flow
# ---------------------------------------------------------------------------
func _start_cardano_flow(index: int) -> void:
	if profile.address == "":
		_set_label(ui, "verify_status", "No wallet address set. Add one in Player Profile to verify on Cardano.", COLOR_WARN)
		ui.cont_btn.disabled = false
		return
	in_flow = true
	flow_quest = index
	_set_label(ui, "verify_status", "Submitting milestone proof to Cardano Preprod...", COLOR_WARN)
	cardano_service.complete_quest(QUEST_IDS[index], profile.address, _cb_proof_submit)

func _cb_proof_submit(result: int, code: int, data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or data == null or not data.get("ok", false):
		var msg := "proof submission failed"
		if data is Dictionary:
			msg = str(data.get("error", msg))
		_set_label(ui, "verify_status", msg, COLOR_ERR)
		ui.retry_btn.disabled = false
		return
	proof_tx_hash = str(data.get("txHash", ""))
	ui.verify_proof.text = "Proof tx: " + proof_tx_hash
	_set_label(ui, "verify_status", "Waiting for on-chain confirmation...", COLOR_WARN)
	_start_poll(proof_tx_hash, "proof")

func _start_attestation() -> void:
	var payload := {
		"playerAddress": profile.address,
		"playerName": profile.player_name,
		"achievement": QUEST_IDS[flow_quest],
		"event": "quest_completed",
		"questId": QUEST_IDS[flow_quest],
		"tier": flow_quest + 1,
		"progression": "quest_progress",
	}
	_set_label(ui, "verify_status", "Creating on-chain achievement attestation...", COLOR_WARN)
	cardano_service.attest_prepare(payload, _cb_attest_prepare)

func _cb_attest_prepare(result: int, code: int, data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or data == null or not data.get("ok", false):
		var msg := "attestation prepare failed"
		if data is Dictionary:
			msg = str(data.get("error", msg))
		_set_label(ui, "verify_status", msg, COLOR_ERR)
		ui.retry_btn.disabled = false
		return
	pending_attest_hash = str(data.get("attestationHash", ""))
	if cip30.connected:
		_set_label(ui, "verify_status", "Waiting for your wallet signature (CIP-30)...", COLOR_WARN)
		cip30.sign(pending_attest_hash, _cb_cip30_signed)
	else:
		_create_attestation({})

func _cb_cip30_signed(sig_data) -> void:
	if not cip30.apply_sign_result(sig_data):
		_set_label(ui, "cip30_status", "Wallet signing failed", COLOR_ERR)
		ui.retry_btn.disabled = false
		return
	ui.cip30_status.text = "Signed by your wallet OK (CIP-30)"
	ui.cip30_status.add_theme_color_override("font_color", COLOR_OK)
	_create_attestation({ "playerSignature": cip30.signature, "playerKey": cip30.key, "playerAddressCip30": cip30.address })

func _create_attestation(extra: Dictionary) -> void:
	var payload := {
		"playerAddress": profile.address,
		"playerName": profile.player_name,
		"achievement": QUEST_IDS[flow_quest],
		"event": "quest_completed",
		"questId": QUEST_IDS[flow_quest],
		"tier": flow_quest + 1,
		"progression": "quest_progress",
	}
	for k in extra.keys():
		payload[k] = extra[k]
	cardano_service.attest_create(payload, _cb_attest_create)

func _cb_attest_create(result: int, code: int, data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or data == null or not data.get("ok", false):
		var msg := "attestation creation failed"
		if data is Dictionary:
			msg = str(data.get("error", msg))
		_set_label(ui, "verify_status", msg, COLOR_ERR)
		ui.retry_btn.disabled = false
		return
	attest_tx_hash = str(data.get("txHash", ""))
	ui.verify_attest.text = "Attestation tx: " + attest_tx_hash
	_set_label(ui, "verify_status", "Waiting for attestation confirmation...", COLOR_WARN)
	_start_poll(attest_tx_hash, "attest")

func _start_poll(hash: String, phase: String) -> void:
	poll_hash = hash
	poll_phase = phase
	poll_count = 0
	if poll_timer == null:
		poll_timer = Timer.new()
		poll_timer.wait_time = 3.0
		poll_timer.one_shot = true
		poll_timer.timeout.connect(_poll_tick)
		add_child(poll_timer)
	poll_timer.start()

func _poll_tick() -> void:
	poll_count += 1
	if poll_count > 20:
		_set_label(ui, "verify_status", "Confirmation timed out - Retry to continue.", COLOR_ERR)
		ui.retry_btn.disabled = false
		return
	cardano_service.tx_status(poll_hash, _cb_poll)

func _cb_poll(result: int, code: int, data) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and data is Dictionary and data.get("status", "") == "confirmed":
		if poll_phase == "proof":
			_start_attestation()
		else:
			_on_verified()
		return
	poll_timer.start()

func _on_verified() -> void:
	in_flow = false
	profile.verified[QUEST_IDS[flow_quest]] = true
	if flow_quest == 2:
		profile.complete_quest("quest_3")
	profile.save_profile()
	_cloud_save()
	ui.open_proof.disabled = false
	ui.open_attest.disabled = false
	ui.cont_btn.disabled = false
	_set_label(ui, "verify_status", "Achievement VERIFIED on Cardano OK", COLOR_OK)
	if cip30.connected:
		ui.cip30_status.text = "Player-signed attestation (CIP-30) verified OK"

func _continue_after_verify() -> void:
	if flow_quest < 2:
		current_quest += 1
		_in_play()
		_update_quest_hud()
		_show_screen("play")
	else:
		_stop_run()

func _connect_cip30() -> void:
	if not cip30.is_available():
		_set_label(ui, "cip30_status", "No CIP-30 wallet found in this browser. Attestation will be signed by the bridge.", COLOR_WARN)
		return
	_set_label(ui, "cip30_status", "Connecting wallet...", COLOR_WARN)
	ui.cip30_btn.disabled = true
	cip30.connect_wallet(_cb_cip30_connected)

func _cb_cip30_connected(data) -> void:
	ui.cip30_btn.disabled = false
	if cip30.apply_connect_result(data):
		ui.cip30_status.text = "Wallet connected: " + cip30.address.substr(0, 20) + "..."
		ui.cip30_status.add_theme_color_override("font_color", COLOR_OK)
	else:
		var msg := "wallet connect failed"
		if data is Dictionary and data.has("error"):
			msg = str(data.get("error", msg))
		_set_label(ui, "cip30_status", msg, COLOR_ERR)

func _refresh_achievements() -> void:
	for c in ui.achievements_list.get_children():
		c.queue_free()
	for i in range(QUEST_IDS.size()):
		var id: String = QUEST_IDS[i]
		var done: bool = profile.quests.get(id, false)
		var ver: bool = profile.verified.get(id, false)
		var state := "Locked"
		var color := Color("#64748b")
		if ver:
			state = "OK Verified on Cardano"
			color = COLOR_OK
		elif done:
			state = "Completed (not yet verified)"
			color = COLOR_WARN
		ui.achievements_list.add_child(_label("%s   -   %s" % [QUEST_NAMES[i], state], 15, color))