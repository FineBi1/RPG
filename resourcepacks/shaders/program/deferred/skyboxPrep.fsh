/* RENDERTARGETS: 3 */
layout(location = 0) out vec3 skyCapture;

#include "/lib/head.glsl"

const vec2 viewSize     = vec2(512, 512);
const vec2 pixelSize    = 1.0 / viewSize;

in vec2 uv;

flat in mat2x3 skyColors;
flat in mat4x3 lightColor;

flat in vec3 sunDir;
flat in vec3 moonDir;

//uniform vec3 sunDir, moonDir;

uniform vec3 cloudLightDir;

uniform vec4 daytime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;

#include "/lib/atmos/project.glsl"

float mieHG(float cosTheta, float g) {
    float mie   = 1.0 + sqr(g) - 2.0*g*cosTheta;
        mie     = (1.0 - sqr(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));
    return mie;
}

vec3 skyGradient(vec3 direction) {
    float vDotS     = dot(direction, sunDir);
    float vDotM     = dot(direction, moonDir);

    float horizon   = exp(-max0(direction.y) * sqrPi);
        horizon     = mix(horizon, horizon * saturate(1.35 * mieHG(vDotS, 0.2) / 0.2), sqr(daytime.x + daytime.z) * 0.8);

    vec3 sky        = skyColors[0] * mix(normalize(max(skyColors[0], 1e-8)), vec3(1), 0.6);
        sky         = mix(sky, skyColors[1], horizon);
        sky        += lightColor[0] * mieHG(vDotS, 0.74) * rpi * (1 - daytime.w);
        sky        += lightColor[1] * mieHG(vDotM, 0.74) * rpi * sqrt(daytime.w);

    return sky;
}

uniform sampler2D colortex8;
uniform sampler2D noisetex;

uniform int frameCounter;
uniform int worldTime;
uniform float worldAnimTime, cloudLightFlip, wetness;

uniform vec3 cameraPosition;

const float eyeAltitude   = 64.0;

#include "/lib/frag/bluenoise.glsl"
#include "/lib/atmos/clouds.glsl"


vec4 RSKY_VanillaClouds(vec3 WorldDirection, float Dither, vec3 SkyColor) {
    vec4 Result = vec4(0,0,0,1);

    vec3 cameraPos      = vec3(cameraPosition.x, 64.0, cameraPosition.z);

    #define cameraPosition cameraPos

    vec3 DirectColor    = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[1];
        DirectColor    *= cloudLightFlip;
    vec3 AmbientColor   = lightColor[2] * (1.0 - sqrt(daytime.w)*0.96) * euler;
    float vDotL         = dot(WorldDirection, cloudLightDir);

    bool IsVisible      = WorldDirection.y > 0.0;

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

    if (IsVisible) {
        mat2x3 VolumeBounds = mat2x3(GetPlane(RSKY_Volume_Limits.x, WorldDirection),
                                     GetPlane(RSKY_Volume_Limits.y, WorldDirection));

        if (WorldDirection.y < 0.0) VolumeBounds = mat2x3(0.0);

        vec3 StartPos      = VolumeBounds[0];
        vec3 EndPos        = VolumeBounds[1];

        const float BaseStep = cloudVolumeDepth / (8.0);
        float StepLength = length((VolumeBounds[1] - VolumeBounds[0]) / (8.0));

        float StepCoeff = 0.5 + clamp(((StepLength / BaseStep) - 1.0) / sqrt2, 0.0, 1.0);
        uint StepCount  = uint(max(8.0 * StepCoeff, cloudVolumeDepth / euler));

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

            float StepOpticalDepth = Density * SigmaT * RLength;
            float StepTransmittance = exp(-StepOpticalDepth);
            float ScatterIntegral = (1.0 - StepTransmittance) / SigmaT;

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

        Result.a = linStep(Result.a, 0.01, 1.0);
    }

    #undef cameraPosition

    Result      = mix(Result, vec4(0,0,0,1), exp(-max0(WorldDirection.y * pi4)));

    return Result;
}

vec4 volumetricClouds(vec3 worldDir, float vDotL, float dither, vec3 skyColor) {
    vec3 totalScattering    = vec3(0.0);
    float totalTransmittance = 1.0;

    vec3 cameraPos      = vec3(cameraPosition.x, 64.0, cameraPosition.z);

    vec3 sunlight       = (worldTime>23000 || worldTime<12900) ? lightColor[0] : lightColor[1];
        sunlight       *= cloudLightFlip * sqrt2;
    vec3 skylight       = lightColor[2] * (1.0 - sqrt(daytime.w)*0.96);

    float pFade         = saturate(mieHG(vDotL, 0.65));

    bool isBelowVol = eyeAltitude < cloudVolMidY;
    bool visibleVol = worldDir.y > 0.0 && isBelowVol || worldDir.y < 0.0 && !isBelowVol;

    const float sigmaA  = 1.0;
    const float sigmaT  = 0.66;

    if (visibleVol) {
        vec3 bottom     = worldDir * ((cloudVolumeAlt - eyeAltitude) * rcp(worldDir.y));
        vec3 top        = worldDir * ((cloudVolMaxY - eyeAltitude) * rcp(worldDir.y));

        if (worldDir.y < 0.0 && isBelowVol || worldDir.y > 0.0 && !isBelowVol) {
            bottom      = vec3(0.0);
            top         = vec3(0.0);
        }

        vec3 start      = isBelowVol ? bottom : top;
        vec3 end        = isBelowVol ? top : bottom;

        float stepCoeff     = 1.0;
        uint steps          = uint(cloudVolumeSamples * stepCoeff);

        vec3 rStep          = (end - start) * rcp(float(steps));
        vec3 rPos           = rStep * dither + start + cameraPos;
        float rLength       = length(rStep);

        vec3 scattering     = vec3(0.0);
        float transmittance = 1.0;

        for (uint i = 0; i < steps; ++i, rPos += rStep) {
            if (transmittance < 0.01) break;
            if (rPos.y < cloudVolumeAlt || rPos.y > cloudVolMaxY) continue;

            float dist  = distance(rPos, cameraPos);
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
        result      = mix(result, vec4(0,0,0,1), exp(-max0(worldDir.y * pi4)) * float(eyeAltitude < cloudVolumeAlt));

    return result;
}

void main() {
    vec2 projectionUV   = fract(uv * vec2(1.0, 2.0));

    if (uv.y < 0.5) {
        // Clear Sky Capture
        vec3 direction  = unprojectSky(projectionUV);

        skyCapture      = skyGradient(direction);
    } else {
        // Sky Capture with Clouds (for Reflections)
        vec3 direction  = unprojectSky(projectionUV);

        skyCapture      = skyGradient(direction);
        skyCapture     *= mix(exp(-max0(-direction.y) * cube(euler)), 1.0, 0.071);

        #ifdef cloudVolumeEnabled
        vec4 clouds     = RSKY_VanillaClouds(direction, ditherBluenoiseStatic(),skyCapture);

        skyCapture      = skyCapture * clouds.a + clouds.rgb;
        #endif
    }
}