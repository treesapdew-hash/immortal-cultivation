class_name Payments

# =========================================================
# Real-money purchases.
#
# TEST MODE (now): purchases succeed instantly on this device,
# so the cash shop can be tested. NEVER ship with TEST_MODE on.
#
# BEFORE LAUNCH:
#   1. Add the Google Play Billing plugin (Android) and a
#      StoreKit plugin (iOS) for Godot, and create the products
#      below (same SKUs) in each store's console.
#   2. In purchase(), start the store purchase instead of the
#      test timer.
#   3. Send the store receipt to your own server, verify it
#      there, and only grant Jade when the server says it's valid.
#      Never trust the device for premium currency.
# =========================================================

const TEST_MODE := false


## Starts a purchase. `on_done` is called with (sku: String, success: bool).
static func purchase(host: Node, sku: String, on_done: Callable) -> void:
	if TEST_MODE:
		# Pretend the store took a moment
		await host.get_tree().create_timer(0.6).timeout
		on_done.call(sku, true)
		return

	# TODO: start the real store purchase here, then verify the
	# receipt on the server before calling on_done(sku, true).
	push_warning("Payments: real store purchases aren't set up yet")
	on_done.call(sku, false)
