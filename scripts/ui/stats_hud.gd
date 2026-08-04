class_name StatsHUD
extends PanelContainer

@onready var health_bar: ProgressBar = $Margin/Column/Health/Bar
@onready var health_value: Label = $Margin/Column/Health/Value
@onready var stamina_bar: ProgressBar = $Margin/Column/Stamina/Bar
@onready var stamina_value: Label = $Margin/Column/Stamina/Value
@onready var mana_bar: ProgressBar = $Margin/Column/Mana/Bar
@onready var mana_value: Label = $Margin/Column/Mana/Value
@onready var area: Label = $Margin/Column/Area

var stats: PlayerStats
var targets := Vector3(100.0, 100.0, 100.0)


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
    var weight := 1.0 - exp(-12.0 * delta)
    health_bar.value = lerpf(health_bar.value, targets.x, weight)
    stamina_bar.value = lerpf(stamina_bar.value, targets.y, weight)
    mana_bar.value = lerpf(mana_bar.value, targets.z, weight)


func bind(model: PlayerStats) -> void:
    _disconnect_stats()
    stats = model
    if stats == null:
        push_error("StatsHUD requires PlayerStats")
        return

    stats.health_changed.connect(_on_health)
    stats.stamina_changed.connect(_on_stamina)
    stats.mana_changed.connect(_on_mana)
    _on_health(stats.health, stats.max_health)
    _on_stamina(stats.stamina, stats.max_stamina)
    _on_mana(stats.mana, stats.max_mana)


func set_area_text(text: String) -> void:
    area.text = text


func set_modal_dimmed(dimmed: bool) -> void:
    modulate = Color(1.0, 1.0, 1.0, 0.55 if dimmed else 1.0)


func _disconnect_stats() -> void:
    if stats == null:
        return
    if stats.health_changed.is_connected(_on_health):
        stats.health_changed.disconnect(_on_health)
    if stats.stamina_changed.is_connected(_on_stamina):
        stats.stamina_changed.disconnect(_on_stamina)
    if stats.mana_changed.is_connected(_on_mana):
        stats.mana_changed.disconnect(_on_mana)


func _on_health(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    targets.x = current
    health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_stamina(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    targets.y = current
    stamina_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_mana(current: float, maximum: float) -> void:
    mana_bar.max_value = maximum
    targets.z = current
    mana_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
