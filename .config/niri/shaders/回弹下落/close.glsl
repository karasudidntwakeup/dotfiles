
            // 窗口关闭的动画：先溶解后下落

            float rand(vec2 co){
                return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
            }
            vec4 close_color(vec3 coords_geo, vec3 size_geo) {
                float p = niri_clamped_progress;
                float noise = rand(coords_geo.xy * 30.0);
                if (noise < (p * 1.5 - (1.0 - coords_geo.y) * 0.2)) {
                    return vec4(0.0);
                }
                //前20%的时间溶解，然后再下落
                float drop_p = max(0.0, p - 0.2) / 0.8;
                float gravity = pow(drop_p, 3.0) * 4.0;
                float spread = (noise - 0.5) * gravity * 0.1;
                vec3 moved_coords = vec3(coords_geo.x + spread, coords_geo.y - gravity, 1.0);
                vec3 coords_tex = niri_geo_to_tex * moved_coords;
                vec4 color = texture2D(niri_tex, coords_tex.st);
                
                if (moved_coords.y < 0.0 || moved_coords.y > 1.0 || moved_coords.x < 0.0 || moved_coords.x > 1.0) {
                    return vec4(0.0);
                }

                return color * (1.0 - p);
            }
