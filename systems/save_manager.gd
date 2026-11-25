extends Node

## Centralized Retail Progression, Save/Load Slot Manager & Codex State (Thrive decoupled signal pattern).
## Manages 3 JSON save slots, Desire Fragments, Silver-Rose Vitality (5 petals), Allure gauge & Shattered Memories.

signal state_changed
signal memory_unlocked(mem_id: String, title: String)
signal desire_gained(amount: int, reason: String)

const SAVE_DIR := "user://saves"
const MAX_SLOTS := 3

var desire_fragments: int = 0
var hp: int = 5
var max_hp: int = 5
var allure: float = 35.0
var unlocked_memories: Array[String] = []
var opened_chests: Array[String] = []
var owned_items: Array[String] = ["dorothy_gingham", "scarecrow_classic", "tinman_classic", "lion_classic", "toto_classic"]
var equipped_outfits: Dictionary = {
	"dorothy": "dorothy_gingham",
	"scarecrow": "scarecrow_classic",
	"tinman": "tinman_classic",
	"lion": "lion_classic",
	"toto": "toto_classic",
}
var current_scene_path: String = "res://regions/kansas/farmyard.tscn"
var current_chapter: String = "Act 0 · Kansas — The Gale Farm"
var difficulty: String = "standard" # "story" | "standard" | "nightmare"
var screen_shake_enabled: bool = true
var high_contrast_hud: bool = false

func damage_multiplier() -> float:
	match difficulty:
		"story":
			return 0.6
		"nightmare":
			return 1.6
		_:
			return 1.0

const SHOP_CATALOG := {
	"dorothy": [
		{"id": "dorothy_gingham", "name": "Prairie Gingham", "cost": 0, "perk": "Classic blue-and-white gingham.", "tint": Color(0.24, 0.42, 0.86)},
		{"id": "dorothy_velvet", "name": "Velvet Corset Couture", "cost": 25, "perk": "+25% Allure gain · Crimson-obsidian silk gown.", "tint": Color(0.68, 0.08, 0.24)},
		{"id": "dorothy_sovereign", "name": "Silver-Lace Sovereign", "cost": 45, "perk": "+40% Allure & faster Blink · Silver-violet couture.", "tint": Color(0.66, 0.54, 0.88)},
		{"id": "dorothy_whip_plus", "name": "Lace Whip Mastery (Weapon)", "cost": 30, "perk": "Upgrades Lace Whip pull & +8 bonus lash damage.", "tint": Color(0.95, 0.18, 0.42)},
	],
	"scarecrow": [
		{"id": "scarecrow_classic", "name": "Cornfield Straw", "cost": 0, "perk": "Classic patched burlap tunic.", "tint": Color(0.72, 0.56, 0.34)},
		{"id": "scarecrow_leather", "name": "Burlap & Leather", "cost": 25, "perk": "Dark-leather straps · Wider Crow Scatter radius.", "tint": Color(0.28, 0.18, 0.16)},
		{"id": "scarecrow_obsidian", "name": "Obsidian Crowmaster", "cost": 45, "perk": "Raven-feathered coat · Longer enemy Confusion.", "tint": Color(0.14, 0.12, 0.20)},
	],
	"tinman": [
		{"id": "tinman_classic", "name": "Polished Tin", "cost": 0, "perk": "Mirror-buffed silver tin plate.", "tint": Color(0.76, 0.80, 0.86)},
		{"id": "tinman_velvet", "name": "Chrome & Crimson Velvet", "cost": 25, "perk": "+10 Axe Cleave · Dark chrome & crimson sash.", "tint": Color(0.32, 0.14, 0.22)},
	],
	"lion": [
		{"id": "lion_classic", "name": "Golden Mane", "cost": 0, "perk": "Natural tawny mane & coat.", "tint": Color(0.84, 0.58, 0.24)},
		{"id": "lion_primal", "name": "Primal Gold Harness", "cost": 25, "perk": "Gilded war-mane · Extended Roar Fear shockwave.", "tint": Color(0.95, 0.72, 0.18)},
	],
	"toto": [
		{"id": "toto_classic", "name": "Cairn Terrier", "cost": 0, "perk": "Loyal dark-brindle prairie terrier.", "tint": Color(0.24, 0.18, 0.14)},
		{"id": "toto_silver_collar", "name": "Silver-Spiked Collar", "cost": 15, "perk": "Shimmering silver-star collar · Wider bark aura.", "tint": Color(0.55, 0.58, 0.68)},
	],
}

const MEMORY_CATALOG := {
	"kansas_locket": {
		"title": "Aunt Em's Tarnished Locket",
		"region": "Kansas Farmhouse",
		"text": "Inside the tin locket is a faded tintype of a prairie before the dust took the color out of everything. Dorothy remembers thinking that grey was just the price of growing up."
	},
	"kansas_barn_diary": {
		"title": "Uncle Henry's Weather Ledger",
		"region": "Kansas Barn",
		"text": "'Barometer dropped three fingers before noon. Stock won't drink. Even the sky wants something it cannot name.' Torn pages smell of axle grease and ozone."
	},
	"munchkin_porcelain_mask": {
		"title": "Cracked Lollipop Mask",
		"region": "Munchkinland Cottage",
		"text": "Painted with a permanent pastel smile. Underneath the glaze, fine needle-marks line the rim — proof that cheerfulness in Oz is enforced, not felt."
	},
	"munchkin_silver_ledger": {
		"title": "East Witch's Debt Book",
		"region": "Munchkinland Interior",
		"text": "Columns of names traded for sugar, youth, and obedience. The ink still shimmers faintly silver whenever Dorothy's shoes step across the threshold."
	},
	"emerald_spectacles": {
		"title": "Green-Tinted Spectacles",
		"region": "Emerald City",
		"text": "Locked with a tiny brass clasp so no citizen can remove them. Everything looks opulent through emerald glass — until you glimpse the rust in the reflection."
	},
}

const BESTIARY_CATALOG := [
	{
		"name": "Rogue Munchkin Axeman",
		"region": "Munchkinland",
		"threat": "Pack Swarms · Hatchet Cleave",
		"lore": "Sweet-faced guild enforcers driven manic by the East Witch's collapse. Vulnerable to Dorothy's Silver-Shoe Kick and Scarecrow's Crow Scatter."
	},
	{
		"name": "Lollipop Guild Marshal",
		"region": "Munchkinland Plaza",
		"threat": "Armored Elite · Heavy Overhead Cleave",
		"lore": "Captain of the sugar-coated militia. Use Tin Man's Axe to shatter his armor plating or Lion's Roar to break his stance."
	},
	{
		"name": "Wicked Witch of the West",
		"region": "Winkie Iron Castle",
		"threat": "Boss · Umbrella-Staff Hexes & Winged Monkeys",
		"lore": "Pale, gaunt, and one-eyed (Baum canon). Brute force only grounds her — draw water from the ruptured courtyard cistern to unmake her."
	},
	{
		"name": "Oscar Diggs (The Humbug Wizard)",
		"region": "Emerald Palace",
		"threat": "Illusionist · Volumetric Hologram & Brass Gears",
		"lore": "A terrified Omaha balloonist hiding behind crimson velvet drapes and a geared voice-horn, trading false miracles for absolute devotion."
	},
]

const COMPANION_CATALOG := [
	{
		"id": "dorothy",
		"name": "Dorothy Gale",
		"role": "Lead · Mobility & Silver Shoes",
		"kit": "F: Silver-Shoe Kick · Space: Jump / Heel-Blink · E: Interact",
		"lore": "Small in a hostile, opulent world. She does not conquer Oz by brute strength — she survives by movement, clarity, and keeping her circle whole."
	},
	{
		"id": "scarecrow",
		"name": "The Scarecrow",
		"role": "Crowd Control · Brain",
		"kit": "F: Crow Flock Caw (confuses & scatters enemy packs)",
		"lore": "Stuffed with straw and haunted by the fear of being hollow, yet sharpest of all when reading the traps of the Yellow Brick Road."
	},
	{
		"id": "tinman",
		"name": "The Tin Woodman",
		"role": "Armor Breaker · Heart",
		"kit": "F: Cleaving Axe Swing (shatters armor & heavy guards)",
		"lore": "A rusted shell polished to a mirror sheen. He swings heavy iron to protect the tenderness he is convinced he lost."
	},
	{
		"id": "lion",
		"name": "The Cowardly Lion",
		"role": "Fear & Stagger · Courage",
		"kit": "F: Primal Roar Shockwave (fears & knocks back foes)",
		"lore": "Snared by doubt in a thorny thicket. His roar shakes the very bravest illusions when he stands between danger and his friends."
	},
	{
		"id": "toto",
		"name": "Toto",
		"role": "Wayfinder & Scout · Loyalty",
		"kit": "F: Fierce Bark (reveals secrets & alerts party; enemies ignore him)",
		"lore": "Small, fearless Cairn Terrier who sees straight through curtains, holograms, and gilded lies."
	},
]

func _ready() -> void:
	if DisplayServer.get_name() not in ["headless", "Dummy"]:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_allure_multiplier() -> float:
	var eq_d := str(equipped_outfits.get("dorothy", "dorothy_gingham"))
	if eq_d == "dorothy_sovereign":
		return 1.40
	if eq_d == "dorothy_velvet":
		return 1.25
	return 1.0

func has_whip_mastery() -> bool:
	return ("dorothy_whip_plus" in owned_items) or (str(equipped_outfits.get("dorothy", "")) == "dorothy_whip_plus")

func add_desire(amount: int, reason: String = "") -> void:
	desire_fragments += amount
	allure = clampf(allure + float(amount) * 0.65 * get_allure_multiplier(), 0.0, 100.0)
	desire_gained.emit(amount, reason)
	state_changed.emit()

func take_damage(amount: int = 1) -> void:
	hp = maxi(1, hp - amount)
	state_changed.emit()

func heal_full() -> void:
	hp = max_hp
	state_changed.emit()

func unlock_memory(mem_id: String) -> bool:
	if mem_id in unlocked_memories:
		return false
	unlocked_memories.append(mem_id)
	var entry: Dictionary = MEMORY_CATALOG.get(mem_id, {"title": mem_id})
	add_desire(10, "Memory: %s" % str(entry.get("title", mem_id)))
	heal_full()
	memory_unlocked.emit(mem_id, str(entry.get("title", mem_id)))
	state_changed.emit()
	return true

func open_chest(chest_id: String, reward: int = 15) -> bool:
	if chest_id in opened_chests:
		return false
	opened_chests.append(chest_id)
	add_desire(reward, "Gilded Chest")
	return true

func set_current_location(scene_path: String, chapter_label: String) -> void:
	if scene_path != "":
		current_scene_path = scene_path
	if chapter_label != "":
		current_chapter = chapter_label
	call_deferred("reapply_all_outfits")
	state_changed.emit()

func reapply_all_outfits() -> void:
	for char_id in equipped_outfits.keys():
		var iid := str(equipped_outfits[char_id])
		var catalog: Array = SHOP_CATALOG.get(char_id, [])
		for it in catalog:
			if str(it.get("id", "")) == iid:
				if char_id in ["dorothy", "scarecrow", "tinman", "lion", "toto"] or not iid.ends_with("_classic"):
					apply_outfit_to_world(char_id, it.get("tint", Color.WHITE), iid)
				break

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot, 1, MAX_SLOTS)]

func save_slot(slot: int) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var cur := get_tree().current_scene
	if cur and cur.scene_file_path != "":
		current_scene_path = cur.scene_file_path
	var payload := {
		"slot": slot,
		"scene_path": current_scene_path,
		"chapter": current_chapter,
		"desire_fragments": desire_fragments,
		"hp": hp,
		"allure": allure,
		"unlocked_memories": unlocked_memories,
		"opened_chests": opened_chests,
		"owned_items": owned_items,
		"equipped_outfits": equipped_outfits,
		"difficulty": difficulty,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	state_changed.emit()
	return true

func get_slot_info(slot: int) -> Dictionary:
	var p := _slot_path(slot)
	if not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed
	return {}

func load_slot(slot: int) -> bool:
	var info := get_slot_info(slot)
	if info.is_empty():
		return false
	desire_fragments = int(info.get("desire_fragments", 0))
	hp = clampi(int(info.get("hp", max_hp)), 1, max_hp)
	allure = clampf(float(info.get("allure", 35.0)), 0.0, 100.0)
	unlocked_memories.clear()
	for m in info.get("unlocked_memories", []):
		unlocked_memories.append(str(m))
	opened_chests.clear()
	for c in info.get("opened_chests", []):
		opened_chests.append(str(c))
	if info.has("owned_items") and info["owned_items"] is Array:
		owned_items.clear()
		for oi in info["owned_items"]:
			owned_items.append(str(oi))
	if info.has("equipped_outfits") and info["equipped_outfits"] is Dictionary:
		for k in info["equipped_outfits"].keys():
			equipped_outfits[str(k)] = str(info["equipped_outfits"][k])
	if info.has("difficulty"):
		difficulty = str(info.get("difficulty", "standard"))
	current_scene_path = str(info.get("scene_path", "res://regions/kansas/farmyard.tscn"))
	current_chapter = str(info.get("chapter", "Act 0 · Kansas"))
	state_changed.emit()
	get_tree().paused = false
	var lt := get_node_or_null("/root/LevelTransition")
	if lt and lt.has_method("go_to"):
		lt.go_to(current_scene_path, "Returning to %s…" % current_chapter, current_chapter)
	else:
		get_tree().change_scene_to_file(current_scene_path)
	return true

func delete_slot(slot: int) -> void:
	var p := _slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	state_changed.emit()

func has_any_save() -> bool:
	for s in range(1, MAX_SLOTS + 1):
		if not get_slot_info(s).is_empty():
			return true
	return false

func buy_and_equip(char_id: String, item_id: String) -> bool:
	var catalog: Array = SHOP_CATALOG.get(char_id, [])
	var item: Dictionary = {}
	for it in catalog:
		if str(it.get("id", "")) == item_id:
			item = it
			break
	if item.is_empty():
		return false
	var cost: int = int(item.get("cost", 0))
	if item_id not in owned_items:
		if desire_fragments < cost:
			return false
		desire_fragments -= cost
		owned_items.append(item_id)
	equipped_outfits[char_id] = item_id
	apply_outfit_to_world(char_id, item.get("tint", Color.WHITE), item_id)
	state_changed.emit()
	return true

func apply_outfit_to_world(char_id: String, tint: Color, item_id: String = "") -> void:
	var target: Node = null
	if char_id == "dorothy":
		target = get_tree().get_first_node_in_group("player")
	elif char_id == "toto":
		target = get_tree().get_first_node_in_group("toto")
	else:
		for n in get_tree().get_nodes_in_group("companions"):
			if char_id in n.name.to_lower():
				target = n
				break
	if target == null:
		return
	var resolved_id := item_id if item_id != "" else str(equipped_outfits.get(char_id, ""))
	var body_vis := target.get_node_or_null("Visual/Body")
	if body_vis and body_vis.has_method("set_outfit"):
		body_vis.call("set_outfit", resolved_id)
		return
	if target.has_method("set_outfit"):
		target.call("set_outfit", resolved_id)
		return
	for mi in target.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m and m.material_override is StandardMaterial3D:
			var dup := (m.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = dup.albedo_color.lerp(tint, 0.58)
			m.material_override = dup
