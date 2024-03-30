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

/* RENDERTARGETS: 0,2 */
layout(location = 0) out vec3 sceneColor;
layout(location = 1) out vec3 godrayMask;


#include "/lib/head.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;

flat in mat4x3 lightColor;

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
uniform int worldTime;

uniform float eyeAltitude, wetness;
uniform float far, near;
uniform float frameTimeCounter;
uniform float cloudLightFlip;
uniform float sunAngle;
uniform float lightFlip;
uniform float worldAnimTime;

uniform vec2 taaOffset;
uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition;
uniform vec3 lightDirView;
uniform vec3 cloudLightDir, cloudLightDirView;

uniform vec4 daytime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferModelView;

#define FUTIL_LINDEPTH
#include "/lib/fUtil.glsl"

#include "/lib/frag/bluenoise.glsl"
#include "/lib/frag/gradnoise.glsl"

#include "/lib/util/bicubic.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/atmos/project.glsl"

vec3 getFog(vec3 color, float dist, vec3 skyColor, vec3 sceneDir) {
	    dist 	= dist / far;
		dist 	= max((dist - fogStart), 0.0);
        dist   /= 1.0 - fogStart;
        
	float alpha = 1.0-exp(-dist * fogFalloff);
        alpha *= alpha;
        alpha  *= cube(1.0 - max0(sceneDir.y));

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

    vec3 scatterColor = lightColor[2] * waterCoeff / pi4 / pi;

	color 	= mix(color, scatterColor, saturate(sqr(alpha)));

	return color;
}

float mieHG(float cosTheta, float g) {
    float mie   = 1.0 + sqr(g) - 2.0*g*cosTheta;
        mie     = (1.0 - sqr(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));
    return mie;
}

#include "/lib/atmos/clouds.glsl"


vec4 RSKY_VanillaClouds(vec3 WorldDirection, vec3 WorldPosition, float Dither, bool IsTerrain, vec3 SkyColor, out float HitDistance) {
    vec4 Result = vec4(0,0,0,1);

    vec3 DirectColor    = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[1];
        DirectColor    *= cloudLightFlip;
    vec3 AmbientColor   = lightColor[2] * (1.0 - sqrt(daytime.w)*0.96) * euler;
    float vDotL         = dot(WorldDirection, cloudLightDir);

    float IsWithin      = sstep(eyeAltitude, float(RSKY_Volume_Limits.x) - 15.0, float(RSKY_Volume_Limits.x)) * (1.0 - sstep(eyeAltitude, RSKY_Volume_Limits.y, RSKY_Volume_Limits.y + 15.0));
    bool IsBelow        = eyeAltitude < cloudVolMidY;
    bool IsVisible      = WorldDirection.y > 0.0 && IsBelow || WorldDirection.y < 0.0 && !IsBelow;

    #ifdef cloudVolumeStoryMode
        const float SigmaA  = 0.5;
            AmbientColor       /= sqrt2;
        const float SigmaT  = 0.31;
    #else
        const float SigmaA  = 0.41;
        const float SigmaT  = 0.66;
    #endif

    const float Albedo = 0.93;
    const float ScatterMult = 1.0;

    HitDistance     = far * 2.0;

    if (IsVisible || IsWithin > 0.0) {
        mat2x3 VolumeBounds = mat2x3(GetPlane(RSKY_Volume_Limits.x, WorldDirection),
                                     GetPlane(RSKY_Volume_Limits.y, WorldDirection));

        if (WorldDirection.y < 0.0 && IsBelow ||
            WorldDirection.y > 0.0 && !IsBelow) VolumeBounds = mat2x3(0.0);

        vec3 StartPos      = IsBelow ? VolumeBounds[0] : VolumeBounds[1];
        vec3 EndPos        = IsBelow ? VolumeBounds[1] : VolumeBounds[0];
            StartPos       = mix(StartPos, gbufferModelViewInverse[3].xyz, IsWithin);
            EndPos         = mix(EndPos, WorldDirection * cloudVolumeClip / pi, IsWithin);

        if (IsTerrain) {
            if (length(EndPos) > length(WorldPosition)) EndPos = WorldPosition;
        }

        const float BaseStep = cloudVolumeDepth / (float(cloudVolumeSamples));
        float StepLength = abs(distance(StartPos, EndPos) / float(cloudVolumeSamples));

        float StepCoeff = 0.5 + clamp(((StepLength / BaseStep) - 1.0) / sqrt2, 0.0, 1.0);
        uint StepCount  = uint(max(cloudVolumeSamples * StepCoeff, cloudVolumeDepth / euler));

        vec3 RStep          = (EndPos - StartPos) / float(StepCount);
        vec3 RPosition      = RStep * Dither + StartPos + cameraPosition;
        float RLength       = length(RStep);

        for (uint I = 0; I < StepCount; ++I, RPosition += RStep) {
            if (Result.a < 0.01) break;
            if (RPosition.y < RSKY_Volume_Limits.x || RPosition.y > RSKY_Volume_Limits.y) continue;

            float SampleDistance  = distance(RPosition, cameraPosition);
            if (SampleDistance > cloudVolumeClip) continue;

            float Density = cloudVolumeShape(RPosition);
            if (Density <= 0.0) continue;

            HitDistance = min(HitDistance, SampleDistance);

            float StepOpticalDepth = Density * SigmaT * RLength;
            float StepTransmittance = exp(-StepOpticalDepth);

            vec3 StepScattering = vec3(0);

            vec2 LightExtinction = vec2(cloudVolumeLightOD(RPosition, 5, cloudLightDir),
                                        approxSkylightDensity(RPosition)
                                       ) * SigmaA;


            float AvgTransmittance = exp(-((tau / SigmaT) * Density));
            float BounceEstimate = EstimateEnergy(Albedo * (1.0 - AvgTransmittance));
            float BaseScatter = Albedo * (1.0 - StepTransmittance);
            vec3 PhaseG = pow(vec3(0.5, 0.35, 0.9), vec3((1.0 + (LightExtinction.x + Density * RLength) * SigmaT)));

            float DirScatterScale = pow(1.0 + 1.0 * LightExtinction.x * SigmaT, -1.0 / 1.0) * BounceEstimate;
            float AmbScatterScale = pow(1.0 + 1.0 * LightExtinction.y * SigmaT, -1.0 / 1.0) * BounceEstimate;

                StepScattering.xy = BaseScatter * vec2(cloudPhase(vDotL, PhaseG) * DirScatterScale,
                                                    cloudPhaseSky(WorldDirection.y, PhaseG * vec3(1,1,0.5)) * AmbScatterScale);

            float SkyFade = exp(-SampleDistance * 4e-3);
                SkyFade = mix(SkyFade, 0.0, sstep(SampleDistance, float(cloudVolumeClip) * 0.75, float(cloudVolumeClip)));
                StepScattering = DirectColor * StepScattering.x + AmbientColor * StepScattering.y;
                StepScattering = mix(SkyColor * (1.0 - StepTransmittance), StepScattering, SkyFade);

            Result = vec4((StepScattering * Result.a) + Result.rgb, Result.a * StepTransmittance);
        }

        Result.a = linStep(Result.a, 0.01, 1.0) * 0.99 + 0.01;

        Result      = mix(Result, vec4(0,0,0,1), exp(-max0(WorldDirection.y * pi4)) * (1.0 - sstep(eyeAltitude, RSKY_Volume_Limits.x - 16.0, RSKY_Volume_Limits.x)));
    }

    return Result;
}
#if 0
vec4 volumetricClouds(vec3 worldDir, vec3 worldPos, float vDotL, float dither, bool terrain, vec3 skyColor, out float hitDistance) {
    vec3 totalScattering    = vec3(0.0);
    float totalTransmittance = 1.0;

    vec3 sunlight       = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[1];
        sunlight       *= cloudLightFlip * sqrt2;
    vec3 skylight       = lightColor[2] * (1.0 - sqrt(daytime.w)*0.96);

    float pFade         = saturate(mieHG(vDotL, 0.65));

    float within    = sstep(eyeAltitude, float(cloudVolumeAlt) - 15.0, float(cloudVolumeAlt)) * (1.0 - sstep(eyeAltitude, cloudVolMaxY, cloudVolMaxY + 15.0));
    bool isBelowVol = eyeAltitude < cloudVolMidY;
    bool visibleVol = worldDir.y > 0.0 && isBelowVol || worldDir.y < 0.0 && !isBelowVol;

    const float sigmaA  = 1.0;
    const float sigmaT  = 0.66;

    hitDistance     = far * 2.0;

    if (visibleVol || within > 0.0) {
        vec3 bottom     = worldDir * ((cloudVolumeAlt - eyeAltitude) * rcp(worldDir.y));
        vec3 top        = worldDir * ((cloudVolMaxY - eyeAltitude) * rcp(worldDir.y));

        if (worldDir.y < 0.0 && isBelowVol || worldDir.y > 0.0 && !isBelowVol) {
            bottom      = vec3(0.0);
            top         = vec3(0.0);
        }

        vec3 start      = isBelowVol ? bottom : top;
        vec3 end        = isBelowVol ? top : bottom;
            start       = mix(start, gbufferModelViewInverse[3].xyz, within);
            end         = mix(end, worldDir * cloudVolumeClip, within);

        if (terrain) end = worldPos;

        hitDistance     = min(length(bottom), length(top));

        float stepCoeff     = 1.0 + sqr(max(within, float(terrain))) * 4.0;
        uint steps          = uint(cloudVolumeSamples * stepCoeff);

        vec3 rStep          = (end - start) * rcp(float(steps));
        vec3 rPos           = rStep * dither + start + cameraPosition;
        float rLength       = length(rStep);

        vec3 scattering     = vec3(0.0);
        float transmittance = 1.0;

        for (uint i = 0; i < steps; ++i, rPos += rStep) {
            if (transmittance < 0.01) break;
            if (rPos.y < cloudVolumeAlt || rPos.y > cloudVolMaxY) continue;

            float dist  = distance(rPos, cameraPosition);
            if (dist > cloudVolumeClip) continue;

            float density = cloudVolumeShape(rPos);
            if (density <= 0.0) continue;

            float extinction    = density * sigmaT;
            float stepT         = exp(-extinction * rLength);
            float integral      = (1.0 - stepT) * rcp(sigmaT);

            vec3 stepScatter    = vec3(0.0);

            float lightOD       = cloudVolumeLightOD(rPos, 5, cloudLightDir) * sigmaA;
            float skyOD         = approxSkylightDensity(rPos) * sigmaA;

            float powder        = 8.0 * (1.0 - 0.97 * exp(-extinction * 18.0));

            float anisoPowder   = mix(powder, 1.0, pFade);

            vec3 phaseG         = pow(vec3(0.45, 0.25, 0.95), vec3(1.0 + lightOD));

            float phase = cloudPhase(vDotL, 1.0, phaseG);

            stepScatter.x  += max(expf(-lightOD * sigmaT), expf(-lightOD * sigmaT * 0.2) * 0.75) * phase * anisoPowder * sigmaT;
            stepScatter.y  += max(expf(-skyOD * sigmaT), expf(-skyOD * sigmaT * 0.2) * 0.75) * powder * sigmaT;

            stepScatter     = (sunlight * stepScatter.x) + (skylight * stepScatter.y);

            float atmosFade = expf(-dist * 4e-3);

            stepScatter     = mix(skyColor * sigmaT, stepScatter, atmosFade);

            scattering     += stepScatter * (integral * transmittance);

            transmittance  *= stepT;
        }

        transmittance       = linStep(transmittance, 0.01, 1.0);

        totalScattering    += scattering;
        totalTransmittance *= transmittance;
    }

    vec4 result     = vec4(totalScattering, totalTransmittance);
        result      = mix(result, vec4(0,0,0,1), exp(-max0(worldDir.y * pi4)) * (1.0 - within) * float(eyeAltitude < cloudVolumeAlt));

    return result;
}
#endif


/* ------ Reflections ------ */
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

    vec3 worldDir       = mat3(gbufferModelViewInverse) * normalize(position0);

    vec3 skyColor       = texture(colortex3, projectSky(worldDir, 0)).rgb;

    godrayMask  = vec3(1);

    #ifdef cloudVolumeEnabled
        float cloudDistance = far * 2.0;
        vec4 cloudData  = RSKY_VanillaClouds(worldDir, scenePos[0], ditherBluenoise(), landMask(sceneDepth.y), skyColor, cloudDistance);
        
        godrayMask *= cloudData.a;

        if (landMask(sceneDepth.x) && length(scenePos[0]) <= cloudDistance) {
            sceneColor  = sceneColor * cloudData.a + cloudData.rgb;
        }
    #endif

    vec3 translucencyAbsorption = texture(colortex7, uv).rgb;

    if (landMask(sceneDepth.x)) godrayMask *= sqr(translucencyAbsorption);
    if (landMask(sceneDepth.y)) godrayMask = vec3(0);

    if (matID == 102 && isEyeInWater == 0) {
        #ifdef waterFogEnabled
        sceneColor = getWaterFog(sceneColor, distance(position0, position1), translucencyAbsorption);
        translucencyAbsorption  = vec3(1);
        #endif
    } else if (landMask(sceneDepth.y)) {
        #ifdef fogEnabled
        sceneColor  = getFog(sceneColor, distance(position0, position1), skyColor, worldDir);
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
            reflectionAux[0] *= pi;
            reflectionAux[1] = saturate(reflectionAux[1]);

        vec3 directCol  = (sunAngle<0.5 ? lightColor[0] : lightColor[1]) * lightFlip;
            reflectionAux[0] = min(reflectionAux[0], directCol);

        materialProperties material = materialProperties(1.0, 0.02, false, false, mat2x3(0.0));
        if (water) material = materialProperties(0.01, 0.02, false, false, mat2x3(0.0));
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

        #ifdef specularHighlightsEnabled
        sceneColor.rgb += specularTrowbridgeReitzGGX(-viewDir, lightDirView, viewNormal, material, (reflectionAux[1])) * reflectionAux[0];
        #endif
    }
    #endif

    #ifdef fogEnabled
        if (isEyeInWater == 0 && landMask(sceneDepth.x)) sceneColor  = getFog(sceneColor, length(position0), skyColor, worldDir);
    #endif

    #ifdef waterFogEnabled
    if (isEyeInWater == 1) sceneColor = getWaterFog(sceneColor, length(position0), vec3(1));
    #endif

    #ifdef cloudVolumeEnabled
    if (!landMask(sceneDepth.x) || length(scenePos[0]) > cloudDistance) {
        sceneColor  = sceneColor * cloudData.a + cloudData.rgb;
    }
    #endif    

    //sceneColor.rgb = stex(colortex9).rgb;
}