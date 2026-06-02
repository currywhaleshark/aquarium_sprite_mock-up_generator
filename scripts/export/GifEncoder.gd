class_name GifEncoder
extends RefCounted

# Minimal self-contained animated GIF89a encoder. Godot has no built-in GIF
# export, so we build a global palette via median cut (255 colours + one
# transparent index), map frames to indices with 1-bit transparency, and
# LZW-compress each frame. Disposal "restore to background" keeps transparent
# pixels from accumulating between frames.

const ALPHA_CUTOFF := 128
const MAX_COLORS := 255  # index 0 is reserved for transparency

# images: Array[Image] (RGBA8, identical size). delay_centiseconds is the per
# frame delay in 1/100 s. loop_count 0 means loop forever.
static func encode_to_file(images: Array, delay_centiseconds: int, output_path: String, loop_count: int = 0) -> int:
	if images.is_empty():
		return ERR_INVALID_DATA
	var first: Image = images[0]
	var width := first.get_width()
	var height := first.get_height()
	if width <= 0 or height <= 0:
		return ERR_INVALID_DATA

	var palette := _build_palette(images)
	var colors_r: PackedInt32Array = palette["r"]
	var colors_g: PackedInt32Array = palette["g"]
	var colors_b: PackedInt32Array = palette["b"]
	var color_table: PackedByteArray = palette["table"]

	var out := PackedByteArray()
	out.append_array("GIF89a".to_utf8_buffer())
	# Logical screen descriptor.
	_append_u16(out, width)
	_append_u16(out, height)
	out.append(0xF7)  # global color table, 256 entries, 8-bit colour resolution
	out.append(0)     # background colour index (transparent)
	out.append(0)     # pixel aspect ratio
	out.append_array(color_table)

	# Netscape looping extension.
	out.append(0x21)
	out.append(0xFF)
	out.append(0x0B)
	out.append_array("NETSCAPE2.0".to_utf8_buffer())
	out.append(0x03)
	out.append(0x01)
	_append_u16(out, clampi(loop_count, 0, 65535))
	out.append(0x00)

	var delay := maxi(delay_centiseconds, 2)
	var cache := {}
	for image in images:
		var indices := _map_frame(image, colors_r, colors_g, colors_b, cache)

		# Graphic control extension: disposal 2 (restore bg), transparency on.
		out.append(0x21)
		out.append(0xF9)
		out.append(0x04)
		out.append(0x09)
		_append_u16(out, delay)
		out.append(0x00)  # transparent colour index
		out.append(0x00)

		# Image descriptor (no local colour table).
		out.append(0x2C)
		_append_u16(out, 0)
		_append_u16(out, 0)
		_append_u16(out, width)
		_append_u16(out, height)
		out.append(0x00)

		out.append(0x08)  # LZW minimum code size for a 256-entry table
		var lzw := _lzw_compress(indices, 8)
		_append_sub_blocks(out, lzw)

	out.append(0x3B)  # trailer

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(out)
	file.close()
	return OK

static func _append_u16(out: PackedByteArray, value: int) -> void:
	out.append(value & 0xFF)
	out.append((value >> 8) & 0xFF)

# --- Palette (median cut) -------------------------------------------------

static func _build_palette(images: Array) -> Dictionary:
	var counts := {}
	for image_any in images:
		var image: Image = image_any
		var w := image.get_width()
		var h := image.get_height()
		for y in h:
			for x in w:
				var c := image.get_pixel(x, y)
				if c.a * 255.0 < float(ALPHA_CUTOFF):
					continue
				var key := (int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)
				counts[key] = int(counts.get(key, 0)) + 1

	var unique: Array = counts.keys()
	var boxes: Array = []
	if not unique.is_empty():
		boxes.append(unique)

	# Split the box with the widest channel range until we reach MAX_COLORS.
	while boxes.size() < MAX_COLORS:
		var target_index := _widest_box_index(boxes)
		if target_index < 0:
			break
		var box: Array = boxes[target_index]
		var channel := _widest_channel(box)
		box.sort_custom(func(a: int, b: int) -> bool:
			return _channel_value(a, channel) < _channel_value(b, channel))
		var mid := box.size() / 2
		var lower := box.slice(0, mid)
		var upper := box.slice(mid)
		boxes.remove_at(target_index)
		boxes.append(lower)
		boxes.append(upper)

	var colors_r := PackedInt32Array()
	var colors_g := PackedInt32Array()
	var colors_b := PackedInt32Array()
	var table := PackedByteArray()
	table.append(0)  # index 0: transparent
	table.append(0)
	table.append(0)
	for box in boxes:
		var avg := _average_color(box, counts)
		colors_r.append(avg.x)
		colors_g.append(avg.y)
		colors_b.append(avg.z)
		table.append(avg.x)
		table.append(avg.y)
		table.append(avg.z)
	# Pad the global colour table to a full 256 entries.
	while table.size() < 256 * 3:
		table.append(0)

	return {"r": colors_r, "g": colors_g, "b": colors_b, "table": table}

static func _widest_box_index(boxes: Array) -> int:
	var best_index := -1
	var best_range := 0
	for i in boxes.size():
		var box: Array = boxes[i]
		if box.size() < 2:
			continue
		var r := _box_range(box)
		if r > best_range:
			best_range = r
			best_index = i
	return best_index

static func _box_range(box: Array) -> int:
	var min_r := 255
	var min_g := 255
	var min_b := 255
	var max_r := 0
	var max_g := 0
	var max_b := 0
	for key_any in box:
		var key := int(key_any)
		var r := (key >> 16) & 0xFF
		var g := (key >> 8) & 0xFF
		var b := key & 0xFF
		min_r = mini(min_r, r)
		min_g = mini(min_g, g)
		min_b = mini(min_b, b)
		max_r = maxi(max_r, r)
		max_g = maxi(max_g, g)
		max_b = maxi(max_b, b)
	return maxi(max_r - min_r, maxi(max_g - min_g, max_b - min_b))

static func _widest_channel(box: Array) -> int:
	var min_r := 255
	var min_g := 255
	var min_b := 255
	var max_r := 0
	var max_g := 0
	var max_b := 0
	for key_any in box:
		var key := int(key_any)
		var r := (key >> 16) & 0xFF
		var g := (key >> 8) & 0xFF
		var b := key & 0xFF
		min_r = mini(min_r, r)
		min_g = mini(min_g, g)
		min_b = mini(min_b, b)
		max_r = maxi(max_r, r)
		max_g = maxi(max_g, g)
		max_b = maxi(max_b, b)
	var dr := max_r - min_r
	var dg := max_g - min_g
	var db := max_b - min_b
	if dr >= dg and dr >= db:
		return 0
	if dg >= db:
		return 1
	return 2

static func _channel_value(key: int, channel: int) -> int:
	match channel:
		0:
			return (key >> 16) & 0xFF
		1:
			return (key >> 8) & 0xFF
		_:
			return key & 0xFF

static func _average_color(box: Array, counts: Dictionary) -> Vector3i:
	var total := 0
	var sum_r := 0
	var sum_g := 0
	var sum_b := 0
	for key_any in box:
		var key := int(key_any)
		var weight := int(counts.get(key, 1))
		sum_r += ((key >> 16) & 0xFF) * weight
		sum_g += ((key >> 8) & 0xFF) * weight
		sum_b += (key & 0xFF) * weight
		total += weight
	if total == 0:
		return Vector3i(0, 0, 0)
	return Vector3i(sum_r / total, sum_g / total, sum_b / total)

# --- Frame mapping --------------------------------------------------------

static func _map_frame(image: Image, colors_r: PackedInt32Array, colors_g: PackedInt32Array, colors_b: PackedInt32Array, cache: Dictionary) -> PackedByteArray:
	var w := image.get_width()
	var h := image.get_height()
	var indices := PackedByteArray()
	indices.resize(w * h)
	var pos := 0
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			if c.a * 255.0 < float(ALPHA_CUTOFF):
				indices[pos] = 0
			else:
				var r := int(c.r * 255.0)
				var g := int(c.g * 255.0)
				var b := int(c.b * 255.0)
				var key := (r << 16) | (g << 8) | b
				var idx: int = cache.get(key, -1)
				if idx < 0:
					idx = _nearest_index(r, g, b, colors_r, colors_g, colors_b)
					cache[key] = idx
				indices[pos] = idx
			pos += 1
	return indices

static func _nearest_index(r: int, g: int, b: int, colors_r: PackedInt32Array, colors_g: PackedInt32Array, colors_b: PackedInt32Array) -> int:
	var best := 1
	var best_dist := 1 << 30
	for i in colors_r.size():
		var dr := r - colors_r[i]
		var dg := g - colors_g[i]
		var db := b - colors_b[i]
		var dist := dr * dr + dg * dg + db * db
		if dist < best_dist:
			best_dist = dist
			best = i + 1  # palette colours start at index 1
	return best

# --- LZW ------------------------------------------------------------------

# Produces a flat LZW byte stream. Codes are recorded with the bit width in
# effect when they are emitted (GDScript lambdas capture by value, so we collect
# code/width pairs and bit-pack them in a second pass rather than via a closure).
static func _lzw_compress(indices: PackedByteArray, min_code_size: int) -> PackedByteArray:
	var clear_code := 1 << min_code_size
	var end_code := clear_code + 1
	var code_size := min_code_size + 1
	var next_code := end_code + 1
	var dict := {}

	var codes := PackedInt32Array()
	var widths := PackedByteArray()
	codes.append(clear_code)
	widths.append(code_size)

	if indices.is_empty():
		codes.append(end_code)
		widths.append(code_size)
		return _pack_codes(codes, widths)

	var prefix := int(indices[0])
	for i in range(1, indices.size()):
		var k := int(indices[i])
		var key := (prefix << 8) | k
		if dict.has(key):
			prefix = int(dict[key])
		else:
			codes.append(prefix)
			widths.append(code_size)
			if next_code == 4096:
				# Dictionary full: emit a clear at the current width, then reset.
				codes.append(clear_code)
				widths.append(code_size)
				dict.clear()
				code_size = min_code_size + 1
				next_code = end_code + 1
			else:
				# Grow the code width BEFORE assigning the new code, so the decoder
				# (which learns each entry one step later) stays in sync.
				if next_code >= (1 << code_size) and code_size < 12:
					code_size += 1
				dict[key] = next_code
				next_code += 1
			prefix = k

	codes.append(prefix)
	widths.append(code_size)
	codes.append(end_code)
	widths.append(code_size)
	return _pack_codes(codes, widths)

static func _pack_codes(codes: PackedInt32Array, widths: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var bit_buffer := 0
	var bit_count := 0
	for i in codes.size():
		bit_buffer |= codes[i] << bit_count
		bit_count += int(widths[i])
		while bit_count >= 8:
			out.append(bit_buffer & 0xFF)
			bit_buffer >>= 8
			bit_count -= 8
	if bit_count > 0:
		out.append(bit_buffer & 0xFF)
	return out

static func _append_sub_blocks(out: PackedByteArray, data: PackedByteArray) -> void:
	var offset := 0
	while offset < data.size():
		var chunk := mini(255, data.size() - offset)
		out.append(chunk)
		out.append_array(data.slice(offset, offset + chunk))
		offset += chunk
	out.append(0x00)  # block terminator
