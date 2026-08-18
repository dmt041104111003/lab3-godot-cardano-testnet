extends Node
## CIP-30 wallet connector (autoload) - browser-only, via JavaScriptBridge.
## Detects Eternl/Nami/Vespr/Gero/Flint and signs data with the player's wallet.

var address := ""
var signature := ""
var key := ""
var connected := false
var pending_cb: Callable = Callable()
var _timer: Timer
var _poll_var := ""
var _poll_remaining := 0

func _js(code: String) -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval(code)
	return ""

func is_available() -> bool:
	if not OS.has_feature("web"):
		return false
	var names := _js("Object.keys(window.cardano||{}).filter(function(n){return ['eternl','vespr','nami','gero','flint'].indexOf(n)>=0;}).join(',')")
	return names != ""

func connect_wallet(cb: Callable) -> void:
	pending_cb = cb
	_js("""
	(function(){
	  var w = window.cardano || {};
	  var name = ['eternl','vespr','nami','gero','flint'].find(function(n){ return w[n]; });
	  if(!name){ window.__c30c = JSON.stringify({error:'no CIP-30 wallet found'}); return; }
	  w[name].enable().then(function(api){ return api.getUsedAddresses(); })
	    .then(function(addrs){ window.__c30c = JSON.stringify({address: addrs[0] || ''}); })
	    .catch(function(e){ window.__c30c = JSON.stringify({error: String(e)}); });
	})();
	""")
	_start_poll("__c30c")

func sign(payload_hex: String, cb: Callable) -> void:
	pending_cb = cb
	_js("""
	(function(){
	  var w = window.cardano || {};
	  var name = ['eternl','vespr','nami','gero','flint'].find(function(n){ return w[n]; });
	  if(!name){ window.__c30s = JSON.stringify({error:'no CIP-30 wallet found'}); return; }
	  w[name].enable().then(function(api){ return api.signData('%s', '%s'); })
	    .then(function(s){ window.__c30s = JSON.stringify({signature:s.signature, key:s.key}); })
	    .catch(function(e){ window.__c30s = JSON.stringify({error: String(e)}); });
	})();
	""" % [address, payload_hex])
	_start_poll("__c30s")

func _start_poll(var_name: String) -> void:
	_poll_var = var_name
	_poll_remaining = 40
	if _timer == null:
		_timer = Timer.new()
		_timer.wait_time = 0.5
		_timer.timeout.connect(_tick)
		add_child(_timer)
	_timer.start()

func _tick() -> void:
	var raw := _js("window.%s" % _poll_var)
	if raw != "" and raw != "null":
		_timer.stop()
		_js("window.%s = null" % _poll_var)
		var cb := pending_cb
		pending_cb = Callable()
		var data = JSON.parse_string(raw)
		cb.call(data)
		return
	_poll_remaining -= 1
	if _poll_remaining <= 0:
		_timer.stop()
		var cb := pending_cb
		pending_cb = Callable()
		cb.call({ "error": "timeout" })

func apply_connect_result(data) -> bool:
	if data == null or data.has("error") or data.get("address", "") == "":
		return false
	address = str(data.get("address", ""))
	connected = true
	return true

func apply_sign_result(data) -> bool:
	if data == null or data.has("error") or data.get("signature", "") == "":
		return false
	signature = str(data.get("signature", ""))
	key = str(data.get("key", ""))
	return true