class_name NumberFormat

# =========================================================
# One place for how numbers look everywhere in the game.
#
#   NumberFormat.short(99999)      -> "99,999"
#   NumberFormat.short(100000)     -> "100K"
#   NumberFormat.short(1234567)    -> "1.23M"
#   NumberFormat.short(12345678)   -> "12.3M"
#   NumberFormat.short(10**10)     -> "10B"
#   NumberFormat.full(1234567)     -> "1,234,567"
#
# Numbers are always rounded DOWN, so 999,999 shows as "999K",
# never "1M" before you actually have a million.
# =========================================================

## Below this, numbers are shown in full with commas.
const SHORT_FROM := 100000.0

const SUFFIXES := ["", "K", "M", "B", "T"]


## Short form for damage, currencies and costs.
static func short(value: float) -> String:
	var prefix := "-" if value < 0.0 else ""
	var v := absf(value)
	if v < SHORT_FROM:
		return prefix + full(int(v))

	var tier := 0
	while v >= 1000.0:
		v /= 1000.0
		tier += 1

	# Keep 3 significant digits: 1.23 / 12.3 / 123
	var decimals := 2 if v < 10.0 else (1 if v < 100.0 else 0)
	var step := pow(10.0, decimals)
	var shown := floorf(v * step + 0.000001) / step

	# String.num drops trailing zeros: 1.00 -> "1", 1.50 -> "1.5"
	return prefix + String.num(shown, decimals) + suffix(tier)


## Full number with commas: 1234567 -> "1,234,567".
static func full(value: int) -> String:
	var prefix := "-" if value < 0 else ""
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return prefix + digits + out


## "", K, M, B, T, then aa, ab, ac ... for huge numbers.
static func suffix(tier: int) -> String:
	if tier < SUFFIXES.size():
		return SUFFIXES[tier]
	var n := tier - SUFFIXES.size()
	@warning_ignore("integer_division")
	var first := n / 26
	return char(97 + first % 26) + char(97 + n % 26)
