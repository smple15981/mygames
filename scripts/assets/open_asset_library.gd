class_name OpenAssetLibrary
extends RefCounted

const FLOOR_ATLAS := "res://vendor/ninja-adventure/content/map/tileset_floor.png"
const VILLAGE_ATLAS := "res://vendor/ninja-adventure/content/map/tileset_village_abandoned.png"
const PLAYER_SHEET := "res://vendor/ninja-adventure/content/character/ninja_blue/sprite.png"
const PIG_SHEET := "res://vendor/ninja-adventure/content/character/pig/pig.png"
const SHADOW_TEXTURE := "res://vendor/ninja-adventure/content/character/Shadow.png"
const VENDOR_PREFIX := "res://vendor/"

static var _warned_paths: Dictionary = {}
static var _texture_cache: Dictionary = {}


static func has_open_assets() -> bool:
    return texture_exists(FLOOR_ATLAS) and texture_exists(PLAYER_SHEET)


static func texture_exists(path: String) -> bool:
    if path.begins_with(VENDOR_PREFIX):
        return FileAccess.file_exists(path)
    return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func load_texture(primary_path: String, fallback_path: String = "") -> Texture2D:
    var primary := _load_texture_resource(primary_path)
    if primary != null:
        return primary

    _warn_once(primary_path)
    if fallback_path.is_empty():
        return null
    return _load_texture_resource(fallback_path)


static func _load_texture_resource(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if _texture_cache.has(path):
        return _texture_cache[path] as Texture2D

    var texture: Texture2D = null
    if path.begins_with(VENDOR_PREFIX):
        texture = _load_raw_image(path)
    elif ResourceLoader.exists(path):
        texture = ResourceLoader.load(path) as Texture2D
    elif FileAccess.file_exists(path):
        texture = _load_raw_image(path)

    if texture != null:
        _texture_cache[path] = texture
    return texture


static func _load_raw_image(path: String) -> Texture2D:
    if not FileAccess.file_exists(path):
        return null
    var image := Image.new()
    var load_error := image.load(ProjectSettings.globalize_path(path))
    if load_error != OK:
        push_warning("Failed to decode open image %s (error %s)." % [path, load_error])
        return null
    return ImageTexture.create_from_image(image)


static func _warn_once(path: String) -> void:
    if _warned_paths.has(path):
        return
    _warned_paths[path] = true
    push_warning(
        "Open asset is unavailable: %s. Run `git submodule update --init --recursive`; using local fallback when available."
        % path
    )
