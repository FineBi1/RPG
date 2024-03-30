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
layout(location = 0) out vec3 sceneColor;


#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

flat in mat4x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;

uniform sampler2D noisetex;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float eyeAltitude;
uniform float far, near;
uniform float frameTimeCounter;
uniform float lightFlip, sunAngle;

uniform float worldAnimTime;

uniform vec2 taaOffset;

uniform vec3 cameraPosition;
uniform vec3 lightDir, lightDirView;
uniform vec3 shadowLightPosition;

uniform vec4 daytime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferModelView;

#include "/lib/frag/bluenoise.glsl"

#include "/lib/util/bicubic.glsl"
#include "/lib/util/transforms.glsl"

float mieHG(float cosTheta, float g) {
    float mie   = 1.0 + sqr(g) - 2.0*g*cosTheta;
        mie     = (1.0 - sqr(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));
    return mie;
}

vec3 getGodrays(vec3 viewDirection, vec3 lightPos) {
    float vis   = sstep(lightDir.y, 0.0, 0.1);

    if (isEyeInWater == 1) return vec3(0);

    float vDotL     = dot(viewDirection, lightDirView);

    float sunGlow   = sqr(max0(vDotL)) * vis;
        sunGlow    *= mieHG(vDotL, 0.74);

    vec3 total      = vec3(0);

    vec3 directColor = (sunAngle < 0.5 ? lightColor[0] : lightColor[1] * 0.5) * lightFlip;

    if (sunGlow > 1e-6) {
        vec4 lightPos   = vec4(shadowLightPosition, 1) * gbufferProjection;
            lightPos.xyz /= infClamp(lightPos.w);
            lightPos.xy  /= infClamp(lightPos.z);

        vec2 lightUV    = lightPos.xy * 0.5 + 0.5;

        float truepos   = shadowLightPosition.z/abs(shadowLightPosition.z);

        vec2 stepUV     = (lightUV - uv) * godraySize;
            stepUV     /= godraySamples;

        vec2 sampleUV   = uv + stepUV * ditherBluenoise();

        float edgeFade  = 1.0 - sstep(maxOf(abs(lightPos.xy)), 0.66, 1.0);

        if (edgeFade > 1e-6) {
            for (uint i = 0; i < godraySamples; ++i, sampleUV += stepUV) {
                vec3 mask   = texture(colortex2, sampleUV).rgb;
                total      += mask * cubeSmooth(1.0 - (float(i) / godraySamples));
            }

            total          /= godraySamples;
            total          *= edgeFade;
        }
    }

    return max0(total) * directColor * sunGlow * godrayIntensity;
}
void main() {
    sceneColor  = texture(colortex0, uv).rgb;

    #ifdef godraysEnabled
    vec3 viewDirection = screenToViewSpace(vec3(uv, texture(depthtex0, uv).x));
    sceneColor += getGodrays(normalize(viewDirection), shadowLightPosition);
    #endif
}