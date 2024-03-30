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

#include "/lib/util/colorspace.glsl"

flat out mat4x3 lightColor;     //Sunlight, Moonlight, Skylight, Blocklight

void getColorPalette() {

    lightColor[0]   = vec3(1.0, 0.4, 1.0) * 0.3;

    lightColor[1]   = lightColor[0];

    lightColor[2]   = vec3(1.0, 0.2, 1.0) * 0.1;

    lightColor[3]   = vec3(1.00, 0.7, 0.4);
}