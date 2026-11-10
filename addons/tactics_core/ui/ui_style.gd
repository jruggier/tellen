class_name UiStyle
extends RefCounted
## Shared look for battle UI panels. Games can restyle through their theme;
## these are the framework defaults.

const PANEL_BG: Color = Color(0.07, 0.08, 0.12, 0.92)
const PANEL_BORDER: Color = Color(0.85, 0.75, 0.45, 0.9)
const HIGHLIGHT: Color = Color(0.95, 0.8, 0.35, 0.28)
const TEXT_DIM: Color = Color(0.72, 0.74, 0.8)
const GOOD: Color = Color(0.45, 0.95, 0.55)
const WARN: Color = Color(1.0, 0.75, 0.3)
const BAD: Color = Color(1.0, 0.42, 0.38)


## A rounded dark panel style with a thin gold border.
static func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


## A label with [param size] font size and optional color.
static func label(text: String, size: int = 26, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result
