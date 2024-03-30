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

#ifndef gTRANSLUCENT
    /* RENDERTARGETS: 0,1,2 */
    layout(location = 0) out vec4 sceneColor;
    layout(location = 1) out vec4 GData;
    layout(location = 2) out vec4 lightingData;
#else
    /* RENDERTARGETS: 5,1,2,7 */
    layout(location = 0) out vec4 sceneColor;
    layout(location = 1) out vec4 GData;
    layout(location = 2) out vec4 lightingData;
    layout(location = 3) out vec4 sceneTint;
#endif

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"
#include "/lib/util/encoders.glsl"

in vec2 uv;
in vec2 lightmapUV;

flat in vec3 vertexNormal;

in vec4 tint;

#ifdef gTERRAIN
    flat in int matID;

    uniform float frameTimeCounter;
#endif

#ifdef gTEXTURED
    uniform sampler2D gcolor;
    uniform sampler2D specular;

    #ifdef normalmapEnabled
        flat in mat3 tbn;

        uniform sampler2D normals;

        vec3 decodeNormalTexture(vec3 ntex, inout float materialAO) {
            if(all(lessThan(ntex, vec3(0.003)))) return vertexNormal;

            vec3 nrm    = ntex * 2.0 - (254.0 * rcp(255.0));

            #if normalmapFormat==0
                nrm.z  = sqrt(saturate(1.0 - dot(nrm.xy, nrm.xy)));
                materialAO = ntex.z;
            #elif normalmapFormat==1
                materialAO = length(nrm);
                nrm    = normalize(nrm);
            #endif

            return normalize(tbn * nrm);
        }
    #endif

    #ifdef gENTITY
        uniform int entityId;
        uniform vec4 entityColor;
    #endif
#endif

const bool shadowHardwareFiltering = true;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform vec3 lightDir;

in vec3 shadowPosition;

flat in vec3 directColor;
flat in mat4x3 lightColor;

float diffuseLambert(vec3 normal, vec3 direction) {
    return saturate(dot(normal, direction));
}

#define FUTIL_LIGHTMAP
#include "/lib/fUtil.glsl"


/*
    This offset thing is from spectrum, and zombye has it from here:
    http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
*/
vec2 R2(float n) {
	const float s0 = 0.5;
	const vec2 alpha = 1.0 / vec2(rho, rho * rho);
	return fract(n * alpha + s0);
}

uniform sampler2D noisetex;

uniform int frameCounter;

#include "/lib/frag/bluenoise.glsl"
#include "/lib/shadowconst.glsl"

vec3 ReadShadowColor(ivec2 Pixel) {
    vec4 Sample = texelFetch(shadowcolor0, Pixel, 0);

    return mix(vec3(1.0), Sample.rgb, Sample.a);
}
vec3 GetSampleColor(vec3 Color, float SolidOcclusion, float TranslucentOcclusion) {
    if (TranslucentOcclusion >= SolidOcclusion) Color = vec3(1.0);

    return SolidOcclusion * Color;
}

vec3 GetShadowBilinear(vec3 uv) {
    ivec2 ShadowRes = ivec2(shadowMapResolution);

    ivec2 SamplePixel = ivec2(uv.xy * ShadowRes - 0.5);

    vec4 OcclusionSamples = textureGather(shadowtex1, uv.xy, uv.z).wzxy;
    vec4 OcclusionSamples_T = textureGather(shadowtex0, uv.xy, uv.z).wzxy;

    vec3[4] ColorSamples = vec3[4](
        ReadShadowColor(SamplePixel + ivec2(0,0)),
        ReadShadowColor(SamplePixel + ivec2(1,0)),
        ReadShadowColor(SamplePixel + ivec2(0,1)),
        ReadShadowColor(SamplePixel + ivec2(1,1))
    );

    vec2 PixelFract = fract(uv.xy * ShadowRes - 0.5);

    vec3 Color0 = mix(GetSampleColor(ColorSamples[0], OcclusionSamples[0], OcclusionSamples_T[0]), GetSampleColor(ColorSamples[1], OcclusionSamples[1], OcclusionSamples_T[1]), PixelFract.x);
    vec3 Color1 = mix(GetSampleColor(ColorSamples[2], OcclusionSamples[2], OcclusionSamples_T[2]), GetSampleColor(ColorSamples[3], OcclusionSamples[3], OcclusionSamples_T[3]), PixelFract.x);

    return mix(Color0, Color1, PixelFract.y);
}

vec3 shadowFiltered(vec3 position) {

    float dither   = ditherBluenoise();

    const float sigma = shadowmapPixel.x * sqrt2 * shadowFilterSize;

    vec3 total  = vec3(0);

    for (uint i = 0; i < shadowFilterIterations; ++i) {
        vec2 offset     = R2((i + dither) * 64.0);
            offset      = vec2(cos(offset.x * tau), sin(offset.x * tau)) * sqrt(offset.y);

        vec3 uv         = position + vec3(offset * sigma, 0.0);

        //float shadow    = texture(shadowtex1, uv);
        //vec4 color      = vec4(1,1,1,0);

        //if (texture(shadowtex0, uv) < shadow) color = texture(shadowcolor0, uv.xy);

        //total          += shadow * mix(vec3(1), color.rgb, color.a);
        total += GetShadowBilinear(uv);
    }
    total  /= float(shadowFilterIterations);

    return total;
}

vec4 packReflectionAux(vec3 directLight, vec3 albedo) {
    vec4 lightRGBE  = encodeRGBE8(directLight);
    vec4 albedoRGBE = encodeRGBE8(albedo);

    return vec4(pack2x8(lightRGBE.xy),
                pack2x8(lightRGBE.zw),
                pack2x8(albedoRGBE.xy),
                pack2x8(albedoRGBE.zw));
}

#if (defined gTRANSLUCENT && defined gTERRAIN)

in float viewDist;
in vec3 worldPos;

#include "/lib/util/bicubic.glsl"

#include "/lib/atmos/waterWaves.glsl"

vec3 waterNormal() {
    vec3 pos    = worldPos;

    float dstep   = 0.005 + (1.0 - exp(-viewDist * rcp(32.0))) * 0.035;

    vec2 delta;
        delta.x     = waterWaves(pos + vec3( dstep, 0.0, -dstep));
        delta.y     = waterWaves(pos + vec3(-dstep, 0.0,  dstep));
        delta      -= waterWaves(pos + vec3(-dstep, 0.0, -dstep));

    return normalize(vec3(-delta.x, 2.0 * dstep, -delta.y));
}

#endif

void main() {
    vec3 sceneNormal    = vertexNormal;
    vec4 sceneMaterial  = vec4(0.0);
    float occlusion     = 1.0;

    #ifndef gTERRAIN
    const int matID     = 1;
    #endif

    #ifdef gTEXTURED
        sceneColor      = texture(gcolor, uv);
        if (sceneColor.a < 0.1) discard;

        sceneColor.rgb *= tint.rgb;

        #ifdef normalmapEnabled
        sceneNormal     = decodeNormalTexture(texture(normals, uv).rgb, occlusion);
        #endif

        #ifdef gTRANSLUCENT
        sceneColor.a    = pow(sceneColor.a, 1.0);
        sceneColor.a    = 0.1 + sqr(linStep(sceneColor.a, 0.1, 1.0)) * 0.9;
        #endif

        sceneMaterial   = texture(specular, uv);

        #ifdef gENTITY
            if (entityId == 999) discard;
            sceneColor.rgb = mix(sceneColor.rgb, entityColor.rgb, entityColor.a);
        #endif
    #else
        sceneColor      = tint;
        if (sceneColor.a<0.01) discard;
        sceneColor.a    = 1.0;
    #endif

    sceneColor.rgb      = toLinear(sceneColor.rgb);

    #if (defined gTRANSLUCENT && defined gTERRAIN)
        if (matID == 102) {
            #ifdef customWaterNormals
            sceneNormal     = waterNormal();
            #endif

            #ifdef customWaterColor
            sceneColor      = vec4(waterRed, waterGreen, waterBlue, max(waterAlpha, 0.101));
            #endif
        }
    #endif


    #ifdef gTRANSLUCENT
    sceneTint           = sceneColor;
    sceneTint.rgb       = normalize(max(sceneColor.rgb, 1e-3));
    sceneTint.a         = sqrt(sceneTint.a);
    #endif

    float diffuse       = mix(diffuseLambert(sceneNormal, lightDir), 1.0, float(matID == 2) * rpi);
        diffuse        /= sqrt2;

    vec3 shadow         = vec3(diffuse);
    if (diffuse > 1e-8) shadow *= shadowFiltered(shadowPosition);

    occlusion          *= sqr(tint.a) * 0.9 + 0.1;
    //#if colorPreset >=2
    //occlusion *= (tint.a) * 0.9 + 0.1;
    //#endif

    vec3 directLight    = directColor * shadow;
        directLight    *= occlusion * 0.9 + 0.1;

    #ifdef UseLightleakPrevention
        directLight    *= sstep(lightmapUV.y, 0.1, 0.2);
    #endif

    #if DIM == 1

    vec3 indirectLight  = lightColor[2];

    #else

    vec3 indirectLight  = cube(lightmapUV.y) * lightColor[2];
        indirectLight  += pow6(linStep(lightmapUV.y, 0.33, 1.0)) * directColor * 0.025;
        indirectLight  += vec3(0.4, 0.6, 1.0) * 0.005;

    #endif

        indirectLight  *= occlusion;

    vec3 blockLight     = getBlocklightMap(lightColor[3], lightmapUV.x);
        blockLight     *= occlusion;
    if (lightmapUV.x > (15.0/16.0) || matID == 5) {
        float albedoLum = getLuma(sceneColor.rgb);
            albedoLum   = mix(cube(albedoLum), albedoLum, albedoLum);
        blockLight += lightColor[3] * pi * albedoLum;
    } else if (matID == 6) {
        float albedoLum = getLuma(sceneColor.rgb);
            albedoLum   = mix(cube(albedoLum), albedoLum, albedoLum);
        blockLight += lightColor[3] * albedoLum;
    }

    lightingData    = packReflectionAux(directLight, sceneColor.rgb);

    sceneColor.rgb *= directLight + indirectLight + blockLight;

    GData.xy        = encodeNormal(sceneNormal);
    GData.z         = pack2x8(vec2(lightmapUV.y, float(matID) / 255.0));
    GData.w         = pack2x8(sceneMaterial.xy);
}