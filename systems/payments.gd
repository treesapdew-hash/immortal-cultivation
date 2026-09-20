class_name Payments

# =========================================================
# Real-money purchases.
#
# The device never decides what a purchase is worth. It sends the
# store's receipt to claim_purchase() (setup_17_integrity.sql) and
# the server answers with how much Jade to add, from its own
# store_products table. A receipt can only ever be claimed once,
# by anyone, so a captured one cannot be replayed or passed around.
#
# TEST MODE: purchases succeed instantly on this device and grant
# nothing, so the cash shop can be laid out. NEVER ship it on.
#
# BEFORE LAUNCH:
#   1. Add the Google Play Billing plugin (Android) and a StoreKit
#      plugin (iOS), and create the SKUs in each store's console.
#   2. Fill in store_products with those SKUs and what each grants.
#   3. Replace the marked block in purchase() with the real billing
#      call, and pass the store's purchase token to claim().
#   4. Purchases are recorded with verified = false until the
#      receipt is checked against Google's API. Reconcile that
#      table against the store's own reporting before trusting the
#      revenue, and add the check when the Play account is live.
# =========================================================

const TEST_MODE := false


static func available() -> bool:
	return Backend.is_configured()


## Starts a purchase. `on_done` is called with
## (sku: String, success: bool, jade: int) — the Jade is whatever the
## SERVER granted, already added. Callers must not add it again.
static func purchase(host: Node, sku: String, on_done: Callable) -> void:
	if TEST_MODE:
		# Pretend the store took a moment, and grant nothing: without a
		# receipt the server has nothing to check, and quietly handing
		# out Jade here is how a test build becomes a live exploit.
		await host.get_tree().create_timer(0.6).timeout
		on_done.call(sku, true, 0)
		return

	# ---- replace this block with the real store purchase ----
	# The plugin hands back a purchase token; pass it to claim(),
	# which is what actually adds the Jade.
	#   var token := await Billing.buy(sku)
	#   if token == "":
	#       on_done.call(sku, false, 0)
	#       return
	#   var got := await claim(sku, token)
	#   on_done.call(sku, got["ok"], int(got["jade"]))
	#   return
	push_warning("Payments: real store purchases aren't set up yet")
	on_done.call(sku, false, 0)
	# ---------------------------------------------------------


## Hands a store receipt to the server and adds whatever it grants.
## Returns {ok, error, jade}. Safe to call again with the same token:
## the second attempt grants nothing and says so.
static func claim(sku: String, token: String) -> Dictionary:
	if not available():
		return {"ok": false, "error": "Purchases need the online server.", "jade": 0}
	var platform := "ios" if OS.get_name() == "iOS" else "android"
	var r: Dictionary = await Backend.call_fn("claim_purchase", {
		"p_sku": sku, "p_token": token, "p_platform": platform,
	})
	if not r["ok"]:
		return {"ok": false, "error": "Couldn't reach the server. Your purchase is safe; "
			+ "reopen the shop to collect it.", "jade": 0}
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not bool(d.get("ok", false)):
		return {"ok": false, "error": str(d.get("error", "That purchase could not be claimed.")),
			"jade": 0}

	var jade := int(d.get("jade", 0))
	if jade > 0:
		GameState.add_immortal_jade(jade)
		GameState.save_game()
	return {"ok": true, "error": "", "jade": jade}
