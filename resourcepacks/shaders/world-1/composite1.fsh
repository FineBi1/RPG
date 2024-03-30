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

flat in mat3 colorPalette;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform int frameCounter;
uniform int isEyeInWater;

uniform float eyeAltitude;
uniform float far, near;
uniform float frameTimeCounter;

uniform float worldAnimTime;

uniform vec2 taaOffset;
uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferModelView;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#include "/lib/util/bicubic.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/atmos/project.glsl"

vec3 getFog(vec3 color, float dist, vec3 skyColor) {
	    dist 	= dist / far;
		dist 	= max((dist - fogStart * 0.25), 0.0);
        dist   /= 1.0 - fogStart;
        
	float alpha = 1.0-exp(-dist * fogFalloff);

	color 	= mix(color, skyColor, saturate(alpha));

	return color;
}

vec3 getWaterFog(vec3 color, float dist, vec3 tint){
	    dist 	= dist / pi;
		dist 	= max((dist), 0.0) * waterFogFalloff;
        
	float alpha = 1.0-exp(-dist / euler);

    vec3 waterCoeff     = vec3(waterFogRed, waterFogGreen, waterFogBlue);

    #ifdef waterFogVanillaColor
    if (isEyeInWater != 1) waterCoeff = tint;
    #endif
    
        waterCoeff     /= maxOf(waterCoeff);

    vec3 extinctCoeff   = 1.0 / max(waterCoeff, vec3(1e-6));
        extinctCoeff   /= maxOf(extinctCoeff);

    vec3 extinctionCoeff = extinctCoeff * sqrt3;

    color  *= exp(-dist * extinctionCoeff);

    vec3 scatterColor = colorPalette[1] * waterCoeff / pi4 / pi;

	color 	= mix(color, scatterColor, saturate(sqr(alpha)));

	return color;
}

/* ------ Reflections ------ */
#define NOSKY
#include "/lib/frag/reflection.glsl"

void main() {
    sceneColor  = texture(colortex0, uv).rgb;

    vec4 GData          = texture(colortex1, uv);
    int matID           = int(unpack2x8(GData.z).y * 255.0);

    vec4 translucencyColor  = texture(colortex5, uv);

    vec2 sceneDepth     = vec2(texture(depthtex0, uv).x, texture(depthtex1, uv).x);

    vec3 position0      = vec3(uv, sceneDepth.x);
        position0       = screenToViewSpace(position0);

    vec3 position1      = vec3(uv, sceneDepth.y);
        position1       = screenToViewSpace(position1);

    mat2x3 scenePos     = mat2x3(viewToSceneSpace(position0), viewToSceneSpace(position1));

    vec3 translucencyAbsorption = texture(colortex7, uv).rgb;

    if (matID == 102 && isEyeInWater == 0) {
        sceneColor = getWaterFog(sceneColor, distance(position0, position1), translucencyAbsorption);
        translucencyAbsorption  = vec3(1);
    } else if (landMask(sceneDepth.y)) {
        #ifdef fogEnabled
        sceneColor  = getFog(sceneColor, distance(position0, position1), colorPalette[1]);
        #endif
    }

    sceneColor  = sceneColor * sqr(translucencyAbsorption) * (1.0 - translucencyColor.a) + translucencyColor.rgb;

    #ifdef reflectionsEnabled
    if (landMask(sceneDepth.x)) {
        vec3 sceneNormal = decodeNormal(GData.xy);
        vec3 viewNormal = mat3(gbufferModelView) * sceneNormal;

        vec3 viewDir    = normalize(position0);

        float lightmap  = saturate(unpack2x8(GData.z).x);

        bool water      = matID == 102;

        mat2x3 reflectionAux = unpackReflectionAux(texture(colortex2, uv));

        materialProperties material = materialProperties(1.0, 0.02, false, false, mat2x3(0.0));
        if (water) material = materialProperties(0.0001, 0.02, false, false, mat2x3(0.0));
        else material   = decodeLabBasic(unpack2x8(GData.w));

        if (dot(viewDir, viewNormal) > 0.0) viewNormal = -viewNormal;

        vec3 reflectDir = reflect(viewDir, viewNormal);
        
        vec4 reflection = vec4(0.0);
        vec3 fresnel    = vec3(0.0);

        float skyOcclusion  = cubeSmooth(sqr(linStep(lightmap, skyOcclusionThreshold - 0.2, skyOcclusionThreshold)));

        #ifdef resourcepackReflectionsEnabled
            /* --- ROUGH REFLECTIONS --- */

            float roughnessFalloff  = 1.0 - (linStep(material.roughness, roughnessThreshold * 0.71, roughnessThreshold));

            #ifdef roughReflectionsEnabled
            if (material.roughness < 0.0002 || water) {
            #endif

                vec3 reflectSceneDir = mat3(gbufferModelViewInverse) * reflectDir;

                #ifdef screenspaceReflectionsEnabled
                    vec3 reflectedPos = screenspaceRT(position0, reflectDir, ditherBluenoise());
                    if (reflectedPos.z < 1.0) reflection += vec4(texelFetch(colortex0, ivec2(reflectedPos.xy * viewSize), 0).rgb, 1.0);
                    else reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                #else
                    reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                #endif

                    if (clamp16F(reflection) != reflection) reflection = vec4(0.0);

                    fresnel    += BRDFfresnelAlbedoTint(-viewDir, viewNormal, material, reflectionAux[1]);

            #ifdef roughReflectionsEnabled

            } else {
                mat3 rot        = getRotationMat(vec3(0, 0, 1), viewNormal);
                vec3 tangentV   = viewDir * rot;
                float noise     = ditherBluenoise();
                float dither    = ditherGradNoiseTemporal();

                const uint steps    = roughReflectionSamples;
                const float rSteps  = 1.0 / float(steps);

                for (uint i = 0; i < steps; ++i) {
                    if (roughnessFalloff <= 1e-3) break;
                    vec2 xy         = vec2(fract((i + noise) * sqr(32.0) * phi), (i + noise) * rSteps);
                    vec3 roughNrm   = rot * ggxFacetDist(-tangentV, material.roughness, xy);

                    vec3 reflectDir = reflect(viewDir, roughNrm);

                    vec3 reflectSceneDir = mat3(gbufferModelViewInverse) * reflectDir;

                    #ifdef screenspaceReflectionsEnabled
                        vec3 reflectedPos       = vec3(1.1);
                        if (material.roughness < 0.3) reflectedPos = screenspaceRT(position0, reflectDir, dither);
                        else if (material.roughness < 0.7) reflectedPos = screenspaceRT_LR(position0, reflectDir, dither);

                        if (reflectedPos.z < 1.0) reflection += vec4(texelFetch(colortex0, ivec2(reflectedPos.xy * viewSize), 0).rgb, 1.0);
                        else reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                    #else
                        reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                    #endif

                        fresnel    += BRDFfresnelAlbedoTint(-viewDir, roughNrm, material, reflectionAux[1]);
                }
                if (clamp16F(reflection) != reflection) reflection = vec4(0.0);

                reflection *= rSteps;
                fresnel    *= rSteps;

                reflection.a *= roughnessFalloff;
            }

            #else
                reflection.a *= roughnessFalloff;
            #endif

            if (material.conductor) sceneColor.rgb = mix(sceneColor.rgb, reflection.rgb * fresnel, reflection.a);
            else sceneColor.rgb = mix(sceneColor.rgb, reflection.rgb, fresnel * reflection.a);   

            //sceneColor.rgb = reflection.rgb;         
        #else
            /* --- WATER REFLECTIONS --- */
            if (water) {
                vec3 reflectSceneDir = mat3(gbufferModelViewInverse) * reflectDir;

                #ifdef screenspaceReflectionsEnabled
                    vec3 reflectedPos = screenspaceRT(position0, reflectDir, ditherBluenoise());
                    if (reflectedPos.z < 1.0) reflection += vec4(texelFetch(colortex0, ivec2(reflectedPos.xy * viewSize), 0).rgb, 1.0);
                    else reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                #else
                    reflection += readSpherePositionAware(skyOcclusion, scenePos[0], reflectSceneDir);
                #endif

                    if (clamp16F(reflection) != reflection) reflection = vec4(0.0);

                    fresnel    += BRDFfresnel(-viewDir, viewNormal, material, reflectionAux[1]);
                sceneColor.rgb = mix(sceneColor.rgb, reflection.rgb, fresnel * reflection.a);
            }   
        #endif
    }
    #endif

    #ifdef fogEnabled
        if (isEyeInWater == 0 && landMask(sceneDepth.x)) sceneColor  = getFog(sceneColor, length(position0), colorPalette[1]);
    #endif

    if (isEyeInWater == 1) sceneColor = getWaterFog(sceneColor, length(position0), vec3(1));
}