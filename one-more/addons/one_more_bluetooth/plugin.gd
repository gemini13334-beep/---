@tool
extends EditorPlugin

var bluetooth_export: EditorExportPlugin

func _enter_tree() -> void:
	bluetooth_export = BluetoothExport.new()
	add_export_plugin(bluetooth_export)

func _exit_tree() -> void:
	remove_export_plugin(bluetooth_export)

class BluetoothExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "OneMoreBluetooth"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["one_more_bluetooth/OneMoreBluetooth.aar"])
