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

flat out vec3 sunDir;
flat out vec3 moonDir;

uniform int worldTime;

flat out mat2x3 skyColors;

#include "/lib/atmos/colorsDefault.glsl"

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    uv          = gl_MultiTexCoord0.xy;

    // Sun Position Fix from Builderb0y
    float ang   = fract(worldTime / 24000.0 - 0.25);
        ang     = (ang + (cos(ang * pi) * -0.5 + 0.5 - ang) / 3.0) * tau;
    const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

    sunDir      = vec3(-sin(ang), cos(ang) * sunRotationData);
    moonDir     = -sunDir;

    vec3 linearSky  = toLinear(skyColor);
    vec3 linearFog  = toLinear(fogColor);

    getColorPalette();

    #if colorPreset <= 1

        skyColors[0]    = linearSky;

        skyColors[1]    = daytimeColor(
            vec3(1.00, 0.28, 0.06) * 1.60,
            linearFog * 2.3,
            vec3(1.00, 0.28, 0.06) * 1.60,
            linearFog * 1.7
        );

    #elif colorPreset == 2  // SEUS v08

        skyColors[0]    = colorSaturation(linearSky, 1.2) * vec3(1.0, 1.5, 1.1);
        skyColors[0] *= daytimeColor(
            vec3(1.0, 1.2, 0.8),
            vec3(1.0, 1.2, 1.0),
            vec3(1.0, 1.2, 0.8),
            vec3(1.0)
        );

        skyColors[1]    = daytimeColor(
            vec3(1.00, 0.45, 0.06) * 2.00,
            linearFog * 3.0 * normalize(lightColor[0]),
            vec3(1.00, 0.45, 0.06) * 2.00,
            linearFog * 1.7 * vec3(0.3, 0.5, 1.0)
        );

    #elif colorPreset == 3

        skyColors[0]    = colorSaturation(linearSky, 0.7) * vec3(1.0, 1.4, 1.3);

        skyColors[1]    = daytimeColor(
            vec3(1.00, 0.35, 0.05) * 2.00,
            linearFog * 3.0 * normalize(lightColor[0]) * vec3(1.0, 0.9, 0.8),
            vec3(1.00, 0.35, 0.05) * 2.00,
            linearFog * 1.7 * vec3(0.26, 0.53, 1.0)
        );

    #elif colorPreset == 4

        skyColors[0]    = colorSaturation(linearSky, 0.8) * vec3(1.0, 1.35, 1.0);

        skyColors[1]    = daytimeColor(
            vec3(1.00, 0.35, 0.05) * 2.00,
            linearFog * 3.0 * normalize(lightColor[0]) * vec3(1.0, 0.95, 0.9),
            vec3(1.00, 0.35, 0.05) * 2.00,
            linearFog * 1.7 * vec3(0.26, 0.39, 1.0)
        );

    #elif colorPreset == 5

        skyColors[0]    = colorSaturation(linearSky, 0.9) * vec3(1.0, 1.35, 1.0);

        skyColors[1]    = daytimeColor(
            vec3(1.00, 0.40, 0.06) * 2.00,
            linearFog * 3.0 * normalize(lightColor[0]),
            vec3(1.00, 0.40, 0.06) * 2.00,
            linearFog * 1.7 * vec3(0.26, 0.53, 1.0)
        );

    #endif

    skyColors[0]   *= daytimeColor(
            vec3(skycolSunriseR, skycolSunriseG, skycolSunriseB) * skycolSunriseL,
            vec3(skycolNoonR, skycolNoonG, skycolNoonB) * skycolNoonL,
            vec3(skycolSunsetR, skycolSunsetG, skycolSunsetB) * skycolSunsetL,
            vec3(skycolNightR, skycolNightG, skycolNightB) * skycolNightL
    );

    skyColors[1]   *= daytimeColor(
            vec3(fogcolSunriseR, fogcolSunriseG, fogcolSunriseB) * fogcolSunriseL,
            vec3(fogcolNoonR, fogcolNoonG, fogcolNoonB) * fogcolNoonL,
            vec3(fogcolSunsetR, fogcolSunsetG, fogcolSunsetB) * fogcolSunsetL,
            vec3(fogcolNightR, fogcolNightG, fogcolNightB) * fogcolNightL
    );

    skyColors[0]    = mix(skyColors[0], vec3(avgOf(skyColors[0]) * 1.11), wetness * 0.9);
    skyColors[1]    = mix(skyColors[1], vec3(avgOf(skyColors[1]) * 0.71), wetness * 0.9);
}