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

in vec2 uv;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D noisetex;

uniform float aspectRatio;
uniform float frameTime;
uniform float rainStrength;

uniform vec2 viewSize, pixelSize;

uniform vec3 cameraPosition, previousCameraPosition;
uniform vec3 sunPosition, sunDir;

uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;

#ifdef legacyFlareToggle
    #ifdef DIM
        #undef legacyFlareToggle
    #endif
#endif

#ifdef legacyFlareToggle
    flat in mat4x3 lightColor;
#endif


/* ------ Motionblur ------ */
float ditherBluenoiseStatic() {
    ivec2 coord = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, coord, 0).a;

    return noise;
}

vec2 ClipUV_AABB(vec2 Value, vec2 MinBounds, vec2 MaxBounds, out bool HasClipped) {
    vec2 pClip = 0.5 * (MaxBounds + MinBounds);
    vec2 eClip = 0.5 * (MaxBounds - MinBounds);
    vec2 vClip = Value - pClip;
    vec2 vUnit = vClip / eClip;
    vec2 aUnit = abs(vUnit);
    float maUnit = maxOf(aUnit);
    HasClipped = maUnit > 1.0;
    return HasClipped ? pClip + vClip / maUnit : Value;
}

vec3 RenderMotionblur(float Depth, vec2 ViewUV, bool Hand, vec2 ObjectVelocity) {
    const uint TargetSamples = motionblurSamples;

    float Dither    = ditherBluenoiseStatic();

    vec4 CurrentFragmentPosition = vec4(ViewUV, Depth, 1.0) * 2.0 - 1.0;
    vec4 CurrentPosition = gbufferProjectionInverse * CurrentFragmentPosition;
        CurrentPosition = gbufferModelViewInverse * CurrentPosition;
        CurrentPosition /= CurrentPosition.w;
    if (!Hand) CurrentPosition.xyz += cameraPosition;

    vec4 PreviousPosition = CurrentPosition;
    if (!Hand) PreviousPosition.xyz -= previousCameraPosition;
        PreviousPosition = gbufferPreviousModelView * PreviousPosition;
        PreviousPosition = gbufferPreviousProjection * PreviousPosition;
        PreviousPosition /= PreviousPosition.w;

    float BlurScale = 0.15 * motionblurScale * min(rcp(frameTime * 30.0), 2.0);

    vec2 Velocity   = (CurrentFragmentPosition - PreviousPosition).xy;
    if (Hand) Velocity *= 0.15;

    float VelocityLength = length(Velocity);
    vec2 VelocityDirection = VelocityLength > 1e-8 ? normalize(Velocity) : vec2(0.0);
    if (VelocityLength > euler) Velocity = VelocityDirection * euler;

        Velocity   *= BlurScale / float(TargetSamples);

    vec2 BlurUV = ViewUV + Velocity * Dither;
        BlurUV -= Velocity * TargetSamples * 0.5;

    vec3 BlurColor  = vec3(0.0);
    uint Weight = 0;

    for (uint i = 0; i < TargetSamples; ++i, BlurUV += Velocity) {
        bool HasClipped = false;
        vec2 ClippedUV = ClipUV_AABB(BlurUV, pixelSize, 1.0 - pixelSize, HasClipped);
        float AbyssDistance = HasClipped ? distance(BlurUV, ClippedUV) : 0.0;
        bool AbyssTermination = Dither > (1.01 / (1.0 + AbyssDistance));

        if (!AbyssTermination) {
            BlurColor  += textureLod(colortex0, ClippedUV, 0).rgb;
            ++Weight;
        } else {
            BlurColor  += textureLod(colortex0, ViewUV, 0).rgb;
            ++Weight;
            break;
        }
    }
    BlurColor  /= float(Weight);

    return BlurColor;
}

/* ------ Legacy Lens Flare (Based on BSL with permission) ------ */

#ifdef legacyFlareToggle

float fovmult = gbufferProjection[1][1] / 1.37373871;

float genLens(vec2 lightPos, float size, float dist,float rough){
	return pow(clamp(max(1.0-length((uv.xy+(lightPos.xy*dist-0.5))*vec2(aspectRatio,1.0)/(size*fovmult)),0.0),0.0,1.0/rough)*rough,4.0);
}

float genMultLens(vec2 lightPos, float size, float dista, float distb){
	return genLens(lightPos,size,dista,2)*genLens(lightPos,size,distb,2);
}

float genPointLens(vec2 lightPos, float size, float dist, float sstr){
	return genLens(lightPos,size,dist,1.5)+genLens(lightPos,size*4.0,dist,1)*sstr;
}

float distratio(vec2 pos, vec2 pos2, float ratio) {
	float xvect = pos.x*ratio-pos2.x*ratio;
	float yvect = pos.y-pos2.y;
	return sqrt(xvect*xvect + yvect*yvect);
}

float circleDist (vec2 lightPos, float dist, float size) {
	vec2 pos = lightPos.xy*dist+0.5;
	return pow(min(distratio(pos.xy, uv.xy, aspectRatio),size)/size,10.);
}

float genRingLens(vec2 lightPos, float size, float dista, float distb){
    size *= 1.2;
	float lensFlare1 = max(pow(max(1.0 - circleDist(lightPos,-dista, size*fovmult),0.1),5.0)-0.1,0.0);
	float lensFlare2 = max(pow(max(1.0 - circleDist(lightPos,-distb, size*fovmult),0.1),5.0)-0.1,0.0);
	
	float lensFlare = pow(clamp(lensFlare2 - lensFlare1, 0.0, 1.0),1.4);
	return lensFlare;
}

float genAnaLens(vec2 lightPos){
	return pow(max(1.0-length(pow(abs(uv.xy-lightPos.xy-0.5),vec2(0.5,0.8))*vec2(aspectRatio*0.175,2.0))*4.0/fovmult,0.0),2.2);
}

vec3 getColor(vec3 color, float truepos){
	return mix(color,vec3(length(color/3)*0.25),truepos*0.49+0.49);
}

float getLensVisibilityA(vec2 lightPos){
	float str = length(lightPos*vec2(aspectRatio,1.0));
	return (pow(clamp(str*8.0,0.0,1.0),2.0)-clamp(str*3.0-1.5,0.0,1.0));
}

float getLensVisibilityB(vec2 lightPos){
	float str = length(lightPos*vec2(aspectRatio,1.0));
	return (1.0-clamp(str*3.0-1.5,0.0,1.0));
}

vec3 genRainbowHalo(vec2 lightPos) {
    float size  = 0.4+length(lightPos)*0.1;
    float dist  = pow4(max(1.0 - circleDist(lightPos,0.7, size*fovmult),0.0));
	float mask  = max(pow8(max(1.0 - circleDist(lightPos,0.2, size*fovmult*1.1),0.0)),0.0);

    float r     = sstep(dist, 0.0, 0.33)*(1.0-sstep(dist, 0.33, 0.66));
    float g     = sstep(dist, 0.0, 0.5)*(1.0-sstep(dist, 0.5, 1.0));
    float b     = sstep(dist, 0.5, 0.66)*(1.0-sstep(dist, 0.66, 1.0));

    return colorSaturation(vec3((b), sqr(g), sqr(r)), 0.75)*vec3(1.0, 0.8, 0.3)*0.02*mask;
}

vec3 genRainbowHalo2(vec2 lightPos) {
    float size  = 1.0+length(lightPos)*0.8;
    float dist  = pow4(max(1.0 - circleDist(lightPos,-1.8, size*fovmult),0.0));
	float mask  = max(pow8(max(1.0 - circleDist(lightPos,-2.6, size*fovmult*1.1),0.0)),0.0);

    float r     = sstep(dist, 0.0, 0.33)*(1.0-sstep(dist, 0.33, 0.66));
    float g     = sqr(sstep(dist, 0.0, 0.5)*(1.0-sstep(dist, 0.5, 1.0)));
    float b     = sstep(dist, 0.5, 0.66)*(1.0-sstep(dist, 0.66, 1.0));

    return colorSaturation(vec3(r, g, b), 0.6)*vec3(1.0, 0.8, 0.2)*0.04*mask;
}

vec3 genLensFlare(vec2 lightPos,float truepos,float visiblesun){
	vec3 final = vec3(0.0);
	float visibilitya = getLensVisibilityA(lightPos);
	float visibilityb = getLensVisibilityB(lightPos);
	if (visibilityb > 0.001){
		vec3 lensFlareA = genLens(lightPos,0.3,-0.45,1)*getColor(vec3(2.2, 1.2, 0.1),truepos)*0.02;
			 lensFlareA+= genLens(lightPos,0.3,0.10,1)*getColor(vec3(2.2, 0.4, 0.1),truepos)*0.03;
			 lensFlareA+= genLens(lightPos,0.3,0.30,1)*getColor(vec3(2.2, 0.1, 0.05),truepos)*0.04;
			 lensFlareA+= genLens(lightPos,0.3,0.50,1)*getColor(vec3(2.2, 0.4, 2.5),truepos)*0.05;
			 lensFlareA+= genLens(lightPos,0.3,0.70,1)*getColor(vec3(1.8, 0.4, 2.5),truepos)*0.06;
			 lensFlareA+= genLens(lightPos,0.3,0.90,1)*getColor(vec3(0.1, 0.2, 2.5),truepos)*0.07;
			 
		vec3 lensFlareB = genMultLens(lightPos,0.08,-0.28,-0.39)*getColor(vec3(2.5, 1.2, 0.3),truepos)*0.015;
			 lensFlareB+= genMultLens(lightPos,0.08,-0.20,-0.31)*getColor(vec3(2.5, 0.5, 0.2),truepos)*0.010;
			 lensFlareB+= genMultLens(lightPos,0.12,0.06,0.19)*getColor(vec3(2.5, 0.1, 0.05),truepos)*0.020;
			 lensFlareB+= genMultLens(lightPos,0.12,0.15,0.28)*getColor(vec3(1.8, 0.1, 1.2),truepos)*0.015;
			 lensFlareB+= genMultLens(lightPos,0.12,0.24,0.37)*getColor(vec3(1.0, 0.1, 2.5),truepos)*0.010;
			 
		vec3 lensFlareC = genPointLens(lightPos,0.03,-0.55,0.5)*getColor(vec3(2.5, 0.9, 0.2),truepos)*0.10;
			 lensFlareC+= genPointLens(lightPos,0.02,-0.4,0.5)*getColor(vec3(2.5, 1.0, 0.0),truepos)*0.15;
			 lensFlareC+= genPointLens(lightPos,0.04,0.425,0.5)*getColor(vec3(2.5, 0.6, 0.6),truepos)*0.20;
			 lensFlareC+= genPointLens(lightPos,0.02,0.6,0.5)*getColor(vec3(0.2, 0.6, 2.5),truepos)*0.15;
			 lensFlareC+= genPointLens(lightPos,0.03,0.675,0.25)*getColor(vec3(0.7, 1.1, 3.0),truepos)*0.25;
			 
		vec3 lensFlareD = genRingLens(lightPos,0.22,0.44,0.46)*getColor(vec3(0.1, 0.35, 2.5),truepos);
			 lensFlareD+= genRingLens(lightPos,0.15,0.98,0.99)*getColor(vec3(0.15, 0.4, 2.55),truepos)*2.5;
			 
		//vec3 lensFlareE = genAnaLens(lightPos)*getColor(vec3(0.3,0.7,1.0),truepos);

		final = (((lensFlareA+lensFlareB)*visibilitya+(lensFlareC+lensFlareD))*visibilityb)*pow(visiblesun,2.0);

		final += (genRainbowHalo(lightPos)+genRainbowHalo2(lightPos))*getLensVisibilityB(lightPos);
	}
	
	return final*(1.0-rainStrength);
}

vec3 getLensflare(){
	vec4 tpos = vec4(sunPosition,1.0)*gbufferProjection;
        tpos.xyz /= tpos.w;
        tpos.xy = tpos.xy/tpos.z;

	vec2 lightPos = tpos.xy * 0.5;
	float truepos = sunPosition.z/abs(sunPosition.z);
	vec3 visible = texture(colortex2, lightPos.xy + 0.5).rgb;
        visible *= sstep(sunDir.y, 0.0, 0.1);

        visible *= 1.0-linStep(length(tpos.xy), 0.85, 1.25);

    if(minOf(visible)>0.01 && truepos < 1.0) {
        return genLensFlare(lightPos, truepos, 1.0) * lightColor[0] * visible * 0.75 * legacyFlareIntensity;
    } else {
        return vec3(0.0);
    }
}

#endif

void main() {
    sceneColor  = textureLod(colortex0, uv, 0).rgb;

    #ifdef motionblurToggle
        float sceneDepth    = texture(depthtex1, uv).x;

        bool hand   = sceneDepth < texture(depthtex2, uv).x;

        sceneColor.rgb = RenderMotionblur(sceneDepth, uv, hand, vec2(0.0));
    #endif

    #ifdef legacyFlareToggle
        sceneColor.rgb += getLensflare();
    #endif

    sceneColor  = clamp16F(sceneColor);
}