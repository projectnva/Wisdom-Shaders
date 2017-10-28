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

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 120


#include "libs/compat.glsl"

#pragma optimize(on)

//#define SMOOTH_TEXTURE

#include "libs/encoding.glsl"

#define NORMALS

uniform sampler2D texture;
uniform sampler2D specular;
#ifdef NORMALS
uniform sampler2D normals;
#endif
varying vec2 nflat;

varying f16vec4 color;
varying vec4 coords;
varying vec4 wdata;

varying float dis;

#define normal wdata.xyz
#define flag wdata.w

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying f16vec3 tangent;
varying f16vec3 binormal;
#endif

uniform ivec2 atlasSize;

#define ParallaxOcclusion
#ifdef ParallaxOcclusion
varying f16vec3 tangentpos;

#define tileResolution 128 // [32 64 128 256 512 1024]

vec2 atlas_offset(in vec2 coord, in vec2 offset) {
	const ivec2 atlasTiles = ivec2(32, 16);

	coord *= atlasSize;

	vec2 offsetCoord = coord + mod(offset.xy * atlasSize, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x)
		offsetCoord.x -= tileResolution;
	else if (offsetCoord.x < minCoord.x)
		offsetCoord.x += tileResolution;

	if (offsetCoord.y > maxCoord.y)
		offsetCoord.y -= tileResolution;
	else if (offsetCoord.y < minCoord.y)
		offsetCoord.y += tileResolution;

	offsetCoord /= atlasSize;

	return offsetCoord;
}

//#define PARALLAX_SELF_SHADOW
#ifdef PARALLAX_SELF_SHADOW
varying vec3 sun;
float parallax_lit = 1.0;
#endif

vec2 ParallaxMapping(in vec2 coord) {
	vec2 adjusted = coord.st;
	#define maxSteps 8 // [4 8 16]
	#define scale 0.01 // [0.005 0.01 0.02]

	float heightmap = texture2D(normals, coord.st).a - 1.0f;

	vec3 offset = vec3(0.0f, 0.0f, 0.0f);
	vec3 s = tangentpos;//normalize(tangentpos);
	s = s / s.z * scale / maxSteps;

	float lazyx = 0.5;
	const float lazyinc = 0.5 / maxSteps;

	if (heightmap < 0.0f) {
		for (int i = 0; i < maxSteps; i++) {
			float prev = offset.z;

			offset += (heightmap - prev) * lazyx * s;
			lazyx += lazyinc;

			adjusted = atlas_offset(coord.st, offset.st);
			heightmap = texture2D(normals, adjusted).a - 1.0f;
			if (max(0.0, offset.z - heightmap) < 0.05) break;
		}

		#ifdef PARALLAX_SELF_SHADOW
		s = normalize(sun);
		s = s * scale * 10.0 / maxSteps;
		vec3 light_offset = offset;

		for (int i = 0; i < maxSteps; i++) {
			float prev = offset.z;

			light_offset += s;
			lazyx += lazyinc;

			heightmap = texture2D(normals, atlas_offset(coord.st, light_offset.st)).a - 1.0f;
			if (heightmap > light_offset.z) {
				parallax_lit = 0.5;
				break;
			}
		}
		#endif
	}

	return adjusted;
}
#endif

//#define SPECULAR_TO_PBR_CONVERSION
//#define CONTINUUM2_TEXTURE_FORMAT

/* DRAWBUFFERS:0124 */
void main() {
	vec2 texcoord_adj = texcoord;
	#ifdef ParallaxOcclusion
	if (dis < 64.0) texcoord_adj = ParallaxMapping(texcoord);
	#endif

	f16vec4 t = texture2D(texture, texcoord_adj);

	#ifdef PARALLAX_SELF_SHADOW
	t.rgb *= parallax_lit;
	#endif

	gl_FragData[0] = t * color;

	#ifdef SPECULAR_TO_PBR_CONVERSION
	vec3 spec = texture2D(specular, texcoord_adj).rgb;
	float spec_strength = dot(spec, vec3(0.3, 0.6, 0.1));
	gl_FragData[1] = vec4(spec_strength, spec_strength, 0.0, 1.0);
	#else
	#ifdef CONTINUUM2_TEXTURE_FORMAT
	gl_FragData[1] = vec4(texture2D(specular, texcoord_adj).brg, 1.0);
	#else
	gl_FragData[1] = vec4(texture2D(specular, texcoord_adj).rgb, 1.0);
	#endif
	#endif

	gl_FragData[2] = vec4(nflat, lmcoord);

	#ifdef NORMALS
		f16vec3 normal2 = normal;
		if (dis < 64.0) {
			normal2 = texture2D(normals, texcoord_adj).xyz * 2.0 - 1.0;
			const float16_t bumpmult = 0.5;
			normal2 = normal2 * bumpmult + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			f16mat3 tbnMatrix = mat3(tangent, binormal, normal);
			normal2 = tbnMatrix * normal2;
		}
		vec2 d = normalEncode(normal2);
		if (!(d.x > 0.0 && d.y > 0.0)) d = nflat;
		gl_FragData[3] = vec4(d, flag, 1.0);
	#else
		gl_FragData[3] = vec4(nflat, flag, 1.0);
	#endif
}
