extends Node

const GifEncoderScript := preload("res://scripts/export/GifEncoder.gd")

func _ready() -> void:
	var frames := [_make_frame(Color(0.9, 0.2, 0.2, 1.0)), _make_frame(Color(0.2, 0.4, 0.9, 1.0))]
	var dir := "res://exports/test_results"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/gif_encoder.gif" % dir
	var err := GifEncoderScript.encode_to_file(frames, 8, path)
	assert(err == OK)

	var bytes := FileAccess.get_file_as_bytes(path)
	assert(bytes.size() > 800)  # header + 256-entry table + two frames
	# GIF89a header.
	assert(bytes.slice(0, 6).get_string_from_ascii() == "GIF89a")
	# Logical screen size matches the frames (8 x 8, little-endian).
	assert(bytes[6] == 8 and bytes[7] == 0)
	assert(bytes[8] == 8 and bytes[9] == 0)
	# Trailer byte.
	assert(bytes[bytes.size() - 1] == 0x3B)
	# Netscape looping extension present (unique ASCII signature).
	assert(_contains_ascii(bytes, "NETSCAPE2.0"))

	# Empty input is rejected rather than producing a broken file.
	assert(GifEncoderScript.encode_to_file([], 8, "%s/empty.gif" % dir) == ERR_INVALID_DATA)

	# Large, busy frame to exercise LZW code-size growth and the 4096 dictionary
	# reset (small frames never reach those paths). A reference PNG is saved so an
	# external decoder can confirm the GIF did not desync.
	var big := _make_busy_frame(128, 128)
	big.save_png("%s/gif_large_ref.png" % dir)
	assert(GifEncoderScript.encode_to_file([big], 8, "%s/gif_large.gif" % dir) == OK)

	var file := FileAccess.open("%s/gif_encoder.ok" % dir, FileAccess.WRITE)
	file.store_string("gif encoder verified")
	file.close()
	print("GIF_ENCODER_TEST_OK")
	get_tree().quit(0)

func _make_frame(fill: Color) -> Image:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	# A transparent border pixel exercises the 1-bit transparency path.
	image.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.0))
	return image

func _make_busy_frame(w: int, h: int) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			# Transparent border, busy interior with many short colour runs.
			if x < 8 or y < 8 or x >= w - 8 or y >= h - 8:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var r := float((x * 5 + y * 3) % 64) / 63.0
				var g := float((x * 2 + y * 7) % 48) / 47.0
				var b := float((x * 11 + y * 13) % 80) / 79.0
				image.set_pixel(x, y, Color(r, g, b, 1.0))
	return image

func _contains_ascii(bytes: PackedByteArray, needle: String) -> bool:
	var probe := needle.to_ascii_buffer()
	for i in range(bytes.size() - probe.size() + 1):
		var matched := true
		for j in probe.size():
			if bytes[i + j] != probe[j]:
				matched = false
				break
		if matched:
			return true
	return false
