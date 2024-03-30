/*
====================================================================================================

    Copyright (C) 2021 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.com/copyright-license

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

/*
    const bool colortex0MipmapEnabled = true;
*/

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 sceneColor;

#include "/lib/head.glsl"

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform float aspectRatio;
uniform float centerDepthSmooth;
uniform float viewWidth, viewHeight;
uniform float far, near;
uniform float screenBrightness;

uniform vec2 viewSize;

uniform mat4 gbufferProjection, gbufferProjectionInverse;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

#include "/lib/util/poisson.glsl"

float screenToViewSpace(float depth) {
	depth = depth * 2.0 - 1.0;
	return gbufferProjectionInverse[3].z / (gbufferProjectionInverse[2].w * depth + gbufferProjectionInverse[3].w);
}

#define camFStops 2.8   //[0.8 1.4 2.0 2.8 3.2 3.6 4.0 4.4 4.8 5.6 6.4 7.2 8.0 9.6 12.8 16.0]
#define camSensorWidth 35   //[16 20 25 30 35 40 50 60 70 80]
#define chromaOffsetScale 1.00  //[0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50]

const vec2 sensorWidth      = camSensorWidth * vec2(1.0 / anamorphStretch, 1.0) * 1e-3;

vec2 getCoC(float dist, float focus, vec2 fLength, vec2 aperture) {
    vec2 n      = aperture * (fLength * (dist - focus));
    vec2 d      = dist * (focus - fLength);

    return abs(n) * rcp(max(d, 1e-20)) * 1e3 * aperture * tau;
}

vec3 getBokehDoF(sampler2D scene, sampler2D depthtex, vec2 coord) {
    vec2 fLength   = 0.5 * sensorWidth * gbufferProjection[0].x;
    vec2 aperture  = fLength / camFStops;

    float pixelDepth = texture(depthtex, coord).x;
    if (pixelDepth < 0.7) return textureLod(scene, coord, 0).rgb;
    
    #if camFocus == 0 //   Auto
        float focus = centerDepthSmooth;
    #elif camFocus == 1 // Manual
        float focus = camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 2 // Manual+
        float focus = screenBrightness * camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 3 // Auto+
        float offset = screenBrightness * 2.0 - 1.0;
        float autoFocus = depthLinear(centerDepthSmooth) * far * 0.5;
        float focus = offset > 0.0 ? autoFocus + (offset * camManFocDis) : autoFocus * saturate(offset * 0.9 + 1.1);
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #endif

    float dist  = screenToViewSpace(pixelDepth);
    float focusDist = screenToViewSpace(focus);

    vec2 pixelCoC   = getCoC(dist, focusDist, aperture, fLength);

    vec2 projectionCoord = (coord - 0.5) * vec2(anamorphStretch * aspectRatio, 1.0);

    vec2 dispersionDir  = clamp(normalize(projectionCoord), -1.0, 1.0);

    vec3 result     = vec3(0.0);
    uint weight     = 0;

    #if DoFQuality == 0
    for (uint i = 0; i < 30; i++) {
        vec2 bokeh  = poisson30[i];
    #elif DoFQuality == 1
    for (uint i = 0; i < 45; i++) {
        vec2 bokeh  = poisson45[i];
    #elif DoFQuality == 2
    for (uint i = 0; i < 60; i++) {
        vec2 bokeh  = poisson60[i];
    #endif

        vec2 offset     = bokeh * vec2(1.0, aspectRatio) * pixelCoC;

        float depth     = screenToViewSpace(texture(depthtex, coord + offset).x);

        vec2 CoC        = getCoC(depth, focusDist, aperture, fLength);

        float lod       = clamp(log2(max(CoC.x, CoC.y) * 0.5 * viewSize.y), 0.0, 4.0);

        vec2 newOffset  = bokeh * vec2(1.0, aspectRatio) * CoC;

        vec3 color      = textureLod(scene, coord + newOffset, lod).rgb;

        #ifdef DoFChromaDispersion
        vec2 chromaOffset = dispersionDir * 4e-1 * CoC * chromaOffsetScale;

            color.r   = textureLod(scene, coord + newOffset + chromaOffset, lod).r;
            color.b   = textureLod(scene, coord + newOffset - chromaOffset, lod).b;
        #endif
        
        result     += color;
        weight++;
    }

    result /= max(weight, 1);

    return result;
}

void main() {
    sceneColor  = textureLod(colortex0, uv, 0).rgb;

    #ifdef DoFToggle
        sceneColor  = getBokehDoF(colortex0, depthtex0, uv);
    #endif
}