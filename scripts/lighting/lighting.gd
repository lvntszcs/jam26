class_name Lighting
extends RefCounted
## Helpers shared by everything that takes part in local illumination.


## An occluder shape covering a rectangle, for walls and closed doors.
static func rect_occluder(rect: Rect2) -> OccluderPolygon2D:
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	return polygon
