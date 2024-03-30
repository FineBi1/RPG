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

vec3 toLinear(vec3 x){
    vec3 temp = mix(x / 12.92, pow(.947867 * x + .0521327, vec3(2.4)), step(0.04045, x));
    return max(temp, 0.0);
}

vec3 LinearToSRGB(vec3 x){
    return mix(x * 12.92, clamp16F(pow(x, vec3(1./2.4)) * 1.055 - 0.055), step(0.0031308, x));
}

void convertToPipelineColor(inout vec3 x) {
    x   = toLinear(x);
    return;
}
void convertToPipelineAlbedo(inout vec3 x) {
    x   = toLinear(x);
    return;
}
void convertToDisplayColor(inout vec3 x) {
    x   = LinearToSRGB(x);
    return;
}