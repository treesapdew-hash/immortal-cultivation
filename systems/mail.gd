class_name Mail

# =========================================================
# The mailbox. Messages can carry Jade and items, claimed by
# the player. Used for daily ranking rewards, and later for
# events, apologies, gifts and titles.
#
# Messages live in GameState.mail:
#   {id, title, body, jade, items, claimed, read, day}
# =========================================================

## Messages older than this are cleared once claimed.
const KEEP_DAYS := 14
const MAX_MESSAGES := 50


static func send(title: String, body: String, jade := 0, items := {}) -> Dictionary:
	var message := {
		"id": GameState.next_mail_id,
		"title": title,
		"body": body,
		"jade": jade,
		"items": items.duplicate(),
		"claimed": jade <= 0 and items.is_empty(),
		"read": false,
		"day": GameState.today(),
	}
	GameState.next_mail_id += 1
	GameState.mail.push_front(message)
	while GameState.mail.size() > MAX_MESSAGES:
		GameState.mail.pop_back()
	GameState.mail_changed.emit()
	return message


static func unread_count() -> int:
	var n := 0
	for m in GameState.mail:
		if not m["read"] or not m["claimed"]:
			n += 1
	return n


static func find(id: int) -> Dictionary:
	for m in GameState.mail:
		if int(m["id"]) == id:
			return m
	return {}


static func mark_read(id: int) -> void:
	var m := find(id)
	if not m.is_empty() and not m["read"]:
		m["read"] = true
		GameState.mail_changed.emit()


## Claims one message. Returns what was given.
static func claim(id: int) -> Dictionary:
	var m := find(id)
	if m.is_empty() or m["claimed"]:
		return {}
	m["claimed"] = true
	m["read"] = true
	if int(m["jade"]) > 0:
		GameState.add_immortal_jade(int(m["jade"]))
	if not m["items"].is_empty():
		GameState.add_items(m["items"])
	GameState.save_game()
	GameState.mail_changed.emit()
	return {"jade": m["jade"], "items": m["items"]}


## Claims everything. Returns the totals.
static func claim_all() -> Dictionary:
	var jade := 0
	var items := {}
	for m in GameState.mail:
		if m["claimed"]:
			continue
		m["claimed"] = true
		m["read"] = true
		jade += int(m["jade"])
		for id in m["items"]:
			items[id] = int(items.get(id, 0)) + int(m["items"][id])
	if jade > 0:
		GameState.add_immortal_jade(jade)
	if not items.is_empty():
		GameState.add_items(items)
	if jade > 0 or not items.is_empty():
		GameState.save_game()
		GameState.mail_changed.emit()
	return {"jade": jade, "items": items}


static func delete_claimed() -> void:
	var kept: Array = []
	for m in GameState.mail:
		if not m["claimed"]:
			kept.append(m)
	GameState.mail = kept
	GameState.save_game()
	GameState.mail_changed.emit()
