#version 120

/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "libs/compat.glsl"
#pragma optimize(on)

varying vec2 uv;

#include "GlslConfig"

#include "libs/uniforms.glsl"
#include "libs/color.glsl"

#define BLOOM
#ifdef BLOOM
const float padding = 0.02f;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (uv.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (uv.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

#ifdef HIGH_LEVE_SHADER
const float weight[3] = float[] (0.3829, 0.2417, 0.0606);
#else
const float weight[7] = float[] (0.02, 0.0606, 0.2417, 0.3829, 0.2417, 0.0606, 0.02);
#endif

#define BLUR_X(i, abs_i) \
		c = max(texture2DOffset(colortex0, finalCoord, ivec2(i, -2)).rgb, vec3(0.0f)) * weight[abs_i] * weight[2]; bloom += c; lu += smoothstep(0.01, 0.1, luma(c)); \
		c = max(texture2DOffset(colortex0, finalCoord, ivec2(i, -1)).rgb, vec3(0.0f)) * weight[abs_i] * weight[1]; bloom += c; lu += smoothstep(0.01, 0.1, luma(c)); \
		c = max(texture2DOffset(colortex0, finalCoord, ivec2(i,  0)).rgb, vec3(0.0f)) * weight[abs_i] * weight[0]; bloom += c; lu += smoothstep(0.01, 0.1, luma(c)); \
		c = max(texture2DOffset(colortex0, finalCoord, ivec2(i,  1)).rgb, vec3(0.0f)) * weight[abs_i] * weight[1]; bloom += c; lu += smoothstep(0.01, 0.1, luma(c)); \
		c = max(texture2DOffset(colortex0, finalCoord, ivec2(i,  2)).rgb, vec3(0.0f)) * weight[abs_i] * weight[2]; bloom += c; lu += smoothstep(0.01, 0.1, luma(c));

vec4 LODblur(in float LOD, in vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);
	float lu = 0.0;

	vec2 finalCoord = ((uv.st - offset.st) * scale) * 0.25;
	vec3 c;

	BLUR_X(-2, 2);
	BLUR_X(-1, 1);
	BLUR_X( 0, 0);
	BLUR_X( 1, 1);
	BLUR_X( 2, 2);

	return vec4(bloom, lu);
}
#endif

void main() {
/* DRAWBUFFERS:0 */
// bloom
	#ifdef BLOOM
	vec4 blur = texture2D(colortex0, uv);
	/* LOD 2 */
	float lod = 2.0; vec2 offset = vec2(0.0f);
	if (uv.y < 0.25 + padding * 2.0 + 0.6251 && uv.x < 0.0078125 + 0.25f + 0.100f) {
		if (uv.y > 0.25 + padding) {
			if (checkBlur(offset = vec2(0.0f, 0.25f)     + vec2(0.000f, 0.03f), exp2(lod = 3.0))) { /* LOD 3 */ }
			else if (checkBlur(offset = vec2(0.125f, 0.25f)   + vec2(0.030f, 0.03f), exp2(lod = 4.0))) { /* LOD 4 */ }
			else if (checkBlur(offset = vec2(0.1875f, 0.25f)  + vec2(0.060f, 0.03f), exp2(lod = 5.0))) { /* LOD 5 */ }
			else if (checkBlur(offset = vec2(0.21875f, 0.25f) + vec2(0.090f, 0.03f), exp2(lod = 6.0))) { /* LOD 6 */ }
			else lod = 0.0f;
		}
		if (lod > 2.5f) blur = LODblur(lod, offset);
	}
	gl_FragData[0] = blur;
	#endif
}
