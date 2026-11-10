class_name WorldText
extends RefCounted
## Draws crisp text inside the zoomed battle world.
##
## World space is in source pixels and the camera zooms in, so text drawn
## at world size would be rasterized small and then magnified (blurry).
## These helpers draw at full on-screen size under an inverse scale instead.


## The project theme font, or Godot's fallback font.
static func default_font() -> Font:
	var project_theme: Theme = ThemeDB.get_project_theme()
	if project_theme != null and project_theme.default_font != null:
		return project_theme.default_font
	return ThemeDB.fallback_font


## Draws [param text] centered on [param center] (world coordinates).
## [param world_size] is the text height in world pixels; [param zoom] is
## the camera zoom it will be shown at.
static func draw_centered(item: CanvasItem, center: Vector2, text: String, world_size: float, zoom: float,
		color: Color, outline_color: Color = Color.TRANSPARENT) -> void:
	var font: Font = default_font()
	var font_size: int = maxi(1, roundi(world_size * zoom))
	var inverse: float = 1.0 / zoom
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2(-width / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	item.draw_set_transform(center, 0.0, Vector2(inverse, inverse))
	if outline_color.a > 0.0:
		item.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, font_size / 6), outline_color)
	item.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
