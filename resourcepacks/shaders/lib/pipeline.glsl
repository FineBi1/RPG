/*
    const int colortex0Format   = RGBA16F;
    const int colortex1Format   = RGBA16;
    const int colortex2Format   = RGBA16;
    const int colortex3Format   = RGB16F;
    const int colortex4Format   = RGBA16F;
    const int colortex5Format   = RGBA16F;
    const int colortex6Format   = R16F;
    const int colortex7Format   = RGB10_A2;
    const int colortex9Format   = RGBA16F;
    const int colortex10Format  = RGBA16F;
    const int colortex11Format  = R8;

    const int shadowcolor0Format   = RGB10_A2;
    const int shadowcolor0Format   = RGB5_A1;

    const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
    const vec4 colortex7ClearColor = vec4(1.0, 1.0, 1.0, 1.0);

    const bool colortex4Clear   = false;
    const bool colortex9Clear   = false;
    const bool colortex10Clear  = false;

    C0: Scene Color
        11F11F10F Scene Color   (gbuffer -> composite)

    C1: GData
        2x16 Scene Normals      (gbuffer -> composite)
        2x8 Sky Occlusion, Wetness (gbuffer -> composite)
        2x8 Specular Data       (gbuffer -> composite)

    C2: Light + Albedo
        4x16 Direct Light + Albedo (gbuffer -> composite)

    C3: Skybox
        3x16 Skybox Captures    (prepare -> composite)

    C4: Temporal AA
        3x16 Temporal AA        (Full)
        1x16 Temporal Exposure  (Full)

    C5: Translucency Storage
        4x16 Translucency Color (water -> composite),
        3x16 Bloom Tiles        (composite -> composite)

    C6: Exposure

    C7: Scene Tint

    C9: Reflection Capture
    C10: Reflection Capture

    C11: Weather
*/