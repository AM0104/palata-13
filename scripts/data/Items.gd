class_name Items
extends RefCounted
## База предметов «ПАЛАТА 13»: названия, описания, иконки, применение.

const DB := {
	"key_ward": {
		"name": "Ключ от палат",
		"desc": "Длинный ключ с биркой «ПАЛАТЫ А–Г». На бирке чей-то палец стёр краску до металла.",
		"icon": "key_hospital", "kind": "key",
	},
	"key_pharmacy": {
		"name": "Ключ аптеки",
		"desc": "Тяжёлый ключ от аптечного склада. Пахнет камфорой и пылью.",
		"icon": "key_hospital", "kind": "key",
	},
	"key_morgue": {
		"name": "Ключ морга",
		"desc": "Ключ с биркой «МОРГ». Холодный, будто его только что достали из ящика.",
		"icon": "key_hospital", "kind": "key",
	},
	"key_gate": {
		"name": "Ключ от входной двери",
		"desc": "Массивный ключ от главного входа. На кольце — обрывок красно-белой ленты.",
		"icon": "key_hospital", "kind": "key",
	},
	"fuse": {
		"name": "Предохранитель",
		"desc": "Керамический предохранитель на 16 ампер. Внутри целая нить — редкость для этой больницы.",
		"icon": "fuse", "kind": "quest",
	},
	"badge": {
		"name": "Бейдж матери",
		"desc": "«Соколова Ирина А., медсестра, отделение 13». Фотография выцвела, но улыбка ещё читается.",
		"icon": "badge", "kind": "quest",
	},
	"medkit": {
		"name": "Аптечка",
		"desc": "Бинт, жгут и ампула обезболивающего. Восстанавливает здоровье.",
		"icon": "medkit", "kind": "heal", "heal": 4,
	},
	"vial": {
		"name": "Успокоительное",
		"desc": "Мутная ампула с надписью «для пациентов 13-й». Руки перестают дрожать.",
		"icon": "vial", "kind": "heal", "heal": 2,
	},
	"battery": {
		"name": "Батарейка",
		"desc": "Квадратная батарейка для фонаря. Восстанавливает 45% заряда.",
		"icon": "battery", "kind": "lamp", "lamp": 45,
	},
	"inhaler": {
		"name": "Ингалятор",
		"desc": "Больничный ингалятор с треснувшим мундштуком. Возвращает 55% воздуха.",
		"icon": "inhaler", "kind": "air", "air": 55,
	},
	"note": {
		"name": "Записка",
		"desc": "Клочок бумаги с чужим почерком.",
		"icon": "note", "kind": "quest",
	},
}

const ORDER := [
	"key_ward", "key_pharmacy", "key_morgue", "key_gate", "fuse", "badge",
	"medkit", "vial", "battery", "inhaler", "note",
]


static func get_item(id: String) -> Dictionary:
	return DB.get(id, {"name": id, "desc": "Неизвестный предмет.", "icon": "note", "kind": "quest"})


static func name_of(id: String) -> String:
	return str(get_item(id).get("name", id))


static func desc_of(id: String) -> String:
	return str(get_item(id).get("desc", ""))


static func icon_of(id: String) -> Texture2D:
	return Art.icon(str(get_item(id).get("icon", "note")))


static func is_usable(id: String) -> bool:
	return str(get_item(id).get("kind", "quest")) in ["heal", "lamp", "air"]


static func heal_amount(id: String) -> int:
	return int(get_item(id).get("heal", 0))


static func lamp_amount(id: String) -> int:
	return int(get_item(id).get("lamp", 0))


static func air_amount(id: String) -> int:
	return int(get_item(id).get("air", 0))
