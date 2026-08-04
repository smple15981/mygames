class_name OpenAssetLibrary
extends RefCounted

const FLOOR_ATLAS := "res://vendor/ninja-adventure/content/map/tileset_floor.png"
const VILLAGE_ATLAS := "res://vendor/ninja-adventure/content/map/tileset_village_abandoned.png"
const PLAYER_SHEET := "res://vendor/ninja-adventure/content/character/ninja_blue/sprite.png"
const PIG_SHEET := "res://vendor/ninja-adventure/content/character/pig/sprite.png"
const SHADOW_TEXTURE := "res://vendor/ninja-adventure/content/character/Shadow.png"

static var _warned_paths: Dictionary = {}


static func has_open_assets() -> bool:
    return ResourceLoader.exists(FLOOR_ATLAS) and ResourceLoader.exists(PLAYER_SHEET)


static func load_texture(primary_path: String, fallback_path: String = "") -> Texture2D:
    var primary := _load_texture_resource(primary_path)
    if primary != null:
        return primary

    _warn_once(primary_path)
    if fallback_path.is_empty():
        return null
    return _load_texture_resource(fallback_path)


static func _load_texture_resource(path: String) -> Texture2D:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var resource := ResourceLoader.load(path)
    return resource as Texture2D


static func _warn_once(path: String) -> void:
    if _warned_paths.has(path):
        return
    _warned_paths[path] = true
    push_warning(
        "Open asset is unavailable: %s. Run `git submodule update --init --recursive`; using local fallback when available."
        % path
    )
