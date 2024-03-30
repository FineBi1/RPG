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

#ifndef DIM
#include "/lib/atmos/colorsDefault.glsl"
#elif DIM == -1
#include "/lib/atmos/colorsNether.glsl"
#elif DIM == 1
#include "/lib/atmos/colorsEnd.glsl"
#endif

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv          = gl_MultiTexCoord0.xy;

    getColorPalette();
}