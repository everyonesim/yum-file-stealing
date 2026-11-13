Shader "Futile/PrinceStem"
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
        Lighting Off
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
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#define PI 3.14159265359

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _PalTex;
uniform float _fogAmount;
uniform float _RAIN;
uniform float4 _spriteRect;
uniform float2 _screenSize;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    int isShort = i.uv.y < 0;

    half4 black = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));
    half3 glowColor = half3(0.89, 0.89, 0.79);
    float theta = asin(i.uv.x * 2 - 1);

    float texFac = i.clr.a * (isShort ? 0.3 : 1);
    float veinMask = tex2D(_NoiseTex, float2(theta / 20.0, texFac - _RAIN * 0.15) + i.uv.y).r;
    veinMask = saturate(veinMask * 1.5 + 0.5 - sqrt(i.clr.a) * 1.25);

    float veins = tex2D(_MainTex, 0.5 * float2(theta / 7.0 * (1 - 0.7 * texFac) + 0.25, texFac * 3.0) + i.uv.y).g;
    float effectFac = veinMask * saturate(round(veins * 4) / 4 * 2 - 0.15) * 0.5;

    half3 color;
    float skinFac = i.clr.a * 0.07 * round(saturate(pow(1 - veins, 10) / 0.6) * 3) / 3;
    
    if (!isShort) {
        float glowFac = max(0, i.clr.a * 3 - 2) * 0.08 * min(7 - 7 * i.clr.a, 1);
        float fadeOut = min(5 - 5 * i.clr.a, 1);
        effectFac *= fadeOut;
        skinFac *= fadeOut;
        color = lerp(black.rgb, i.clr.rgb, effectFac) + skinFac + glowColor * glowFac;
    }
    else {
        color = lerp(black.rgb, i.clr.rgb, effectFac) + skinFac;
    }
    return half4(color, 1);
}
ENDCG
            }
        }
    }
}