extends Control
## LAB3 Godot x Cardano Game - main controller.
## Screens: menu, profile, play (platformer world), verify, achievements, settings.

const QUEST_NAMES := [
	"Quest 1: Collect 5 Coins",
	"Quest 2: Defeat 3 Monsters",
	"Quest 3: Reach the Village Gate",
]
const QUEST_IDS := ["quest_1", "quest_2", "quest_3"]

const COLOR_TITLE := Color("#22c1a6")
const COLOR_OK := Color("#4ade80")
const COLOR_WARN := Color("#fbbf24")
const COLOR_ERR := Color("#f87171")
const COLOR_INFO := Color("#a5b4fc")

var screens := {}
var ui := {}
var fade: ColorRect
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
var max_health := 100
var current_health := 100

func _ready() -> void:
	_ensure_input()
	theme = ui_theme.theme
	_build_background()
	_build_screens()
	_build_fade()
	_show_screen("menu")
	_apply_profile_to_ui()

func _process(_delta: float) -> void:
	if world == null or not screens.has("play") or not screens["play"].visible:
		return
	if ui.has("skill_slash"):
		var slash_cd: float = world.skill1_cd
		ui.skill_slash.text = "READY" if slash_cd <= 0.0 else "%.1fs" % slash_cd
		ui.skill_slash.modulate = Color.WHITE if slash_cd <= 0.0 else Color(0.55, 0.62, 0.68)
		ui.skill_slash_card.disabled = slash_cd > 0.0
	if ui.has("skill_fire"):
		var fire_cd: float = world.skill2_cd
		ui.skill_fire.text = "READY" if fire_cd <= 0.0 else "%.1fs" % fire_cd
		ui.skill_fire.modulate = Color.WHITE if fire_cd <= 0.0 else Color(0.55, 0.62, 0.68)
		ui.skill_fire_card.disabled = fire_cd > 0.0

func _build_background() -> void:
	var backdrop := preload("res://ui/starfield.gd").new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

func _ensure_input() -> void:
	# Guarantee WASD + Space work (browser focus / default map fallback).
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	_add_key("ui_accept", KEY_SPACE)
	_add_key("skill_1", KEY_J)
	_add_key("skill_2", KEY_K)

func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _build_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0.04, 0.05, 0.1, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.visible = false
	add_child(fade)

func _transition_to(name: String) -> void:
	fade.visible = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.2)
	tw.tween_callback(func(): _show_screen(name))
	tw.tween_property(fade, "color:a", 0.0, 0.25)
	tw.tween_callback(func(): fade.visible = false)

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _centered_label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 74)
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
	if ui.has("play_hud_layer"):
		ui.play_hud_layer.visible = (name == "play")

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
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(root)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 620)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var eyebrow := _centered_label("ON-CHAIN ADVENTURE", 11, Color("#73f7de"))
	v.add_child(eyebrow)
	v.add_child(_centered_label("LAB3", 42, Color("#f4fbff")))
	v.add_child(_centered_label("GODOT x CARDANO", 22, Color("#ffd166")))
	var hero := TextureRect.new()
	var hero_atlas := AtlasTexture.new()
	hero_atlas.atlas = load("res://assets/local_pack/characters/hero_idle.png")
	hero_atlas.region = Rect2(0, 0, 32, 32)
	hero.texture = hero_atlas
	hero.custom_minimum_size = Vector2(88, 88)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(hero)
	v.add_child(_centered_label("A playable Web3 reference game.\nComplete quests. Build identity. Verify on Cardano.", 10, Color("#9db1c8")))
	ui.menu_player = _label("", 12, COLOR_INFO)
	ui.menu_player.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ui.menu_player)
	v.add_child(_button("PLAY", func(): _start_run()))
	v.add_child(_button("PLAYER PROFILE", func(): _transition_to("profile")))
	v.add_child(_button("ACHIEVEMENTS", func(): _refresh_achievements(); _transition_to("achievements")))
	v.add_child(_button("SETTINGS", func(): _transition_to("settings")))

func _center_panel(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	return v

func _build_profile() -> void:
	var s := _screen("profile")
	var v := _center_panel(s)
	v.add_child(_centered_label("PLAYER PROFILE", 22, COLOR_TITLE))
	v.add_child(_centered_label("Your identity, progress and on-chain achievements.", 11, Color("#94a3b8")))
	var rn := _row()
	rn.add_child(_label("PLAYER NAME", 11))
	ui.profile_name = LineEdit.new()
	ui.profile_name.custom_minimum_size.x = 380
	ui.profile_name.placeholder_text = "Choose your adventurer name"
	rn.add_child(ui.profile_name)
	v.add_child(rn)
	ui.profile_stats = _label("", 13, COLOR_INFO)
	v.add_child(ui.profile_stats)
	ui.profile_balance = _label("Connect a CIP-30 wallet to read your ADA balance.", 12, Color("#ffd166"))
	v.add_child(ui.profile_balance)
	var rb := _row()
	rb.add_child(_button("LOGIN WITH WALLET (CIP-30)", func(): _login_wallet()))
	rb.add_child(_button("BACK", func(): _transition_to("menu")))
	v.add_child(rb)
	ui.profile_msg = _label("", 11)
	v.add_child(ui.profile_msg)

func _build_play() -> void:
	var s := _screen("play")
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 50
	add_child(hud_layer)
	ui.play_hud_layer = hud_layer
	var hud_root := Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 14
	top.offset_bottom = 72
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_right", 16)
	hud_root.add_child(top)
	var h := HBoxContainer.new()
	top.add_child(h)
	h.add_theme_constant_override("separation", 18)
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 230
	vitals.add_child(_label("PLAYER VITALS", 8, Color("#ffb4b4")))
	ui.health_bar = ProgressBar.new()
	ui.health_bar.max_value = max_health
	ui.health_bar.value = current_health
	ui.health_bar.show_percentage = false
	ui.health_bar.custom_minimum_size = Vector2(230, 16)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color("#190d18")
	hp_bg.set_corner_radius_all(7)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color("#ef3857")
	hp_fill.set_corner_radius_all(7)
	ui.health_bar.add_theme_stylebox_override("background", hp_bg)
	ui.health_bar.add_theme_stylebox_override("fill", hp_fill)
	vitals.add_child(ui.health_bar)
	ui.health_text = _label("HP 100 / 100", 8, Color.WHITE)
	vitals.add_child(ui.health_text)
	h.add_child(vitals)
	ui.play_quest = _label("", 11, Color("#73f7de"))
	ui.play_quest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ui.play_quest)
	ui.play_progress = _label("", 9, COLOR_INFO)
	h.add_child(ui.play_progress)
	ui.ada_balance = _label("ADA --", 11, Color("#73f7de"))
	ui.ada_balance.custom_minimum_size.x = 155
	ui.ada_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ui.ada_balance)
	var back := _button("EXIT", func(): _stop_run())
	back.custom_minimum_size = Vector2(100, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(back)
	# online chat
	var chat_box := VBoxContainer.new()
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 12
	chat_box.offset_bottom = -12
	chat_box.offset_right = 420
	chat_box.custom_minimum_size.y = 190
	chat_box.add_theme_constant_override("separation", 4)
	hud_root.add_child(chat_box)
	ui.chat = RichTextLabel.new()
	ui.chat.bbcode_enabled = true
	ui.chat.scroll_active = true
	ui.chat.custom_minimum_size.y = 150
	chat_box.add_child(ui.chat)
	var chat_row := HBoxContainer.new()
	ui.chat_input = LineEdit.new()
	ui.chat_input.placeholder_text = "Chat (Enter to send)"
	ui.chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.chat_input.text_submitted.connect(_send_chat)
	chat_row.add_child(ui.chat_input)
	var send := _button("Send", func(): _send_chat(ui.chat_input.text))
	chat_row.add_child(send)
	chat_box.add_child(chat_row)
	ui.info_label = _label("Click a player to view their profile", 13, COLOR_INFO)
	hud_root.add_child(ui.info_label)
	ui.info_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	ui.info_label.offset_right = -12
	ui.info_label.offset_bottom = -164
	var skills := HBoxContainer.new()
	skills.anchor_left = 0.5
	skills.anchor_right = 0.5
	skills.anchor_top = 1.0
	skills.anchor_bottom = 1.0
	skills.offset_left = -190
	skills.offset_top = -138
	skills.offset_right = 190
	skills.offset_bottom = -10
	skills.add_theme_constant_override("separation", 10)
	hud_root.add_child(skills)
	var slash_card := _skill_card("J", "SPECTRAL SLASH", Color("#35e6ff"), load("res://assets/custom/skills/spectral_slash.png"), func(): _activate_skill(1))
	var fire_card := _skill_card("K", "INFERNO ORB", Color("#ff7a24"), load("res://assets/custom/skills/inferno_orb.png"), func(): _activate_skill(2))
	skills.add_child(slash_card.card)
	skills.add_child(fire_card.card)
	ui.skill_slash = slash_card.status
	ui.skill_fire = fire_card.status
	ui.skill_slash_card = slash_card.card
	ui.skill_fire_card = fire_card.card
	var flow := PanelContainer.new()
	flow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	flow.offset_left = -510
	flow.offset_top = 82
	flow.offset_right = -18
	flow.offset_bottom = 124
	hud_root.add_child(flow)
	ui.flow_label = _centered_label("PLAY  >  MILESTONE  >  CIP-0170  >  CARDANO", 9, Color("#ffd166"))
	flow.add_child(ui.flow_label)

func _skill_card(key: String, title: String, accent: Color, icon: Texture2D, callback: Callable) -> Dictionary:
	var card := Button.new()
	card.custom_minimum_size = Vector2(185, 128)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = title + "  |  Click or press " + key
	card.pressed.connect(callback)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.06, 0.10, 0.96)
	normal.border_color = Color(accent, 0.82)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.shadow_color = Color(0, 0, 0, 0.62)
	normal.shadow_size = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(accent, 0.20)
	hover.border_color = accent
	hover.set_border_width_all(3)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(accent, 0.34)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.025, 0.04, 0.06, 0.88)
	disabled.border_color = Color(accent, 0.28)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)
	card.add_theme_stylebox_override("disabled", disabled)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 10
	row.offset_right = -10
	row.offset_bottom = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(76, 76)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)
	copy.add_child(_label("[" + key + "]", 11, accent))
	copy.add_child(_label(title, 9, Color.WHITE))
	var status := _label("READY", 9, Color("#7ef29a"))
	copy.add_child(status)
	return { "card": card, "status": status }

func _activate_skill(index: int) -> void:
	if world == null or not screens["play"].visible:
		return
	if world.try_cast_skill(index):
		var card: Button = ui.skill_slash_card if index == 1 else ui.skill_fire_card
		var tween := create_tween()
		tween.tween_property(card, "scale", Vector2(0.92, 0.92), 0.06)
		tween.tween_property(card, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_verify() -> void:
	var s := _screen("verify")
	var v := _center_panel(s)
	v.add_child(_centered_label("MILESTONE COMPLETE", 25, COLOR_OK))
	v.add_child(_centered_label("Your adventure is becoming permanent.", 11, Color("#94a3b8")))
	ui.verify_quest = _label("", 18)
	v.add_child(ui.verify_quest)
	ui.verify_xp = _label("", 16, COLOR_INFO)
	v.add_child(ui.verify_xp)
	v.add_child(HSeparator.new())
	v.add_child(_label("CARDANO VERIFICATION", 15, COLOR_TITLE))
	ui.verify_status = _label("", 15, COLOR_WARN)
	v.add_child(ui.verify_status)
	ui.verify_proof = _label("", 13, COLOR_INFO)
	v.add_child(ui.verify_proof)
	ui.verify_attest = _label("", 13, COLOR_INFO)
	v.add_child(ui.verify_attest)
	var row_btn := _row()
	var open_proof := _button("OPEN PROOF TX", func():
		if proof_tx_hash != "":
			OS.shell_open(cardano_service.explorer_url(proof_tx_hash))
	)
	open_proof.disabled = true
	ui.open_proof = open_proof
	row_btn.add_child(open_proof)
	var open_attest := _button("OPEN ATTESTATION TX", func():
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
	var cip30_btn := _button("CONNECT WALLET", func(): _connect_cip30())
	ui.cip30_btn = cip30_btn
	row2.add_child(cip30_btn)
	var retry := _button("RETRY", func(): _start_cardano_flow(flow_quest))
	retry.disabled = true
	ui.retry_btn = retry
	row2.add_child(retry)
	v.add_child(row2)
	var cont := _button("CONTINUE ADVENTURE", func(): _continue_after_verify())
	ui.cont_btn = cont
	cont.disabled = true
	v.add_child(cont)

func _build_achievements() -> void:
	var s := _screen("achievements")
	var v := _center_panel(s)
	v.add_child(_centered_label("ACHIEVEMENTS", 24, COLOR_TITLE))
	v.add_child(_centered_label("Every completed quest can become verifiable proof.", 11, Color("#94a3b8")))
	ui.achievements_list = VBoxContainer.new()
	v.add_child(ui.achievements_list)
	v.add_child(_button("BACK TO BASE", func(): _transition_to("menu")))

func _build_settings() -> void:
	var s := _screen("settings")
	var v := _center_panel(s)
	v.add_child(_centered_label("SYSTEM STATUS", 24, COLOR_TITLE))
	v.add_child(_label("NETWORK  •  " + cardano_service.network.to_upper(), 12, COLOR_OK))
	v.add_child(_label("BRIDGE   •  " + cardano_service.bridge_url, 10, COLOR_INFO))
	var about := _label("Catalyst Quest keeps gameplay fast and off-chain. Only meaningful quest milestones are anchored to Cardano with proof metadata and CIP-0170 attestations.", 11, Color("#94a3b8"))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 600
	v.add_child(about)
	v.add_child(_button("BACK TO BASE", func(): _transition_to("menu")))

# ---------------------------------------------------------------------------
# Profile / cloud
# ---------------------------------------------------------------------------
func _apply_profile_to_ui() -> void:
	ui.profile_name.text = profile.player_name
	_set_label(ui, "profile_stats", "Level %d  -  XP %d/%d  -  Coins %d  -  Terminals %d" % [profile.level, profile.xp, profile.level * 100, profile.fragments, profile.terminals], COLOR_INFO)
	var who := "Player" if profile.player_name == "" else profile.player_name
	var login := "Login required"
	var ada := "ADA --"
	if cip30.connected and cip30.address == profile.address:
		login = "Wallet connected"
		ada = "%.2f ADA" % cip30.balance_ada
	ui.menu_player.text = "%s  -  Level %d  -  %d/%d XP  -  %s  -  %s" % [who, profile.level, profile.xp, profile.level * 100, login, ada]
	if profile.address == "":
		_set_label(ui, "profile_balance", "No account yet. Enter a name and connect your wallet.", COLOR_WARN)
	elif cip30.connected and cip30.address == profile.address:
		_set_label(ui, "profile_balance", "Balance: %.6f ADA  |  Wallet: %s..." % [cip30.balance_ada, profile.address.substr(0, 20)], Color("#73f7de"))
	else:
		_set_label(ui, "profile_balance", "Reconnect wallet to refresh ADA balance.", COLOR_WARN)

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
	if ui.profile_name.text.strip_edges() == "":
		_set_label(ui, "profile_msg", "Enter a player name before connecting your wallet.", COLOR_WARN)
		return
	if not cip30.is_available():
		_set_label(ui, "profile_msg", "No CIP-30 wallet found. Install Eternl, Vespr, Nami, Gero or Flint.", COLOR_WARN)
		return
	_set_label(ui, "profile_msg", "Connecting wallet...", COLOR_WARN)
	cip30.connect_wallet(_cb_login_wallet)

func _cb_login_wallet(data) -> void:
	if not cip30.apply_connect_result(data):
		_set_label(ui, "profile_msg", "Wallet connect failed", COLOR_ERR)
		return
	profile.player_name = ui.profile_name.text.strip_edges()
	profile.address = cip30.address
	profile.save_profile()
	_apply_profile_to_ui()
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
		profile.save_profile()
		_cloud_save()
		_apply_profile_to_ui()
		_set_label(ui, "profile_msg", "Account created. Wallet and ADA balance are ready.", COLOR_OK)
	get_tree().create_timer(0.8).timeout.connect(func(): _transition_to("menu"))

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
func _start_run() -> void:
	if profile.player_name == "" or profile.address == "":
		_transition_to("profile")
		_set_label(ui, "profile_msg", "Create an account with your player name and wallet before playing.", COLOR_WARN)
		return
	if not cip30.connected or cip30.address != profile.address:
		_transition_to("profile")
		_set_label(ui, "profile_msg", "Login with your wallet to play and refresh your ADA balance.", COLOR_WARN)
		return
	quest_state.reset_run()
	current_health = max_health
	current_quest = 0
	_in_play()
	_show_screen("play")

func _in_play() -> void:
	if world != null:
		world.queue_free()
	world = preload("res://game/world.gd").new()
	add_child(world)
	world.coins_collected.connect(_on_coins)
	world.monsters_killed.connect(_on_monsters)
	world.gate_reached.connect(_on_gate)
	world.player_damaged.connect(_on_player_damaged)
	world.player_clicked.connect(_on_player_clicked)
	_update_quest_hud()
	_update_health_hud()
	if ui.chat != null:
		ui.chat.clear()
	_chat_timer = Timer.new()
	_chat_timer.wait_time = 3.0
	_chat_timer.timeout.connect(_poll_chat)
	add_child(_chat_timer)
	_chat_timer.start()
	_poll_chat()

func _stop_run() -> void:
	if world != null:
		world.queue_free()
		world = null
	if _chat_timer != null:
		_chat_timer.stop()
		_chat_timer.queue_free()
		_chat_timer = null
	_show_screen("menu")
	_apply_profile_to_ui()

func _update_quest_hud() -> void:
	ui.play_quest.text = QUEST_NAMES[current_quest]
	if world != null:
		ui.play_progress.text = "Coins %d/%d   Monsters %d/%d" % [8 - int(world.coins_left), 8, 3 - int(world.monsters_left), 3]
		ui.ada_balance.text = "₳ %.6f" % cip30.balance_ada
		var identity := "WALLET CONNECTED / CIP-0170 READY"
		ui.flow_label.text = "PLAY  >  MILESTONE  >  CIP-0170  >  CARDANO   |   " + identity

func _on_coins(n: int) -> void:
	var collected := 8 - n
	profile.fragments = maxi(profile.fragments, collected)
	if current_quest == 0 and collected >= 5:
		_complete_quest(0)
	else:
		_update_quest_hud()

func _on_monsters(n: int) -> void:
	var killed := 3 - n
	profile.terminals = maxi(profile.terminals, killed)
	if current_quest == 1 and killed >= 3:
		_complete_quest(1)
	else:
		_update_quest_hud()

func _on_gate() -> void:
	if current_quest == 2:
		_complete_quest(2)

func _on_player_damaged() -> void:
	current_health = maxi(current_health - 20, 0)
	_update_health_hud()
	if current_health <= 0:
		current_health = max_health
		world.reset_player()
		_update_health_hud()

func _update_health_hud() -> void:
	if not ui.has("health_bar"):
		return
	ui.health_bar.value = current_health
	ui.health_text.text = "HP %d / %d" % [current_health, max_health]

func _on_player_clicked(address: String, name: String) -> void:
	ui.info_label.text = "Loading %s profile..." % name
	ui.info_label.add_theme_color_override("font_color", COLOR_WARN)
	cardano_service.load_player(address, func(result: int, code: int, data):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and data is Dictionary:
			var d = data.get("data")
			if d != null:
				var q: Dictionary = d.get("quests", {})
				var q1 = q.get("quest_1", false)
				var q2 = q.get("quest_2", false)
				var q3 = q.get("quest_3", false)
				ui.info_label.text = "%s  |  Lv %d  XP %d  |  Q1:%s Q2:%s Q3:%s" % [name, int(d.get("level", 1)), int(d.get("xp", 0)), str(q1), str(q2), str(q3)]
				ui.info_label.add_theme_color_override("font_color", COLOR_OK)
			else:
				ui.info_label.text = "%s - new player (no data yet)" % name
				ui.info_label.add_theme_color_override("font_color", COLOR_WARN)
		else:
			ui.info_label.text = "Could not load %s profile" % name
			ui.info_label.add_theme_color_override("font_color", COLOR_ERR)
	)

var _chat_timer: Timer

func _poll_chat() -> void:
	cardano_service.fetch_chat(_cb_chat)

func _cb_chat(result: int, code: int, data) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or data == null or not data.get("ok", false):
		return
	var msgs = data.get("messages", [])
	ui.chat.clear()
	for m in msgs:
		ui.chat.append_text("[color=#7dd3fc]%s:[/color] %s\n" % [str(m.get("sender", "?")), str(m.get("text", ""))])

func _send_chat(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		ui.chat_input.text = ""
		return
	var sender := profile.player_name
	if sender == "":
		sender = "Guest"
	if profile.address != "":
		sender += " (" + profile.address.substr(0, 6) + ")"
	cardano_service.send_chat(sender, t, func(_r: int, _c: int, _d): pass)
	ui.chat_input.text = ""
	_poll_chat()

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
		ui.cip30_status.text = "Wallet connected: " + cip30.address.substr(0, 20) + "...  |  %.6f ADA" % cip30.balance_ada
		ui.cip30_status.add_theme_color_override("font_color", COLOR_OK)
		_apply_profile_to_ui()
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
