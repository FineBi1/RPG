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

/* RENDERTARGETS: 6 */
layout(location = 0) out float exposureImage;

#include "/lib/head.glsl"

in vec2 uv;

uniform sampler2D colortex6;

uniform float aspectRatio;
uniform float viewWidth, viewHeight;

uniform vec2 viewSize;

#if pass == 0
const uvec2 downsampleScale     = uvec2(4);
const float scaleMult           = 0.25 * 0.25;
#elif pass == 1
const uvec2 downsampleScale     = uvec2(4);
const float scaleMult           = 0.25 * 0.25 * 0.25;
#endif

float getLuminance4x4(sampler2D tex) {
    uvec2 startPos  = uvec2(floor(gl_FragCoord.xy / vec2(downsampleScale))) * downsampleScale;

    float lumaSum   = 0.0;
    uint samples    = 0;

    for (uint x = 0; x < downsampleScale.x; ++x) {
        for (uint y = 0; y < downsampleScale.y; ++y) {
            uvec2 pos   = (startPos + ivec2(x, y)) * downsampleScale;
                pos     = clamp(pos, uvec2(0), uvec2(viewSize * sqrt(scaleMult)));
            lumaSum += texelFetch(tex, ivec2(pos), 0).r;
            ++samples;
        }
    }
    lumaSum /= max(samples, 1);

    return lumaSum;
}

void main() {
    exposureImage = getLuminance4x4(colortex6);
}