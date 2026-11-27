@tool
extends EditorPlugin

var dock: VBoxContainer
var history: RichTextLabel
var prompt: TextEdit

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "FORGE AI"
	var heading := Label.new()
	heading.text = "ИИ-помощник • FORGE"
	dock.add_child(heading)
	history = RichTextLabel.new()
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.text = "Подключение провайдера пока не настроено."
	dock.add_child(history)
	prompt = TextEdit.new()
	prompt.placeholder_text = "Опишите задачу для игры…"
	prompt.custom_minimum_size.y = 100
	dock.add_child(prompt)
	var send := Button.new()
	send.text = "Отправить"
	send.pressed.connect(_submit)
	dock.add_child(send)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _submit() -> void:
	if prompt.text.strip_edges().is_empty():
		return
	history.add_text("\nВы: " + prompt.text + "\nИИ: API ещё не подключён.")
	prompt.clear()

func _exit_tree() -> void:
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()
