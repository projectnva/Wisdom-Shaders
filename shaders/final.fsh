#version 120
#pragma optimize(on)
#include "libs/compat.glsl"

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

varying vec2 uv;

const int RGBA8 = 0, R11_G11_B10 = 1, RGB16 = 2, RGBA16F = 3, RGBA16 = 4, RGBA32F = 5;

const int colortex0Format = RGBA16;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA16;
const int gaux1Format = RGB16;
const int gaux2Format = RGBA16;
const int gaux3Format = RGBA16F;
const int gaux4Format = RGBA16;

const int noiseTextureResolution = 256;

#include "GlslConfig"

//#define VIGNETTE
#define BLOOM

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/noise.glsl"
#include "libs/Effects.glsl"

uniform float screenBrightness;
uniform float nightVision;
uniform float blindness;
uniform float valHurt;

#define DISTORTION_FIX
#ifdef DISTORTION_FIX
varying vec3 vUV;
varying vec2 vUVDot;
#endif

varying vec3 sunLight;
varying vec3 worldLightPosition;

void main() {
	#ifdef DISTORTION_FIX
	vec3 distort = dot(vUVDot, vUVDot) * vec3(-0.5, -0.5, -1.0) + vUV;
	vec2 uv_adj = distort.xy / distort.z;
	#else
	vec2 uv_adj = uv;
	#endif

	vec3 color = texture2D(gaux2, uv_adj).rgb;

	float exposure = 1.0;

	#ifdef BLOOM
	vec3 b = bloom(color, uv_adj);

	const vec2 tex = vec2(0.5) * 0.015625 + vec2(0.21875f, 0.3f) + vec2(0.090f, 0.035f);
	exposure = (1.0 + max(1.0 - eyeBrightnessSmooth.y / 240.0 * luma(sunLight) * 0.4, 0.0));
	//#define BLOOM_DEBUG
	#ifdef BLOOM_DEBUG
	color = max(vec3(0.0), b) * exposure;
	#else
	color += max(vec3(0.0), b) * exposure;
	#endif
	#endif

	#ifdef NOISE_AND_GRAIN
	noise_and_grain(color);
	#endif
	
	color = pow(color, vec3(1.0 - nightVision * 0.5));
	color *= 1.0 - blindness * 0.9;
	
	vec2 uv_n = uv * 0.4;
	vec2 central = vec2(0.5) - uv_n;
	float screwing = noise_tex(uv_n - frameTimeCounter * central);
	uv_n += screwing * 0.04 * central;
	screwing += noise_tex(uv_n * 2.5 + frameTimeCounter * 0.4 * central);
	uv_n += screwing * 0.08 * central;
	screwing += noise_tex(uv_n * 8.0 - frameTimeCounter * 0.8 * central);
	
	color = vignette(color, vec3(0.4, 0.00, 0.00), valHurt * fma(screwing, 0.25, 0.75));
	
	ACEStonemap(color, (screenBrightness * 0.5 + 0.75) * exposure);
	
	gl_FragColor = vec4(toGamma(color),1.0);
	
	//if (uv.y > 0.5) gl_FragColor.rgb = vec3((1.0 + max(1.0 - eyeBrightnessSmooth.y / 240.0 * luma(sunLight) * 0.4, 0.0))) * 0.5;
}
