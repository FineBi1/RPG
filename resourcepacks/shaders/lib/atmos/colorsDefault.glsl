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

uniform float wetness, RMoonPhaseOcclusion;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform vec4 daytime;

flat out mat4x3 lightColor;     //Sunlight, Moonlight, Skylight, Blocklight

vec3 daytimeColor(vec3 rise, vec3 noon, vec3 set, vec3 night) {
    return rise * daytime.x + noon * daytime.y + set * daytime.z + night * daytime.w;
}

void getColorPalette() {
    vec3 linearSky  = toLinear(skyColor);
    vec3 linearFog  = toLinear(fogColor);

    #if colorPreset <= 1

        lightColor[0]   = daytimeColor(
            vec3(1.00, 0.40, 0.00) * 0.60,
            vec3(1.00, 0.97, 0.94) * 1.00,
            vec3(1.00, 0.30, 0.00) * 0.70,
            vec3(1.00, 0.20, 0.00) * 0.40
            ) * 2.45;

        lightColor[1]   = vec3(0.45, 0.60, 1.0) * 0.05;

        vec3 skylightColor = mix(linearSky, lightColor[0] / euler, 0.3);

        lightColor[2]   = daytimeColor(
            skylightColor * 0.80,
            skylightColor * 1.00,
            skylightColor * 0.80,
            vec3(0.30, 0.60, 1.00) * 0.012
            ) * 0.5;

    #elif colorPreset == 2  // SEUS v08

        lightColor[0]   = daytimeColor(
            vec3(1.00, 0.63, 0.16) * 0.80 * vec3(1.0, 0.6, 0.5),
            vec3(1.00, 0.90, 0.61) * 1.30 * vec3(1.1, 1.0, 0.91),
            vec3(1.00, 0.63, 0.16) * 0.80 * vec3(1.0, 0.55, 0.6),
            vec3(1.00, 0.20, 0.00) * 0.40
            ) * 2.5;

        lightColor[1]   = vec3(0.2, 0.3, 1.0) * 0.05;

        //vec3 skylightColor = mix(linearSky, lightColor[0] / euler, 0.3);

        lightColor[2]   = daytimeColor(
            vec3(1.00, 1.00, 1.00) * 0.30 * vec3(0.2, 0.55, 1.0),
            vec3(0.37, 0.72, 1.00) * 0.50 * vec3(0.7, 0.95, 1.0),
            vec3(1.00, 1.00, 1.00) * 0.30 * vec3(0.35, 0.45, 1.0),
            vec3(0.30, 0.50, 1.00) * 0.012 * vec3(0.35, 0.5, 1.0)
            ) * 0.4;

    #elif colorPreset == 3

        lightColor[0]   = daytimeColor(
            vec3(1.00, 0.53, 0.09) * 1.00,
            vec3(1.00, 0.79, 0.58) * 1.20,
            vec3(1.00, 0.53, 0.09) * 1.00,
            vec3(1.00, 0.20, 0.00) * 0.40
            ) * 2.5;

        lightColor[1]   = vec3(0.26, 0.53, 1.0) * 0.05;

        //vec3 skylightColor = mix(linearSky, lightColor[0] / euler, 0.3);

        lightColor[2]   = daytimeColor(
            vec3(0.39, 0.39, 1.00) * 0.50,
            vec3(0.46, 0.46, 1.00) * 0.90,
            vec3(0.46, 0.46, 1.00) * 0.50,
            vec3(0.13, 0.22, 1.00) * 0.012
            ) * 0.6;

    #elif colorPreset == 4

        lightColor[0]   = daytimeColor(
            vec3(1.00, 0.53, 0.07) * 1.00,
            vec3(1.00, 0.79, 0.58) * 1.20,
            vec3(1.00, 0.53, 0.09) * 1.00,
            vec3(1.00, 0.20, 0.00) * 0.40
            ) * 2.5;

        lightColor[1]   = vec3(0.26, 0.39, 1.0) * 0.05;

        //vec3 skylightColor = mix(linearSky, lightColor[0] / euler, 0.3);

        lightColor[2]   = daytimeColor(
            vec3(0.39, 0.39, 1.00) * 0.50,
            vec3(0.46, 0.46, 1.00) * 0.90,
            vec3(0.46, 0.46, 1.00) * 0.50,
            vec3(0.13, 0.22, 1.00) * 0.012
            ) * 0.6;

    #elif colorPreset == 5

        lightColor[0]   = daytimeColor(
            vec3(1.00, 0.61, 0.17) * 1.00,
            vec3(1.00, 0.93, 0.9) * 1.20,
            vec3(1.00, 0.61, 0.17) * 1.00,
            vec3(1.00, 0.20, 0.00) * 0.40
            ) * 2.5;

        lightColor[1]   = vec3(0.26, 0.53, 1.0) * 0.05;

        //vec3 skylightColor = mix(linearSky, lightColor[0] / euler, 0.3);

        lightColor[2]   = daytimeColor(
            vec3(0.78, 0.78, 1.00) * 0.50,
            vec3(0.89, 0.89, 1.00) * 0.80,
            vec3(0.78, 0.78, 1.00) * 0.50,
            vec3(0.13, 0.22, 1.00) * 0.012
            ) * 0.6;

    #endif

    lightColor[3]   = vec3(1.00, 0.7, 0.4);

    lightColor[0]  *= daytimeColor(
            vec3(sunlightSunriseR, sunlightSunriseG, sunlightSunriseB) * sunlightSunriseL,
            vec3(sunlightNoonR, sunlightNoonG, sunlightNoonB) * sunlightNoonL,
            vec3(sunlightSunsetR, sunlightSunsetG, sunlightSunsetB) * sunlightSunsetL,
            vec3(sunlightNightR, sunlightNightG, sunlightNightB) * sunlightNightL
    );

    lightColor[2]  *= daytimeColor(
            vec3(skylightSunriseR, skylightSunriseG, skylightSunriseB) * skylightSunriseL,
            vec3(skylightNoonR, skylightNoonG, skylightNoonB) * skylightNoonL,
            vec3(skylightSunsetR, skylightSunsetG, skylightSunsetB) * skylightSunsetL,
            vec3(skylightNightR, skylightNightG, skylightNightB) * skylightNightL
    );

    lightColor[0]   = mix(lightColor[0], vec3(avgOf(lightColor[0]) * 0.05), wetness * 0.9);
    lightColor[1]   = mix(lightColor[1], vec3(avgOf(lightColor[1]) * 0.03), wetness * 0.9) * RMoonPhaseOcclusion;
    lightColor[2]   = mix(lightColor[2], vec3(avgOf(lightColor[2]) * 1.41), wetness * 0.9);
}