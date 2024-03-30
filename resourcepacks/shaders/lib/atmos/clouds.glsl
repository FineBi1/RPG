
const float edgeWeightStep = 1.0 - (1.0 / cloudVolumeRounding);

vec3 GetPlane(float Altitude, vec3 Direction) {
    return  Direction * ((Altitude - eyeAltitude) / Direction.y);
}

float cloudTextureCubic(sampler2D tex, vec2 pos) {
    ivec2 texSize = textureSize(tex, 0) * cloudVolumeRounding;
    vec2 texelSize = rcp(vec2(texSize));
    
    float p0q0 = texture(tex, pos).a;
    float p1q0 = texture(tex, pos + vec2(texelSize.x, 0)).a;

    float p0q1 = texture(tex, pos + vec2(0, texelSize.y)).a;
    float p1q1 = texture(tex, pos + vec2(texelSize.x , texelSize.y)).a;

    float a = cubeSmooth(fract(pos.x * texSize.x));

    float pInterp_q0 = mix(p0q0, p1q0, a);
    float pInterp_q1 = mix(p0q1, p1q1, a);

    float b = cubeSmooth(fract(pos.y*texSize.y));

    return mix(pInterp_q0, pInterp_q1, b);
}

float EstimateEnergy(float ratio) {
    return ratio / (1.0 - ratio);
}
float cloudPhase(float cosTheta, float g, vec3 gMult) {
    float x = mieHG(cosTheta, gMult.x * g);
    float y = mieHG(cosTheta, -gMult.y * g);
    float z = mieHG(cosTheta, gMult.z * g) * sqrt2;

    return mix(mix(x, y, 0.2), z, 0.15);    //i assume this is more energy conserving than summing them
}

float cloudPhase(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y);
    float z = mieHG(cosTheta, asymmetry.z);

    return 0.7 * x + 0.2 * y + 0.1 * z;
}
float cloudPhaseSky(float cosTheta, vec3 asymmetry) {
    float x = mieHG(cosTheta, asymmetry.x);
    float y = mieHG(cosTheta, -asymmetry.y);

    return 0.75 * x + 0.25 * y;
}

const float cloudScale  = 0.17 / 1024.0;
const float cloudVolMaxY   = float(cloudVolumeAlt + cloudVolumeDepth);
const float cloudVolMidY   = float(cloudVolumeAlt) + cloudVolumeDepth * 0.5;
const vec2 RSKY_Volume_Limits = vec2(cloudVolumeAlt, cloudVolumeAlt + cloudVolumeDepth);

float cloudVolumeShape(vec3 Position) {
    float Elevation = (Position.y - RSKY_Volume_Limits.x) / cloudVolumeDepth;

    vec4 ErosionFade = vec4(1.0 - linStep(Elevation, 0.0, 0.2),  //EL
                            linStep(Elevation, 0.8, 1.0),        //EH
                            sstep(Elevation, 0.0, 0.02),         //FL
                            1.0 - sstep(Elevation, 0.98, 1.0));  //FH
        ErosionFade.xy = cube(ErosionFade.xy);

    #ifdef freezeAtmosAnim
        Position.x  += float(atmosAnimOffset);
    #else
        #ifdef volumeWorldTimeAnim
            Position.x  += worldAnimTime * 600.0;
        #else
            Position.x  += frameTimeCounter;
        #endif
    #endif

        Position    *= cloudScale;

    float shape = cloudTextureCubic(colortex8, Position.xz);
        shape  -= ErosionFade.x + ErosionFade.y;
        shape  *= ErosionFade.z * ErosionFade.w;
        shape  -= 0.007;

    #ifdef cloudVolumeStoryMode
    float storyFade = linStep(Elevation, 0.15, 1.0);
        shape  *= (sqr(1.0 - storyFade)) * 0.999 + 0.001;
    #endif

        shape = mix(shape, shape * 0.15 + (ErosionFade.z * ErosionFade.w) * 0.08, wetness);

    return max0(shape);
}
/*
float cloudVolumeShape(vec3 pos) {
    float fadeLow   = sstep(pos.y, float(cloudVolumeAlt), float(cloudVolumeAlt) + float(cloudVolumeDepth) * 0.02);
    float fadeHigh  = 1.0 - sstep(pos.y, cloudVolMaxY - float(cloudVolumeDepth) * 0.02, cloudVolMaxY);
    float erodeLow  = cube(1.0 - linStep(pos.y, float(cloudVolumeAlt), float(cloudVolumeAlt) + float(cloudVolumeDepth) * 0.2));
    float erodeHigh = cube(linStep(pos.y, float(cloudVolumeAlt) + float(cloudVolumeDepth) * 0.8, cloudVolMaxY));

    float altitude  = pos.y;

        #ifdef volumeWorldTimeAnim
            pos.x  += worldAnimTime * 600.0;
        #else
            pos.x  += frameTimeCounter;
        #endif

        pos    *= cloudScale;

    float shape = cloudTextureCubic(colortex8, pos.xz);
        shape  -= erodeLow + erodeHigh;
        shape  *= fadeLow * fadeHigh;
        shape  -= 0.007;

    #ifdef cloudVolumeStoryMode
    float storyFade = linStep(altitude, cloudVolumeAlt + 2.0, cloudVolMaxY);
        shape  *= cube(1.0 - storyFade) * 0.99 + 0.01;
    #endif

    return max0(shape);
}*/

float cloudVolumeLightOD(vec3 pos, const uint steps, vec3 dir) {
    float stepSize      = float(cloudVolumeDepth) / float(steps);

    vec3 rStep  = dir * stepSize;

        pos    += rStep / pi;

    float od    = 0.0;

    for (uint i = 0; i < steps; ++i, pos += rStep) {

        if(pos.y > cloudVolMaxY || pos.y < cloudVolumeAlt) continue;

        float density   = cloudVolumeShape(pos);

            od += density * stepSize;
    }

    return od;
}

float approxSkylightDensity(vec3 pos) {
    float distToTop     = max0(cloudVolMaxY - pos.y);

    return distToTop;
}