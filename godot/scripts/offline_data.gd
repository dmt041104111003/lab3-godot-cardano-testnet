class_name OfflineData
## Offline development data source.
##
## Used ONLY when OFFLINE_MODE is true in main.gd, for developing the UI and
## flows without network access. It is strictly separated from the live path.
## All values returned here are clearly marked and are never used as evidence.

static func tip() -> Dictionary:
	return {
		"offline": true,
		"block_height": 5066198,
	}

static func address_info(address: String) -> Array:
	return [
		{
			"offline": true,
			"address": address,
			"balance": 12500000000,
			"stake_address": "stake_test1...offline...",
			"utxo_set": [],
		},
	]

static func tx_info(tx_hash: String) -> Array:
	return [
		{
			"offline": true,
			"tx_hash": tx_hash,
			"block_height": 5066198,
		},
	]

static func submit(quest_id: String, player_address: String) -> Dictionary:
	var fake_hash := "0000000000000000000000000000000000000000000000000000000000000000"
	return {
		"ok": true,
		"offline": true,
		"txHash": fake_hash,
		"network": "preprod",
		"explorerUrl": "https://preprod.cardanoscan.io/transaction/" + fake_hash,
	}