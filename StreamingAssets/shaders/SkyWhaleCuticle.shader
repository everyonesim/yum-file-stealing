Shader "Futile/SkyWhaleCuticle"
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
#include "_RippleClip.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NoiseTex;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    float2 scrPos : TEXCOORD1;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.color = v.color;
    o.scrPos = ComputeScreenPos(o.pos);
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float noise = lerp(tex2D(_NoiseTex, i.uv * float2(1, 0.5) + float2(6, 1) * i.color.a), 0.5, 0.2 + i.uv.y * 0.8);
    float dist = min(i.uv.y, (1 - abs(i.uv.x * 2 - 1)) * 1.5 + i.uv.y / 5);
    clip(noise - dist * 3);

    return half4(i.color.rgb, 1);
}
ENDCG
            }
        }
    }
}
