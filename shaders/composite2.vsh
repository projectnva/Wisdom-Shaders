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

//varying vec3 sunLight;

//varying vec3 ambientU;

#include "libs/atmosphere.glsl"

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
/*
void functions() {
  vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
  sunLight = scatter(vec3(0., 25e2, 0.), worldLightPosition, worldLightPosition, Ra);

  ambientU = scatter(vec3(0., 25e2, 0.), vec3(0.0, 1.0, 0.0), worldLightPosition, Ra);
}

#define Functions*/
#include "libs/DeferredCommon.vert"
