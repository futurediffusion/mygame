extends Node

const SAVE_PATH := "user://saves/"
const CURRENT := "slot_01.json"

func save_dict(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var path := SAVE_PATH + CURRENT
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo abrir save")
		return
	var text := JSON.stringify(data, "	")
	var bytes := text.to_utf8_buffer().compress(FileAccess.COMPRESSION_ZSTD)
	f.store_buffer(bytes)
	f.flush()
	f.close()

func load_dict() -> Dictionary:
	var path := SAVE_PATH + CURRENT
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir save")
		return {}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	var text := ""
	if bytes.is_empty():
		text = "{}"
	else:
		var decompressed := bytes.decompress_dynamic(FileAccess.COMPRESSION_ZSTD, bytes.size())
		if decompressed.is_empty() and bytes.size() > 0:
			text = bytes.get_string_from_utf8()
		else:
			text = decompressed.get_string_from_utf8()
	var res: Variant = JSON.parse_string(text)
	return res if typeof(res) == TYPE_DICTIONARY else {}
