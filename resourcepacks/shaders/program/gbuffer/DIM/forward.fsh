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

uniform vec3 lightDir;

in vec3 shadowPosition;

flat in mat3 colorPalette;

#define FUTIL_LIGHTMAP
#include "/lib/fUtil.glsl"

vec4 packReflectionAux(vec3 directLight, vec3 albedo) {
    vec4 lightRGBE  = encodeRGBE8(directLight);
    vec4 albedoRGBE = encodeRGBE8(albedo);

    return vec4(pack2x8(lightRGBE.xy),
                pack2x8(lightRGBE.zw),
                pack2x8(albedoRGBE.xy),
                pack2x8(albedoRGBE.zw));
}

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

    #ifdef gTRANSLUCENT
    sceneTint           = sceneColor;
    sceneTint.rgb       = normalize(max(sceneColor.rgb, 1e-3));
    sceneTint.a         = sqrt(sceneTint.a);
    #endif

    occlusion          *= sqr(tint.a) * 0.9 + 0.1;

    vec3 indirectLight  = colorPalette[0];
        indirectLight  *= occlusion;

    vec3 blockLight     = getBlocklightMap(colorPalette[2], lightmapUV.x);
        blockLight     *= occlusion;
    if (lightmapUV.x > (15.0/16.0) || matID == 5) {
        float albedoLum = getLuma(sceneColor.rgb);
            albedoLum   = mix(cube(albedoLum), albedoLum, albedoLum);
        blockLight += colorPalette[2] * pi * albedoLum;
    } else if (matID == 6) {
        float albedoLum = getLuma(sceneColor.rgb);
            albedoLum   = mix(cube(albedoLum), albedoLum, albedoLum);
        blockLight += colorPalette[2] * albedoLum;
    }

    lightingData    = packReflectionAux(vec3(0), sceneColor.rgb);

    sceneColor.rgb     *= indirectLight + blockLight;

    GData.xy        = encodeNormal(sceneNormal);
    GData.z         = pack2x8(vec2(lightmapUV.y, float(matID) / 255.0));
    GData.w         = pack2x8(sceneMaterial.xy);
}