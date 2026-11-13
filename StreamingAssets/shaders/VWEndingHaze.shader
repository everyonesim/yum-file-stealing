Shader "Futile/VWEndingHaze"
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
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.texcoord;
    o.color = v.color;
    
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float3 bgColor = _AboveCloudsAtmosphereColor;
    float3 hazeColor = i.color;

    float2 scrollUv = i.uv * 0.99 + float2(_RAIN * 0.1, 0.0);
    half3 cloud = tex2D(_MainTex, scrollUv * float2(-1, 1));
    cloud.r *= 0.25 + 0.75 * pow(tex2D(_CloudsTex, scrollUv * float2(3.0, 1.0) * 3.0).r, 0.7);
    cloud.r = saturate(cloud.r);

    float alpha = pow(cloud.r, 0.5) * 0.5;
    alpha *= min(pow(i.uv.y, 0.7) * 2.5, 1.0);
    alpha *= i.color.a;
    alpha *= smoothstep(0.2, 0.6, tex2D(_NoiseTex, scrollUv * float2(3.0, 0.5) / 6.8).r);
    if (alpha < 0.0)
        discard;
    alpha = smoothstep(0.0, 0.5, alpha);

    float lit = cloud.g;
    return half4(lerp(bgColor, hazeColor, saturate(lit) * 0.75 + 0.25) + pow(lit, 10.0) * 0.2, alpha);
}
ENDCG
            }
        } 
    }
}
