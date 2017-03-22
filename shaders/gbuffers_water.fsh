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
#pragma optimize(on)

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform vec3 skyColor;
uniform vec3 cameraPosition;

varying vec3 wpos;
varying vec2 normal;
varying float iswater;
varying vec2 texcoord;
varying float skyLight;

/* DRAWBUFFERS:3467 */
void main() {
	gl_FragData[0] = vec4(normal, iswater, 1.0);

	if (iswater < 0.90f) {
		gl_FragData[1] = vec4(0.14, 0.93, 0.0, skyLight);
	}
	gl_FragData[3] = texture2D(texture, texcoord);

	gl_FragData[2] = vec4(wpos, 1.0);
}
