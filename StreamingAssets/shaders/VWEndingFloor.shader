Shader "Futile/VWEndingFloor"
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
#include "_ShaderFix.cginc"
#define TAU 6.28318530718

sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _CloudsTex;
float2 _WorldCamPos;
half4 _AboveCloudsAtmosphereColor;

uniform float _RAIN;

struct appdata {
    float4 vertex : POSITION;
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR;
};

struct v2f {
    float4 pos : SV_POSITION;
    float3 worldPos : TEXCOORD0;
    float4 color : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.pos.z = v.color.a;
    o.pos.w *= v.color.a;
    o.worldPos.xy = v.vertex.xy + _WorldCamPos;
    o.worldPos.z = v.color.a * 800.0;
    o.color = v.color;
    
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float3 bgColor = _AboveCloudsAtmosphereColor;
    float3 hazeColor = float3(0.93, 0.61, 0.38);

    float3 dir = i.worldPos - float3(320.0, 620.0, 800.0);
    float dist = length(dir);
    dir /= dist;

    float theta = fmod(sqrt(dist / 500.0) - _RAIN * 6.0, TAU);
    if (theta < 0.0) theta += TAU;
    float spike = pow(max(cos(theta), 0), 2000.0);
    float spikePush = sin(theta * 2.0) * pow(theta / TAU, 5.0);

    float2 offset = float2(
        tex2D(_NoiseTex, i.worldPos.xz / 5000.0 - _RAIN * 0.02).r * 2.0 - 1.0,
        tex2D(_NoiseTex, i.worldPos.xz / 4800.0 + 0.4 - _RAIN * 0.02).r * 2.0 - 1.0);

    float2 uv = i.worldPos.xz + dir.xz * spikePush * 100.0 + float2(_RAIN * 200.0, 0.0) + offset * 500.0;
    float noise = tex2D(_CloudsTex, uv / 1000.0).r * 0.8;
    noise +=      tex2D(_CloudsTex, uv / 234.0).r * 0.2;
    noise *= 1.8 * (1.0 - length(offset) / 1.42);
    noise = noise * 0.1 + pow(noise, 15.0) * 0.9;
    float fade = 1.0 / max(i.worldPos.z / 3000.0, 1.0);

    noise = min(noise * (1.0 + spike), 1.0);

    return float4(
        pow(lerp(sqrt(bgColor) * 0.9, sqrt(hazeColor), noise), 2),
        fade
    );
}
ENDCG
            }
        } 
    }
}
