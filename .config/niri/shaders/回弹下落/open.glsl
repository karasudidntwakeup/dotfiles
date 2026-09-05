
            // 窗口打开的动画：从屏幕顶部下落且伴有回弹效果

            vec4 open_color(vec3 coords_geo, vec3 size_geo) {
                float p = niri_progress;
                float y_offset = (1.0 - p) * 0.3;
                vec3 moved_coords = vec3(coords_geo.x, coords_geo.y + y_offset, 1.0);
                vec3 coords_tex = niri_geo_to_tex * moved_coords;
                vec4 color = texture2D(niri_tex, coords_tex.st);
                if (coords_geo.y < 0.0 || coords_geo.y > 1.0 || coords_geo.x < 0.0 || coords_geo.x > 1.0) {
                    color = vec4(0.0);
                }

                return color * niri_clamped_progress;
            }
