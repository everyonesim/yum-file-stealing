Shader "Futile/MudPit"
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

        SubShader
        {
            Pass
            {
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_TerrainMask.cginc"

uniform float _RAIN;
uniform float4 _spriteRect;

uniform float _light;
uniform float4 _lightDirAndPixelSize;
uniform float4 _camInRoomRect;
uniform float _WetTerrain;
uniform float _cloudsSpeed;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _LevelTex;
sampler2D _PalTex;

uniform float2 _screenSize;

sampler2D _DynamicLevelElements;
sampler2D _OrigLevelTex;
#include "_RippleClip.cginc"
#include "_Functions.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

// Adapted from _TerrainMask's TerrainAndLevelDepth
half GetDepth(float2 textCoord)
{
    half4 levelCol = tex2D(_LevelTex, textCoord);
    int red = round(levelCol.r * 255);
    if (red > 90)
        red -= 90;
    
    half levelDepth = fmod(red - 1, 30.0);
    if (all(levelCol.rgb == 1))
        levelDepth = 30;
    
    half4 terrain = TerrainAtLevelPos(textCoord, _spriteRect);
    half terrainDepth = round(terrain.r * 30);

    // Offset terrain depth by a bit, since mud is drawn into the terrain mask
    terrainDepth += 1.5;

    return min(levelDepth, terrainDepth);
}

half4 frag (v2f i) : SV_Target
{
    float2 textCoord = floor(i.scrPos * _screenSize) / _screenSize;
    textCoord = (textCoord - _spriteRect) / (_spriteRect.zw - _spriteRect);
    float2 worldPos = _camInRoomRect.xy / _camInRoomRect.zw * _screenSize + i.scrPos * _screenSize;

    rippleClip(i.scrPos);

    half red = max(0, i.uv.y) * 30.0;
    
    half shadow = tex2D(_NoiseTex, float2((textCoord.x*0.5) + (_RAIN*0.1*_cloudsSpeed) - (0.003*(red + 1)),
                                        1-(textCoord.y*0.5) + (_RAIN*0.2*_cloudsSpeed) - (0.003*(red + 1))
                                        )).x;
    shadow = 0.5 + sin(fmod(shadow+(_RAIN*0.1*_cloudsSpeed)-textCoord.y, 1)*3.14*2)*0.5;
    shadow = saturate(((shadow - 0.5)*6)+0.5-(_light*4));

    if (GetDepth(textCoord) <= red)
    {
        return half4(0,0,0,0);
    }

    if (shadow != 1 && red >= 5)
    {
        float4 shadowFix =FixEdgeShadowStretch(i.scrPos,true);
        half2 grabPos = float2(i.scrPos.x + -_lightDirAndPixelSize.x*_lightDirAndPixelSize.z*(red-5) * shadowFix.x,
                               i.scrPos.y +  _lightDirAndPixelSize.y*_lightDirAndPixelSize.w*(red-5) * shadowFix.y);
        grabPos = lerp(grabPos,((grabPos-half2(0.5, 0.3))*(1 + (red-5.0)/460.0))+half2(0.5, 0.3),shadowFix.zw);
        float4 grabTexCol2 = tex2D(_GrabTexture, grabPos);
        if (grabTexCol2.x != 0.0 || grabTexCol2.y != 0.0 || grabTexCol2.z != 0.0)
        {
            shadow = 1;
        }
    }

    if (red >= 5)
    {
        float4 grabTexCol = tex2D(_GrabTexture, float2(i.scrPos.x, i.scrPos.y));
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            return half4(0,0,0,0);
    }
    
    half lightness = 1 - shadow;
    half4 color = tex2D(_MainTex, i.uv) * half4(i.clr.rgb, 1);
    half4 black = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));

    half noise = tex2D(_NoiseTex, float2(worldPos.x / 100.0, max(i.uv.y, 0) + worldPos.x / 300.0)) + min(i.uv.y, 0);
    half fadeNoise = tex2D(_NoiseTex, float2(worldPos.x, worldPos.y + worldPos.x * 0.2) / 50.0);

    lightness = (noise > 0.6 + i.clr.a * 0.1) * 0.5 * saturate(_light * 4) + 0.5;
    lightness *= round(pow(min(1 + i.uv.y, 1), 1 + fadeNoise * 4) * i.uv.x * 5) / 5.0;
    lightness *= tex2D(_PalTex, float2(30.5 / 32.0, 7.5 / 8.0)).r;

    float disturbance = saturate((abs(i.uv.y * 30 - (3 + 7 * fadeNoise)) - i.clr.a * 4) / 5.0 + 1);
    lightness *= pow(disturbance, 2) * 0.5 + 0.5;

    color = lerp(black, color, lightness);

    return color;
}
ENDCG
            }
        } 
    }
}
