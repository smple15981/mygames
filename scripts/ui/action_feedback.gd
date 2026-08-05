class_name ActionFeedback
extends Label

@export_range(0.2, 5.0, 0.1) var display_duration := 1.4

var _hide_timer: Timer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hide_timer = get_node_or_null("HideTimer") as Timer
    if _hide_timer == null:
        _hide_timer = Timer.new()
        _hide_timer.name = "HideTimer"
        _hide_timer.one_shot = true
        _hide_timer.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(_hide_timer)
    if not _hide_timer.timeout.is_connected(_on_hide_timer_timeout):
        _hide_timer.timeout.connect(_on_hide_timer_timeout)
    if text.is_empty():
        hide()


func show_message(message: String) -> void:
    if message.is_empty():
        hide()
        return
    text = message
    show()
    if _hide_timer != null:
        _hide_timer.start(display_duration)


func _on_hide_timer_timeout() -> void:
    hide()
