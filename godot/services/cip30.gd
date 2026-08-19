extends Node
## CIP-30 wallet connector (autoload) - browser-only, via JavaScriptBridge.
## Detects Eternl/Nami/Vespr/Gero/Flint and signs data with the player's wallet.

var address := ""
var signature := ""
var key := ""
var connected := false
var balance_lovelace := 0
var balance_ada := 0.0
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
	  function head(hex, at){
	    var b = parseInt(hex.slice(at, at + 2), 16), ai = b & 31, major = b >> 5, p = at + 2;
	    if(ai < 24) return {major:major, value:BigInt(ai), next:p};
	    var sizes = {24:1, 25:2, 26:4, 27:8}, n = sizes[ai];
	    if(!n) throw new Error('unsupported CBOR value');
	    return {major:major, value:BigInt('0x' + hex.slice(p, p + n * 2)), next:p + n * 2};
	  }
	  function coin(hex){
	    var value = head(hex, 0);
	    if(value.major === 0) return value.value;
	    if(value.major === 4){
	      var amount = head(hex, value.next);
	      if(amount.major === 0) return amount.value;
	    }
	    throw new Error('invalid CIP-30 balance');
	  }
	  w[name].enable().then(function(api){
	    return Promise.all([api.getUsedAddresses(), api.getChangeAddress(), api.getBalance()]);
	  }).then(function(values){
	    var address = values[0][0] || values[1] || '';
	    window.__c30c = JSON.stringify({address:address, balanceLovelace:coin(values[2]).toString()});
	  })
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
	balance_lovelace = int(str(data.get("balanceLovelace", "0")))
	balance_ada = float(balance_lovelace) / 1000000.0
	connected = true
	return true

func apply_sign_result(data) -> bool:
	if data == null or data.has("error") or data.get("signature", "") == "":
		return false
	signature = str(data.get("signature", ""))
	key = str(data.get("key", ""))
	return true
