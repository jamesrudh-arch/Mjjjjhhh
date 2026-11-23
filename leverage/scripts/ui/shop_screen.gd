class_name ShopScreen
extends Control
## ShopScreen - buy weapons, ammo, armor, outfits, food. setup(shop_id):
## "pawn" (weapons/armor), "threads" (outfits), "quickmart" (consumables).

var shop_id := "pawn"
var _root: Control
var _body: VBoxContainer


const GOODS := {
        "pawn": [
                {"id": "pistol", "kind": "weapon", "price": 450, "label": "P9 Sidearm", "desc": "12-round sidearm. Clean serials."},
                {"id": "pistol2", "kind": "weapon", "price": 620, "label": "Kalvin Compact", "desc": "8 rounds, hits harder."},
                {"id": "smg", "kind": "weapon", "price": 1200, "label": "Vetch Ripper SMG", "desc": "30-round ripper. Loud reputation."},
                {"id": "ammo_pistol", "kind": "item", "price": 60, "label": "Pistol Ammo x24", "desc": "Box of 24."},
                {"id": "ammo_smg", "kind": "item", "price": 90, "label": "SMG Ammo x60", "desc": "Box of 60."},
                {"id": "vest", "kind": "armor", "price": 300, "label": "Street Vest", "desc": "+40 armor on wear."},
                {"id": "kevlar", "kind": "armor", "price": 750, "label": "Kestrel Kevlar", "desc": "+100 armor."},
        ],
        "threads": [
                {"id": "jacket", "kind": "outfit", "price": 180, "label": "Worker Jacket", "desc": "Old Quarter standard issue."},
                {"id": "suit", "kind": "outfit", "price": 500, "label": "Ledger Suit", "desc": "For meetings above your station."},
                {"id": "workwear", "kind": "outfit", "price": 120, "label": "Docks Workwear", "desc": "Blends into strike crowds."},
                {"id": "street", "kind": "outfit", "price": 90, "label": "Street Kit", "desc": "Neon Strip camouflage."},
        ],
        "quickmart": [
                {"id": "food_burger", "kind": "consumable", "price": 12, "label": "Char Burger", "desc": "+25 health."},
                {"id": "food_coffee", "kind": "consumable", "price": 8, "label": "Cinder Coffee", "desc": "+15 stamina, bitter."},
                {"id": "bandage", "kind": "consumable", "price": 25, "label": "Street Bandage", "desc": "+40 health."},
        ],
}


func setup(p_shop_id: String) -> void:
        shop_id = p_shop_id


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        _build()


func _build() -> void:
        add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.55)))
        var sheet := LvgTheme.make_panel()
        sheet.set_anchors_preset(Control.PRESET_CENTER)
        sheet.custom_minimum_size = Vector2(1500, 1000)
        add_child(sheet)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 14)
        sheet.add_child(v)
        var header := HBoxContainer.new()
        header.add_theme_constant_override("separation", 24)
        v.add_child(header)
        header.add_child(LvgTheme.make_display_label(_shop_title(), 60, LvgTheme.ACCENT))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        header.add_child(spacer)
        var money := LvgTheme.make_label("$%d" % GameState.money, 34, LvgTheme.ACCENT, true)
        header.add_child(money)
        var close := LvgTheme.make_button("LEAVE")
        close.pressed.connect(func(): _close())
        header.add_child(close)
        _body = VBoxContainer.new()
        _body.add_theme_constant_override("separation", 10)
        v.add_child(_body)
        for g in GOODS.get(shop_id, []):
                _add_good(g as Dictionary, money)


func _shop_title() -> String:
        match shop_id:
                "pawn": return "PAWN & BARREL"
                "threads": return "THREADS & THREADS"
                "quickmart": return "QUICKMART"
        return "SHOP"


func _add_good(g: Dictionary, money_label: Label) -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 16)
        var owned_txt := ""
        var price: int = int(g.get("price", 0))
        if g["kind"] == "weapon" and GameState.weapons_owned.has(g["id"]):
                owned_txt = "OWNED"
        elif g["kind"] == "outfit" and GameState.outfits_owned.has(g["id"]):
                owned_txt = "OWNED"
        row.add_child(LvgTheme.make_label(String(g["label"]), 26, LvgTheme.TEXT, true))
        row.add_child(LvgTheme.make_label(String(g["desc"]), 22, LvgTheme.TEXT_DIM))
        var price_l := LvgTheme.make_label("$%d" % price, 26, LvgTheme.ACCENT)
        row.add_child(price_l)
        if owned_txt == "":
                var buy := LvgTheme.make_button("BUY")
                buy.pressed.connect(func():
                        if GameState.money < price:
                                EventBus.notification_posted.emit("Not enough cash", "warn")
                                return
                        _purchase(g)
                        EventBus.notification_posted.emit("Bought " + String(g["label"]), "money")
                        money_label.text = "$%d" % GameState.money)
                row.add_child(buy)
        else:
                row.add_child(LvgTheme.make_label(owned_txt, 26, LvgTheme.SUCCESS))
        _body.add_child(row)


func _purchase(g: Dictionary) -> void:
        var kind: String = String(g["kind"])
        var id: String = String(g["id"])
        var price: int = int(g["price"])
        match kind:
                "weapon":
                        GameState.add_money(-price)
                        GameState.weapons_owned.append(id)
                        GameState.set_story_flag("first_firearm", true)
                        EventBus.item_purchased.emit(id, price)
                "armor":
                        GameState.add_money(-price)
                        GameState.add_item(id)
                        EventBus.item_purchased.emit(id, price)
                "item":
                        GameState.add_money(-price)
                        GameState.add_item(id)
                        EventBus.item_purchased.emit(id, price)
                "outfit":
                        GameState.add_money(-price)
                        GameState.outfits_owned.append(id)
                        EventBus.item_purchased.emit(id, price)
                "consumable":
                        GameState.add_money(-price)
                        GameState.add_item(id)
                        EventBus.item_purchased.emit(id, price)
                        # quickmart consumables apply instantly
                        match id:
                                "food_burger":
                                        var p1 := get_tree().get_first_node_in_group("player")
                                        if p1 and p1.has_method("heal"):
                                                p1.heal(25.0)
                                "food_coffee":
                                        GameState.stamina = min(GameState.max_stamina, GameState.stamina + 15.0)
                                "bandage":
                                        var p2 := get_tree().get_first_node_in_group("player")
                                        if p2 and p2.has_method("heal"):
                                                p2.heal(40.0)


func _close() -> void:
        var hud_layer := get_parent()
        if hud_layer and hud_layer.has_method("_close_panels"):
                hud_layer._close_panels()
        else:
                queue_free()
