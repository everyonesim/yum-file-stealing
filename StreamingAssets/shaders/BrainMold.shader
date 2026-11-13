Shader "Futile/BrainMold"
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
            GrabPass{"_PreBrainMold"}
            Pass
            {
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _LevelTex;
sampler2D _PalTex;

uniform float _fogAmount;
uniform float _RAIN;
uniform float4 _spriteRect;
uniform float2 _screenSize;
uniform float4 _camInRoomRect;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float2 worldPos : TEXCOORD2;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.worldPos = v.color.xy;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    // Sample level texture
    float2 textCoord = floor(i.scrPos * _screenSize) / _screenSize;
    textCoord -= _spriteRect.xy;
    textCoord /= _spriteRect.zw - _spriteRect.xy;
    half4 texcol = tex2D(_LevelTex, textCoord);

    half hairFactor = 0.0;
    half noise = pow(tex2D(_MainTex, i.worldPos / 10.0), 0.75);
    half hair = pow(1 - tex2D(_MainTex, i.worldPos / 5.6), 3);
    noise = max(noise, hair * 0.5);

    float fade = pow(max(0, length(i.uv * 2 - 1) * 1.25 - 0.25), 1.5);

    clip(noise - fade);

    half effectFac = pow(round(saturate((noise - fade - max(0, 0.5 - i.uv.y) * 2.25) * 1.5) * 3) / 3, 1.5) * 0.5;

    half4 mainColor = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));
    half4 effectColor = tex2D(_PalTex, float2(31.5 / 32.0, 3.5 / 8.0));

    return lerp(mainColor, effectColor, effectFac);
}
ENDCG
            }
            GrabPass{"_BrainMold"}
        }
    }
}
