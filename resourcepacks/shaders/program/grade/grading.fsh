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

/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec3 sceneImage;
layout(location = 1) out vec4 temporal;

#include "/lib/head.glsl"
#include "/lib/util/colorspace.glsl"

#define INFO 0  //[0]

/* ------ color grading related settings ------ */
//#define doColorgrading

#define vibranceInt 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define saturationInt 1.00     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define gammaCurve 1.00        //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define brightnessInt 0.00     //[-0.50 -0.45 -0.40 -0.35 -0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.5]
#define constrastInt 1.00      //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define colorlumR 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlumG 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlumB 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define vignetteEnabled
#define vignetteStart 0.15     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteEnd 0.85       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteIntensity 0.75 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignetteExponent 1.50  //[0.50 0.75 1.0 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]

#define CONE_OVERLAP_SIMULATION 0.75 // [0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1]


const mat3 coneOverlapMatrix2Deg = mat3(
    mix(vec3(1.0, 0.0, 0.0), vec3(0.5595088340965042, 0.39845359892109633, 0.04203756698239944), vec3(CONE_OVERLAP_SIMULATION)),
    mix(vec3(0.0, 1.0, 0.0), vec3(0.43585871315661756, 0.5003841413971261, 0.06375714544625634), vec3(CONE_OVERLAP_SIMULATION)),
    mix(vec3(0.0, 0.0, 1.0), vec3(0.10997368482498855, 0.15247972169325025, 0.7375465934817612), vec3(CONE_OVERLAP_SIMULATION))
);

in vec2 uv;

flat in float exposure;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex11;

uniform sampler2D depthtex0;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int hideGUI;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform float nightVision, screenBrightness;
uniform float far, near, centerDepthSmooth;

uniform vec2 pixelSize;
uniform vec2 viewSize;

/* ------ tonemapping operators ------ */

const mat3 XYZ_sRGB = mat3(
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142
);
const mat3 sRGB_XYZ = mat3(
	0.4124564, 0.3575761, 0.1804375,
	0.2126729, 0.7151522, 0.0721750,
	0.0193339, 0.1191920, 0.9503041
);

const mat3 XYZ_P3D65 = mat3(
    2.4933963, -0.9313459, -0.4026945,
    -0.8294868,  1.7626597,  0.0236246,
    0.0358507, -0.0761827,  0.9570140
);
const mat3 XYZ_REC2020 = mat3(
	 1.7166511880, -0.3556707838, -0.2533662814,
	-0.6666843518,  1.6164812366,  0.0157685458,
	 0.0176398574, -0.0427706133,  0.9421031212
);
// https://en.wikipedia.org/wiki/Adobe_RGB_color_space
const mat3 XYZ_AdobeRGB = mat3(
      2.04158790381075,  -0.56500697427886,  -0.34473135077833,
     -0.96924363628088,   1.87596750150772, 0.0415550574071756,
    0.0134442806320311, -0.118362392231018,   1.01517499439121
);

// Bradford chromatic adaptation from standard D65 to DCI Cinema White
const mat3 D65_DCI = mat3(
    1.02449672775258,     0.0151635410224164, 0.0196885223342068,
    0.0256121933371582,   0.972586305624413,  0.00471635229242733,
    0.00638423065008769, -0.0122680827367302, 1.14794244517368
);

const mat3 sRGB_to_P3DCI = ((sRGB_XYZ) * XYZ_P3D65) * D65_DCI;
const mat3 sRGB_to_P3D65 = sRGB_XYZ * XYZ_P3D65;
const mat3 sRGB_to_REC2020 = sRGB_XYZ * XYZ_REC2020;
const mat3 sRGB_to_AdobeRGB = sRGB_XYZ * XYZ_AdobeRGB;

#if (defined COLOR_SPACE_SRGB || defined COLOR_SPACE_DCI_P3 || defined COLOR_SPACE_DISPLAY_P3 || defined COLOR_SPACE_REC2020 || defined COLOR_SPACE_ADOBE_RGB)

uniform int currentColorSpace;

// https://en.wikipedia.org/wiki/Rec._709#Transfer_characteristics
vec3 EOTF_Curve(vec3 LinearCV, const float LinearFactor, const float Exponent, const float Alpha, const float Beta) {
    return mix(LinearCV * LinearFactor, clamp(Alpha * pow(LinearCV, vec3(Exponent)) - (Alpha - 1.0), 0.0, 1.0), step(Beta, LinearCV));
}

// https://en.wikipedia.org/wiki/SRGB#Transfer_function_(%22gamma%22)
vec3 EOTF_IEC61966(vec3 LinearCV) {
    return EOTF_Curve(LinearCV, 12.92, 1.0 / 2.4, 1.055, 0.0031308);;
    //return mix(LinearCV * 12.92, clamp(pow(LinearCV, vec3(1.0/2.4)) * 1.055 - 0.055, 0.0, 1.0), step(0.0031308, LinearCV));
}
// https://en.wikipedia.org/wiki/Rec._709#Transfer_characteristics
vec3 EOTF_BT709(vec3 LinearCV) {
    return EOTF_Curve(LinearCV, 4.5, 0.45, 1.099, 0.018);
    //return mix(LinearCV * 4.5, clamp(pow(LinearCV, vec3(0.45)) * 1.099 - 0.099, 0.0, 1.0), step(0.018, LinearCV));
}
// https://en.wikipedia.org/wiki/DCI-P3
vec3 EOTF_P3DCI(vec3 LinearCV) {
    return pow(LinearCV, vec3(1.0 / 2.6));
}
// https://en.wikipedia.org/wiki/Adobe_RGB_color_space
vec3 EOTF_Adobe(vec3 LinearCV) {
    return pow(LinearCV, vec3(1.0 / 2.2));
}

vec3 OutputGamutTransform(vec3 LinearCV) {
    switch(currentColorSpace) {
        case COLOR_SPACE_SRGB:
            return EOTF_IEC61966(LinearCV);

        case COLOR_SPACE_DCI_P3:
            LinearCV = LinearCV * sRGB_to_P3DCI;
            return EOTF_P3DCI(LinearCV);

        case COLOR_SPACE_DISPLAY_P3:
            LinearCV = LinearCV * sRGB_to_P3D65;
            return EOTF_IEC61966(LinearCV);

        case COLOR_SPACE_REC2020:
            LinearCV = LinearCV * sRGB_to_REC2020;
            return EOTF_BT709(LinearCV);

        case COLOR_SPACE_ADOBE_RGB:
            LinearCV = LinearCV * sRGB_to_AdobeRGB;
            return EOTF_Adobe(LinearCV);
    }
    // Fall back to sRGB if unknown
    return EOTF_IEC61966(LinearCV);
}

#else

#define VIEWPORT_GAMUT 0    //[0 1 2] 0: sRGB, 1: P3D65, 2: Display P3

vec3 OutputGamutTransform(vec3 Linear) {
#if VIEWPORT_GAMUT == 1
    vec3 P3 = Linear * sRGB_P3D65;
    //return LinearToSRGB(P3);
    return pow(P3, vec3(1.0 / 2.6));
#elif VIEWPORT_GAMUT == 2
    vec3 P3 = Linear * sRGB_P3D65;
    return LinearToSRGB(P3);
    //return pow(P3, vec3(1.0 / 2.2));
#else
    return LinearToSRGB(Linear);
#endif
}

#endif

vec3 tonemapReinhard(vec3 hdr) {
    float luma      = getLuma(hdr);

    #if colorPreset == 0
        float coeff     = 0.83 - nightVision*0.6;
    #elif colorPreset == 1
        float coeff     = 0.5 - nightVision*0.3;
        hdr    *= 1.2;
    #elif colorPreset == 2
        float coeff     = 0.5 - nightVision*0.3;
        hdr    *= 1.04;
    #elif colorPreset >= 3
        float coeff     = 0.75 - nightVision*0.4;
        hdr    *= 1.1;
    #endif

    const float white   = 8.0;

    vec4 hdrWhite   = vec4(hdr, white);

    vec4 col        = hdrWhite / (hdrWhite + coeff);
        col         = mix(hdrWhite / (vec4(vec3(luma), white) + coeff), col, col);

    return OutputGamutTransform(col.rgb / col.a);
}

/* ------ color grading utilities ------ */

vec3 rgbLuma(vec3 x) {
    return x * vec3(colorlumR, colorlumG, colorlumB);
}

vec3 applyGammaCurve(vec3 x) {
    #if colorPreset == 1
    const float gint    = gammaCurve + 0.13;
    #elif colorPreset == 2
    const float gint    = gammaCurve + 0.1;
    #else
    const float gint    = gammaCurve;
    #endif

    return pow(x, vec3(gint));
}

vec3 vibranceSaturation(vec3 color) {
    #if colorPreset == 0
    const float vint    = vibranceInt;
    const float sint    = saturationInt;
    #elif colorPreset == 1
    const float vint    = vibranceInt - 0.03;
    const float sint    = saturationInt + 0.1;
    #elif colorPreset == 2
    const float vint    = vibranceInt + 0.01;
    const float sint    = saturationInt + 0.02;
    #elif colorPreset == 3
    const float vint    = vibranceInt - 0.1;
    const float sint    = saturationInt + 0.1;
    #elif colorPreset == 4
    const float vint    = vibranceInt;
    const float sint    = saturationInt + 0.05;
    #elif colorPreset == 5
    const float vint    = vibranceInt;
    const float sint    = saturationInt + 0.2;
    #endif

    float lum   = dot(color, lumacoeffRec709);
    float mn    = min(min(color.r, color.g), color.b);
    float mx    = max(max(color.r, color.g), color.b);
    float sat   = (1.0 - saturate(mx-mn)) * saturate(1.0-mx) * lum * 5.0;
    vec3 light  = vec3((mn + mx) / 2.0);

    color   = mix(color, mix(light, color, vint), saturate(sat));

    color   = mix(color, light, saturate(1.0-light) * (1.0-vint) / 2.0 * abs(vint));

    color   = mix(vec3(lum), color, sint);

    return color;
}

vec3 brightnessContrast(vec3 color) {
    #if colorPreset == 0
    const float bint    = brightnessInt;
    const float cint    = constrastInt;
    #elif colorPreset == 1
    const float bint    = brightnessInt + 0.02;
    const float cint    = constrastInt + 0.05;
    #elif colorPreset == 2
    const float bint    = brightnessInt + 0.01;
    const float cint    = constrastInt + 0.02;
    #elif colorPreset == 3
    const float bint    = brightnessInt;
    const float cint    = constrastInt;
    #elif colorPreset == 4
    const float bint    = brightnessInt;
    const float cint    = constrastInt + 0.06;
    #elif colorPreset == 5
    const float bint    = brightnessInt;
    const float cint    = constrastInt;
    #endif

    return (color - 0.5) * cint + 0.5 + bint;
}

vec3 vignette(vec3 color) {
    float fade      = length(uv*2.0-1.0);
        fade        = linStep(abs(fade) * 0.5, vignetteStart, vignetteEnd);
        fade        = 1.0 - pow(fade, vignetteExponent) * vignetteIntensity;

    return color * fade;
}

const float gauss9w[9] = float[9] (
     0.0779, 0.12325, 0.0779,
    0.12325, 0.1954,  0.12225,
     0.0779, 0.12325, 0.0779
);

const vec2 gauss9o[9] = vec2[9] (
    vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0),
    vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0),
    vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0)
);

float gauss9Rain(sampler2D tex) {
    float col        = 0.0;

    for (int i = 0; i<9; i++) {
        vec2 bcoord = uv + gauss9o[i]*pixelSize;
        col += texture(tex, bcoord).x*gauss9w[i];
    }
    return col;
}


vec3 bloomExpand(vec3 x) {
    float blurLuma = getLuma(x);
        x *= 1.0 + sqr(max0(blurLuma - sqrt2));

    return x;
}

#include "/lib/util/bicubic.glsl"

vec3 getBloom(vec2 coord) {
    vec3 blur1 = (textureBicubic(colortex5, coord.xy / pow(2.0,2.0) + vec2(0.0,0.0)).rgb);
    vec3 blur2 = (textureBicubic(colortex5, coord.xy / pow(2.0,3.0) + vec2(0.3,0.0)).rgb)*0.95;
    vec3 blur3 = (textureBicubic(colortex5, coord.xy / pow(2.0,4.0) + vec2(0.0,0.3)).rgb)*0.9;
    vec3 blur4 = (textureBicubic(colortex5, coord.xy / pow(2.0,5.0) + vec2(0.1,0.3)).rgb)*0.85;
    vec3 blur5 = (textureBicubic(colortex5, coord.xy / pow(2.0,6.0) + vec2(0.2,0.3)).rgb)*0.8;
    vec3 blur6 = (textureBicubic(colortex5, coord.xy / pow(2.0,7.0) + vec2(0.3,0.3)).rgb)*0.75;
    vec3 blur7 = (textureBicubic(colortex5, coord.xy / pow(2.0,8.0) + vec2(0.4,0.3)).rgb)*0.7;
    
    vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7) / 7.0;
    //float blurLuma = getLuma(blur);
    //    blur *= 1.0 + sqr(max0(blurLuma - sqrt2)) * pi;

    return blur;
}

#ifdef doColorgrading
    /* - */
#endif

#ifdef showFocusPlane
float depthLinear(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

void getFocusPlane(inout vec3 color) {
    #if camFocus == 0 //   Auto
        float focus = centerDepthSmooth;
    #elif camFocus == 1 // Manual
        float focus = camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 2 // Manual+
        float focus = screenBrightness * camManFocDis;
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #elif camFocus == 3 // Auto+
        float offset = screenBrightness * 2.0 - 1.0;
        float autoFocus = depthLinear(centerDepthSmooth) * far * 0.5;
        float focus = offset > 0.0 ? autoFocus + (offset * camManFocDis) : autoFocus * saturate(offset * 0.9 + 1.1);
              focus = (far * ( focus - near)) / ( focus * (far - near));
    #endif

    if (stex(depthtex0).x > focus) color    = mix(color, vec3(0.7, 0.2, 1.0) * 0.8, 0.5);
}
#endif

void main() {
    vec3 sceneHDR   = texture(colortex0, uv).rgb;

    #ifdef bloomEnabled
        float bloomInt = 0.03;

        #if DIM == -1
            bloomInt  = 0.2;
        #elif DIM == 1
            bloomInt  = 0.15;
        #endif

        #if colorPreset == 2
            bloomInt  *= 1.2;
        #elif colorPreset >= 3
            bloomInt  *= 1.5;
        #endif

            bloomInt   *= bloomIntensity;

        if (isEyeInWater == 1) bloomInt = mix(bloomInt, 1.0, 0.4);

        vec3 bloom  = getBloom(uv);

        sceneHDR    = mix(sceneHDR, bloom, saturate(bloomInt));

        
        if (rainStrength > 0.0) {
            float rint      = gauss9Rain(colortex11);
            bool rain       = rint > 0.0;

            if (rain) sceneHDR = mix(sceneHDR, bloom * 1.0, rint * 0.5);
        }
        
    #else
        
        if (rainStrength > 0.0) {
            float rint      = gauss9Rain(colortex11);
            bool rain       = rint > 0.0;

            if (rain) sceneHDR = mix(sceneHDR, sceneHDR * 1.4, rint * 0.5);
        }
        
    #endif

    //sceneHDR    = mix(sceneHDR, texelFetch(colortex5, ivec2(uv * viewSize * 0.25 * 0.25 * 0.25), 0).rrr, 0.5);

    #ifdef manualExposureEnabled
        sceneHDR   *= rcp(manualExposureValue);
    #else
        sceneHDR   *= exposure * exposureBias;
    #endif

    #if DIM == -1
        sceneHDR  *= 0.75;
    #elif DIM == 1
        sceneHDR  *= 1.0;
    #endif

    #ifdef showFocusPlane
    if (hideGUI == 0) getFocusPlane(sceneHDR);
    #endif

    #if (defined doColorgrading || colorPreset != 0)
        sceneHDR    = vibranceSaturation(sceneHDR);
        sceneHDR    = rgbLuma(sceneHDR);
    #endif

    #ifdef vignetteEnabled
        sceneHDR    = vignette(sceneHDR);
    #endif

    vec3 sceneLDR   = tonemapReinhard(sceneHDR);
    
    #if DEBUG_VIEW==5
        sceneLDR    = sqrt(sceneHDR);
    #endif

    #if (defined doColorgrading || colorPreset != 0)
        sceneLDR    = brightnessContrast(sceneLDR);
        sceneLDR    = applyGammaCurve(saturate(sceneLDR));
    #endif

    sceneImage      = saturate(sceneLDR);

    temporal        = texture(colortex4, uv);
    temporal.a      = exposure;

    temporal        = clamp16F(temporal);

    //sceneImage  = stex(colortex3).rgb;
}