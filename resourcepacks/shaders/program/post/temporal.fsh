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
layout(location = 0) out vec3 sceneColor;
layout(location = 1) out vec4 temporal;

#include "/lib/head.glsl"

in vec2 uv;

const bool colortex4Clear   = false;

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D depthtex1;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelViewInverse;

#define taaClamp(x) clamp(x, 0.0, 65535.0)

//Temporal Reprojection based on Chocapic13's approach
vec2 taaReprojection(vec2 coord, float depth) {
    vec4 frag       = gbufferProjectionInverse*vec4(vec3(coord, depth)*2.0-1.0, 1.0);
        frag       /= frag.w;
        frag        = gbufferModelViewInverse*frag;

    vec4 prevPos    = frag + vec4(cameraPosition-previousCameraPosition, 0.0)*float(depth > 0.56);
        prevPos     = gbufferPreviousModelView*prevPos;
        prevPos     = gbufferPreviousProjection*prevPos;
    
    return prevPos.xy/prevPos.w*0.5+0.5;
}

vec3 applyTAA(float depth, vec3 scenecol) {
    vec2 taaCoord       = taaReprojection(uv, depth);
    vec2 viewport       = 1.0/vec2(viewWidth, viewHeight);

    vec3 taaCol         = texture(colortex4, taaCoord).rgb;
        taaCol          = taaClamp(taaCol);

    vec3 coltl      = texture(colortex0,uv+vec2(-1.0,-1.0)*viewport).rgb;
	vec3 coltm      = texture(colortex0,uv+vec2( 0.0,-1.0)*viewport).rgb;
	vec3 coltr      = texture(colortex0,uv+vec2( 1.0,-1.0)*viewport).rgb;
	vec3 colml      = texture(colortex0,uv+vec2(-1.0, 0.0)*viewport).rgb;
	vec3 colmr      = texture(colortex0,uv+vec2( 1.0, 0.0)*viewport).rgb;
	vec3 colbl      = texture(colortex0,uv+vec2(-1.0, 1.0)*viewport).rgb;
	vec3 colbm      = texture(colortex0,uv+vec2( 0.0, 1.0)*viewport).rgb;
	vec3 colbr      = texture(colortex0,uv+vec2( 1.0, 1.0)*viewport).rgb;

	vec3 minCol = min(scenecol,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
	vec3 maxCol = max(scenecol,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));

        taaCol      = clamp(taaCol, minCol, maxCol);

    float taaMix    = float(taaCoord.x>0.0 && taaCoord.x<1.0 && taaCoord.y>0.0 && taaCoord.y<1.0);

    vec2 velocity   = (uv-taaCoord)/viewport;

        taaMix     *= clamp(1.0-sqrt(length(velocity))/1.999, 0.0, 1.0)*0.35+0.6;

    return taaClamp(mix(scenecol, taaCol, taaMix));
}

void main() {
    sceneColor      = texture(colortex0, uv).rgb;
    float depth     = texture(depthtex1, uv).x;

    #ifdef taaEnabled
        sceneColor  = applyTAA(depth, sceneColor);
    #endif

    temporal        = texture(colortex4, uv);
    temporal.rgb    = sceneColor;
}