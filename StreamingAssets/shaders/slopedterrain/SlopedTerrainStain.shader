Shader "Futile/SlopedTerrainStain"
{
    Properties 
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        SubShader   
        {
            Pass
            {
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "TerrainCommon.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

// Textures
sampler2D _UniNoise;

sampler2D _SandNormals;

float _fogAmount;
float2 _screenOffset;

float _terrainStainFactor;
float _terrainStainBrightness;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.texcoord;
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float2 levelUv = ScreenToLevelTex(i.scrPos);
    half4 texcol = tex2D(_LevelTex, levelUv);
    float3 lightDir = normalize(float3(-_lightDirAndPixelSize.x, _lightDirAndPixelSize.y, 2.0));
    float4 rippleParams = GetRippleParams(i.scrPos);

    bool lit = texcol * 255.0 > 90.0;
    half terrainDpth = (((uint)round(texcol.x * 255.0) - 1u) % 30u) / 30.0;
    if(all(texcol.rgb == 1.0))
    {
        discard;
    }

    if(terrainDpth >= 6.0/30.0)
    {
        float4 grabTexCol = tex2Dproj(_GrabTexture, i.scrPos);
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
        {
            discard;
        }
    }
    
    half2 screenPos = half2(lerp(_spriteRect.x+_screenOffset.x, _spriteRect.z+_screenOffset.x, levelUv.x), lerp(_spriteRect.y+_screenOffset.y, _spriteRect.w+_screenOffset.y, levelUv.y));
    #if UNITY_UV_STARTS_AT_TOP
        screenPos.y = 1 - screenPos.y;
    #endif

    if(i.clr.w > terrainDpth)
        discard;

    // Sunlight
    float sunlight = lit * _terrainStainBrightness;
    sunlight = sqrt(max((sunlight - 1.0) / (1.0 - TERRAIN_LIGHT_FACTOR) + 1.0, 0.0));
    sunlight *= ObjectShadows(levelUv, screenPos, terrainDpth * 30.0 - 1.0);

    float ambientLight = _terrainStainBrightness;
    
    float lightness = sunlight * 0.75 + ambientLight * 0.25;

    half4 sunColor = PaletteSurfaceColor(lightness, i.clr.w, 1, rippleParams);
    half4 ambientColor = PaletteSurfaceColor(lightness, i.clr.w, 0, rippleParams);
    
    half4 skyColor = LevelPalette(0.5 / 32.0, 7.5 / 8.0, rippleParams);
    half4 fogColor = LevelPalette(1.5 / 32.0, 7.5 / 8.0, rippleParams);
    half4 sandColor = lerp(ambientColor, sunColor, sunlight);

    sandColor = lerp(sandColor, fogColor, saturate(terrainDpth) * _fogAmount);
    sandColor = lerp(sandColor, skyColor, saturate(terrainDpth * 3 - 2) * TERRAIN_SKY_FADE);

    float gradient = clamp(lerp(i.uv.x, i.uv.y, terrainDpth), 0, 1);
    sandColor.a *= (1 - gradient) * _terrainStainFactor;

    ApplyShiftWaveColor(sandColor,rippleParams.w,rippleParams.z);
    return sandColor;
}
ENDCG
            }
        } 
    }
}
