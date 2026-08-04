class_name PlayerStats
extends Node

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)

@export_range(1.0, 999.0, 1.0) var max_health := 100.0
@export_range(1.0, 999.0, 1.0) var max_stamina := 100.0
@export_range(1.0, 999.0, 1.0) var max_mana := 100.0

var health := 100.0
var stamina := 100.0
var mana := 100.0
var invulnerable := false
var stamina_regeneration_enabled := true
var mana_regeneration_enabled := true


func _ready() -> void:
    health = clampf(health, 0.0, max_health)
    stamina = clampf(stamina, 0.0, max_stamina)
    mana = clampf(mana, 0.0, max_mana)
    _emit_all()


func set_health(value: float) -> void:
    var next := clampf(value, 0.0, max_health)
    if is_equal_approx(next, health):
        return
    health = next
    health_changed.emit(health, max_health)


func change_health(delta: float) -> void:
    set_health(health + delta)


func set_stamina(value: float) -> void:
    var next := clampf(value, 0.0, max_stamina)
    if is_equal_approx(next, stamina):
        return
    stamina = next
    stamina_changed.emit(stamina, max_stamina)


func change_stamina(delta: float) -> void:
    set_stamina(stamina + delta)


func set_mana(value: float) -> void:
    var next := clampf(value, 0.0, max_mana)
    if is_equal_approx(next, mana):
        return
    mana = next
    mana_changed.emit(mana, max_mana)


func change_mana(delta: float) -> void:
    set_mana(mana + delta)


func set_max_health(value: float, preserve_ratio := false) -> void:
    var previous_max := max_health
    max_health = maxf(1.0, value)
    if preserve_ratio and previous_max > 0.0:
        health = clampf(health / previous_max * max_health, 0.0, max_health)
    else:
        health = clampf(health, 0.0, max_health)
    health_changed.emit(health, max_health)


func set_max_stamina(value: float, preserve_ratio := false) -> void:
    var previous_max := max_stamina
    max_stamina = maxf(1.0, value)
    if preserve_ratio and previous_max > 0.0:
        stamina = clampf(stamina / previous_max * max_stamina, 0.0, max_stamina)
    else:
        stamina = clampf(stamina, 0.0, max_stamina)
    stamina_changed.emit(stamina, max_stamina)


func set_max_mana(value: float, preserve_ratio := false) -> void:
    var previous_max := max_mana
    max_mana = maxf(1.0, value)
    if preserve_ratio and previous_max > 0.0:
        mana = clampf(mana / previous_max * max_mana, 0.0, max_mana)
    else:
        mana = clampf(mana, 0.0, max_mana)
    mana_changed.emit(mana, max_mana)


func restore_all() -> void:
    set_health(max_health)
    set_stamina(max_stamina)
    set_mana(max_mana)


func _emit_all() -> void:
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina, max_stamina)
    mana_changed.emit(mana, max_mana)
