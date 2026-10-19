// Sea glass body. Ported from the AGSL body shader in Sea Glass for Compose
// (Apache-2.0, Matt McKenna). Draw inside the tumbled outline path.
//
// Coordinates are local logical pixels with the material's top-left at 0,0.
// uGeometryA: R/G = X slope (16-bit), B = dome height.
// uGeometryB: R/G = Y slope (16-bit).

#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;       // material size in logical pixels
uniform vec4 uRecipeA;    // frost, grain, thickness, bulge
uniform vec4 uRecipeB;    // slopeScale, transmission, noise seed, unused
uniform vec3 uBody;       // body pigment, 0..1
uniform vec3 uEdge;       // edge light, 0..1
uniform vec2 uLight;      // light azimuth direction, screen space
uniform vec3 uHalfway;    // half vector between light and viewer
uniform sampler2D uGeometryA;
uniform sampler2D uGeometryB;

out vec4 fragColor;

float hashNoise(vec2 point, float salt) {
  vec3 p = fract(vec3(point.x, point.y, point.x) * 0.1031 + salt);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z) * 2.0 - 1.0;
}

float noiseGrid(vec2 point, float spacing, float salt) {
  vec2 cell = point / spacing;
  vec2 index = floor(cell);
  vec2 fraction = fract(cell);
  vec2 eased = fraction * fraction * (3.0 - 2.0 * fraction);
  float a = hashNoise(index, salt);
  float b = hashNoise(index + vec2(1.0, 0.0), salt);
  float c = hashNoise(index + vec2(0.0, 1.0), salt);
  float d = hashNoise(index + vec2(1.0, 1.0), salt);
  return mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
}

// Value plus the analytic gradient of the same cubic interpolation.
vec3 noiseGridGradient(vec2 point, float spacing, float salt) {
  vec2 cell = point / spacing;
  vec2 index = floor(cell);
  vec2 fraction = fract(cell);
  vec2 eased = fraction * fraction * (3.0 - 2.0 * fraction);
  vec2 derivative = 6.0 * fraction * (1.0 - fraction) / spacing;
  float a = hashNoise(index, salt);
  float b = hashNoise(index + vec2(1.0, 0.0), salt);
  float c = hashNoise(index + vec2(0.0, 1.0), salt);
  float d = hashNoise(index + vec2(1.0, 1.0), salt);
  float value = mix(mix(a, b, eased.x), mix(c, d, eased.x), eased.y);
  float dx = mix(b - a, d - c, eased.y) * derivative.x;
  float dy = mix(c - a, d - b, eased.x) * derivative.y;
  return vec3(value, dx, dy);
}

float decode16(vec2 hiLo) {
  return (hiLo.x * 65280.0 + hiLo.y * 255.0) / 65535.0;
}

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec2 uv = clamp(position / uSize, vec2(0.0), vec2(1.0));
  vec3 geoA = texture(uGeometryA, uv).rgb;
  vec3 geoB = texture(uGeometryB, uv).rgb;

  float slopeScale = uRecipeB.x;
  vec2 slope = (vec2(decode16(geoA.rg), decode16(geoB.rg)) - 0.5) * 2.0 * slopeScale;
  float dome = geoA.b;

  float frost = uRecipeA.x;
  float grain = uRecipeA.y;
  float thickness = uRecipeA.z;
  float bulge = uRecipeA.w;
  float transmission = uRecipeB.y;
  float seed = uRecipeB.z;
  float shortSide = min(uSize.x, uSize.y);

  float fine = noiseGrid(position, 0.68, seed + 0.11);
  vec3 micro = noiseGridGradient(position, 1.7, seed + 0.29);
  float worn = noiseGrid(position, 7.5, seed + 0.47);
  float cloud = noiseGrid(position, shortSide * 0.44, seed + 0.71) * 0.75 + worn * 0.25;
  float roughness = fine * 0.54 + micro.x * 0.32 + worn * 0.14;
  vec2 roughGradient = micro.yz * (0.32 + min(position, vec2(0.32)));

  float rise = 0.9 + min(thickness * 1.55, shortSide * 0.22) + bulge * shortSide * 0.34;
  vec3 shapeNormal = normalize(vec3(-slope * rise, 1.0));
  shapeNormal.z = clamp(shapeNormal.z, 0.0, 1.0);
  float rough = grain * (0.025 + frost * 0.04);
  vec3 normal = normalize(vec3(-slope * rise + roughGradient * rough, 1.0));

  // Optical depth lives in the body: thin shoulders transmit more, the broad
  // interior keeps its color, and a slight vertical bias keeps the top rich.
  float travel = clamp(position.y / uSize.y, 0.0, 1.0);
  float flow = travel * travel * (3.0 - 2.0 * travel);
  float depth = (1.05 - flow * transmission * 0.13)
      * (0.70 + dome * (0.52 + thickness * 0.012))
      * (1.0 + (1.0 - shapeNormal.z) * max(0.0, -shapeNormal.y) * 0.28)
      * (1.0 + cloud * 0.035);
  float weathering = frost * (0.06 + (cloud + 1.0) * 0.025);
  vec3 tint = uBody * 0.96 + uEdge * 0.04;
  vec3 color = 1.0 - (1.0 - tint) * depth;
  color += (1.0 - color) * weathering;

  float lx = uLight.x;
  float ly = uLight.y;
  float lightZ = 0.52;
  float lightSide = sqrt(1.0 - lightZ * lightZ);
  vec3 light = vec3(lx * lightSide, ly * lightSide, lightZ);
  float diffuse = max(0.0, dot(normal, light));

  // A soft environment lobe reflected through the curved normal.
  vec3 reflectionNormal = vec3(2.0 * normal.xy * normal.z, 2.0 * normal.z * normal.z - 1.0);
  float reflectedLight = max(0.0, dot(reflectionNormal, light));
  float across = -ly * reflectionNormal.x + lx * reflectionNormal.y;
  float along = -lightZ * (lx * reflectionNormal.x + ly * reflectionNormal.y) + lightSide * reflectionNormal.z;
  float acrossScale = across / (0.78 + frost * 0.24);
  float alongScale = along / (0.46 + frost * 0.24);
  float reflection = exp(-(acrossScale * acrossScale + alongScale * alongScale))
      * clamp(reflectedLight / 0.30, 0.0, 1.0) * (0.15 + bulge * 0.12) * (0.82 + frost * 0.18);
  float scatter = pow(max(0.0, dot(normal, uHalfway)), 12.0 + (1.0 - frost) * 18.0)
      * (0.008 + frost * 0.012);

  // Soft overhead illumination across the upper turn.
  float upperScale = (normal.y + 0.40) / 0.38;
  float upperTurn = exp(-(upperScale * upperScale)) * pow(max(normal.z, 0.000001), 0.55)
      * (0.10 + bulge * 0.14) * (0.85 + frost * 0.15);
  float palePits = pow(max(0.0, roughness + 0.20), 2.0) * grain
      * (5.0 + frost * 10.0) * (0.65 + diffuse * 0.35);
  float matte = roughness * grain * (0.012 + frost * 0.016);

  // Light exits through the curved lower shoulder.
  float grazing = sqrt(max(0.0, 1.0 - shapeNormal.z * shapeNormal.z));
  float lowerFacing = clamp((shapeNormal.y + 0.16) / 0.80, 0.0, 1.0);
  float shoulder = pow(grazing, 2.3) * lowerFacing * lowerFacing * (3.0 - 2.0 * lowerFacing);
  float exitAmount = clamp(transmission * (0.10 * flow + 1.65 * shoulder)
      * (0.96 - thickness * 0.005), 0.0, 0.96);
  float exitCatch = pow(max(0.0, 1.0 - shapeNormal.z), 2.2) * lowerFacing * 0.85;

  color += (1.0 - color) * (reflection + scatter + upperTurn);
  vec3 exitColor = uEdge + (1.0 - uEdge) * exitCatch;
  color += (exitColor - color) * exitAmount;
  color += (palePits / 255.0 + matte) * (1.0 - exitAmount * 0.45);
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
