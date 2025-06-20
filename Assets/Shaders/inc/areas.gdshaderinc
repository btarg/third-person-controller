bool point_in_circle(vec2 point, float r) {
	return length(point) <= r;
}

bool point_in_cone(vec3 point, float r, float angle, vec3 direction) {
	float distance = length(point);
	if (distance > r) {
		return false;
	}

	if (distance < 0.001) {
		return true; // At origin
	}

	vec3 normalized_point = normalize(point);
	float dot_product = dot(normalized_point, normalize(direction));

	// Clamp to avoid floating point errors
	dot_product = clamp(dot_product, -1.0, 1.0);

	float point_angle = acos(dot_product);
	return point_angle <= (angle * 0.5);
}

bool point_in_line(vec3 point, float length, float width, vec3 direction) {
	vec3 line_dir_2d = normalize(vec3(direction.x, 0.0, direction.z));
	vec3 perpendicular = vec3(-line_dir_2d.z, 0.0, line_dir_2d.x);

	float along_line = dot(point, line_dir_2d);
	float across_line = dot(point, perpendicular);

	bool within_length = along_line >= 0.0 && along_line <= length;
	bool within_width = abs(across_line) <= width * 0.5;

	return within_length && within_width;
}

float line_distance_field(vec3 point, float length, float width, vec3 direction) {
	vec3 line_dir_2d = normalize(vec3(direction.x, 0.0, direction.z));
	vec3 perpendicular = vec3(-line_dir_2d.z, 0.0, line_dir_2d.x);

	float along_line = dot(point, line_dir_2d);
	float across_line = dot(point, perpendicular);

	// Distance to rectangle edges
	float dist_along = max(max(-along_line, along_line - length), 0.0);
	float dist_across = max(abs(across_line) - width * 0.5, 0.0);

	return sqrt(dist_along * dist_along + dist_across * dist_across);
}
