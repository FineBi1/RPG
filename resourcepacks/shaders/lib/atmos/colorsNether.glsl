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

uniform vec3 fogColor;

flat out mat3 colorPalette;

void getColorPalette() {
    vec3 linearFog  = toLinear(fogColor);

    colorPalette[0]   = linearFog * sqrt2;    //ambient light
    colorPalette[1]   = linearFog * rpi;    //sky + fog
    colorPalette[2]   = vec3(1.00, 0.7, 0.4);
}