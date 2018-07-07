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

#pragma optimize(on)
#include "libs/compat.glsl"

varying vec2 uv;

#include "GlslConfig"

#define WAO

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"

#define SSS

#include "libs/Lighting.frag"

//#define GI

#define HAND_LIGHT
#ifdef HAND_LIGHT
LightSourcePBR hand;
#endif

#include "libs/atmosphere.glsl"

varying vec3 sunLight;
varying vec3 sunraw;

varying vec3 ambientU;
varying vec3 ambient0;
varying vec3 ambient1;
varying vec3 ambient2;
varying vec3 ambient3;
varying vec3 ambientD;

varying vec3 worldLightPosition;

#define WAO_ADVANCED
#define FAR_SHADOW_APPROXIMATION

void main() {
  vec3 color = vec3(0.0);

  Mask mask;
  Material frag;
  
  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  #ifdef GI
  vec3 gi = vec3(0.0);
  #endif

  #define RAIN_DROPS_ANIMATION

  if (!mask.is_sky) {
    LightSourcePBR sun;
    LightSourceHarmonics ambient;
    LightSource torch;

    sun.light.color = sunLight;
    sun.L = lightPosition;

    vec3 wN = mat3(gbufferModelViewInverse) * frag.N;

    float thickness = 1.0, shade = 0.0;
    vec3 scolor;
    shade = light_fetch_shadow(shadowtex1, wpos2shadowpos(frag.wpos), thickness, scolor, 1.0 - max(0.0, dot(frag.N, lightPosition)));
    sun.light.color *= scolor;

    float ao = 1.0;
    #ifdef WAO
    ao  = sum4(textureGatherOffset(gaux2, uv, ivec2( 1, 1)));
    #ifdef WAO_ADVANCED
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2(-1, 1)));
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2(-1,-1)));
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2( 1,-1)));
    ao *= 0.0625;
    #else
    ao *= 0.25;
    #endif
    #endif

    float far_shadow_weight = smoothstep(shadowDistance - 16.0, shadowDistance, frag.cdepth);
    thickness = mix(thickness, 1.0, far_shadow_weight);
    #ifdef FAR_SHADOW_APPROXIMATION
    shade = mix(shade, max(1.0 - smoothstep(0.9, 0.95, frag.skylight), 1.0 - ao), far_shadow_weight);
    #endif

    #ifdef SSS
    shade = max(shade, screen_space_shadow(lightPosition, frag.vpos, frag.N, frag.cdepth));
    #endif
    //shade = shade * smoothstep(0.0, 1.0, thickness * 5.0);
    sun.light.attenuation = 1.0 - shade;

    ambient.attenuation = light_mclightmap_simulated_GI(frag.skylight);
    #ifdef DIRECTIONAL_LIGHTMAP
    ambient.attenuation *= lightmap_normals(frag.N, frag.skylight, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
    #endif

    ambient.color0 = ambientU * ao;
    ambient.color1 = ambient0 * ao;
    ambient.color2 = ambient1 * ao;
    ambient.color3 = ambient2 * ao;
    ambient.color4 = ambient3 * ao;
    ambient.color5 = ambientD * ao;

    const vec3 torch1900K = pow(vec3(255.0, 147.0, 41.0) / 255.0, vec3(2.2)) * 0.01;
  	const vec3 torch5500K = vec3(1.2311, 1.0, 0.8286) * 0.008;
    const vec3 torch_warm = vec3(1.2311, 0.7, 0.4286) * 0.01;
  	//#define WHITE_LIGHT
    //#define WARM_LIGHT
    #define TORCH_LIGHT

  	#ifdef TORCH_LIGHT
    torch.color = torch1900K;
	  #endif
    #ifdef WARM_LIGHT
    torch.color = torch_warm;
    #endif
    #ifdef WHITE_LIGHT
	  torch.color = torch5500K;
	  #endif
    torch.attenuation = light_mclightmap_attenuation(frag.torchlight) * ao;

    #ifdef HAND_LIGHT
    hand.light.color = torch.color * float(heldBlockLightValue) * 10.0;
    hand.L = -frag.vpos;
    hand.light.attenuation = 1.0 / (distanceSquared(hand.L, frag.vpos) + 1.0);
    #endif

    float wetness2 = wetness * smoothstep(0.92, 1.0, frag.skylight) * float(!mask.is_plant);
		if (wetness2 > 0.0) {
			float wet = noise((frag.wpos + cameraPosition).xz * 0.5 - frameTimeCounter * 0.02);
			wet += noise((frag.wpos + cameraPosition).xz * 0.6 - frameTimeCounter * 0.01) * 0.5;
			wet = clamp(wetness2 * 3.0, 0.0, 1.0) * clamp(wet * 2.0 + wetness2, 0.0, 1.0);
			
			if (wet > 0.0) {
				frag.roughness = mix(frag.roughness, 0.05, wet);
				frag.metalic = mix(frag.metalic, 0.03, wet);
				frag.N = mix(frag.N, frag.Nflat, wet);
			
        #ifdef RAIN_DROPS_ANIMATION
				frag.N.x += noise((frag.wpos.xz + cameraPosition.xz) * 5.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N.y -= noise((frag.wpos.xz + cameraPosition.xz) * 6.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N = normalize(frag.N);
        #endif
			}
    }
		
    color = light_calc_PBR(sun, frag, mask.is_plant ? thickness : 1.0, mask.is_grass) + light_calc_diffuse_harmonics(ambient, frag, wN) + light_calc_diffuse(torch, frag);
    #ifdef HAND_LIGHT
    color += light_calc_PBR(hand, frag, 1.0, false);
    #endif

  	#ifdef GI
    float weight = 0.0;

  	for (int i = 0; i < 4; i++) {
		  vec2 coord = uv + vec2(i / viewWidth * 1.5, 0.0);

			vec3 c = texture2D(colortex3, coord).rgb;
  		float bilateral = max(dot(normalDecode(texture2D(gaux1, uv).rg), frag.N), 0.0);
      #ifdef MC_GL_VENDOR_INTEL
      if (bilateral < 0.1) break;
      #endif

	  	weight += 1.0;
      gi += c;
	  }

    for (int i = -1; i > -4; i--) {
		  vec2 coord = uv + vec2(i / viewWidth * 1.5, 0.0);

			vec3 c = texture2D(colortex3, coord).rgb;
  		float bilateral = max(dot(normalDecode(texture2D(gaux1, uv).rg), frag.N), 0.0);
      #ifdef MC_GL_VENDOR_INTEL
      if (bilateral < 0.1) break;
      #endif

	  	weight += 1.0;
      gi += c;
	  }

    gi /= weight;
    gi *= sunLight;
	  #endif
	
  	//#define WAO_DEBUG
  	#ifdef WAO_DEBUG
	  color = vec3(ao);
	  #endif
	
    color = mix(color, frag.albedo, frag.emmisive);

    //#define SSS_DEBUG
    #ifdef SSS_DEBUG
    color = vec3(sun.light.attenuation);
    #endif
  } else {
    vec3 nwpos = normalize(frag.wpos);
    color = texture2D(colortex0, uv).rgb;

    float mu_s = dot(nwpos, worldLightPosition);
    float mu = abs(mu_s);
    #ifdef CLOUDS_2D
    float cmie = calc_clouds(nwpos * 512.0, cameraPosition);
    color *= 1.0 - cmie;

    float opmu2 = 1. + mu*mu;
    float phaseM = .1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));
    vec3 sunlight = sunraw * 1.3;
    color += (1.8 * luma(ambientU) + sunlight * phaseM) * cmie;
    #endif

    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), nwpos, worldLightPosition, Ra);
    color += sunraw * smoothstep(0.9997, 0.99975, mu_s);
  }

/* DRAWBUFFERS:53 */
  gl_FragData[0] = vec4(color, 0.0);
  #ifdef GI
  gl_FragData[1] = vec4(gi, 0.0);
  #endif
}
