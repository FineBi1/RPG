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

#include "/lib/head.glsl"

out vec2 uv;

flat out float exposure;

uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;

uniform vec2 viewSize;

ivec2 tiles   = ivec2(viewSize * cube(0.25) - 1);

float getExposureLuma() {
    float averageLuminance  = 0.0;
    int total = 0;
    float totalWeight   = 0.0;

    for (int x = 0; x < tiles.x; ++x) {
        for (int y = 0; y < tiles.y; ++y) {
            float currentLuminance = texelFetch(colortex6, ivec2(x, y), 0).x;

            vec2 coord          = vec2(x, y) / vec2(tiles);

            float weight        = 1.0 - linStep(length(coord * 2.0 - 1.0), 0.25, 0.75);
                weight          = cubeSmooth(weight) * 0.9 + 0.1;

            averageLuminance   += currentLuminance * weight;
            ++total;
            totalWeight    += weight;
        }
    }
    averageLuminance   /= max(totalWeight, 1);

    return averageLuminance;
}

float temporalExp() {

    #if DIM == -1
    const float exposureLowClamp    = 0.06;
    const float exposureHighClamp   = rpi;
    #elif DIM == 1
    const float exposureLowClamp    = 0.1;
    const float exposureHighClamp   = rpi;
    #else
    const float exposureLowClamp    = 0.02;
    const float exposureHighClamp   = 0.25;
    #endif

    float expCurr   = clamp(texelFetch(colortex4, ivec2(0), 0).a, 0.0, 65535.0);
    float expTarg   = getExposureLuma();
        expTarg     = 1.0 / clamp(expTarg, exposureLowClamp * exposureDarkClamp * rcp(nightVision + 1.0), exposureHighClamp * exposureBrightClamp);
        expTarg     = log2(expTarg * rcp(8.0));    //adjust this
        expTarg     = 1.2 * pow(2.0, expTarg);

    //return expTarg;

    float adaptBaseSpeed = expTarg < expCurr ? 0.075 : 0.05;

    return mix(expCurr, expTarg, adaptBaseSpeed * exposureDecay * (frameTime * rcp(0.033)));
}

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv = gl_MultiTexCoord0.xy;

    exposure  = temporalExp();
}