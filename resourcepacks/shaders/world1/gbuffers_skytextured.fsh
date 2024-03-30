#version 400 compatibility

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

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 sceneAlbedo;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"

in vec2 coord;

in vec4 tint;

uniform sampler2D gcolor;

uniform vec4 daytime;

void main() {
    vec4 sceneColor   = texture(gcolor, coord);
        sceneColor.rgb *= tint.rgb;
        convertToPipelineAlbedo(sceneColor.rgb);

    sceneAlbedo     = clamp16F(sceneColor);
}