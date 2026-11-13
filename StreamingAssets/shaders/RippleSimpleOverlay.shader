Shader "Futile/RippleSimpleOverlay"
{
Properties
{
    _MainTex ("Texture", 2D) = "white" {}
}
SubShader
{
    Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
    Blend SrcAlpha OneMinusSrcAlpha 
    ZWrite Off
    Lighting Off
    Cull Off 
BindChannels 
{
    Bind "Vertex", vertex
    Bind "texcoord", texcoord 
    Bind "Color", color 
}
GrabPass{}
Pass
{ 
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float2 scrPos : TEXCOORD1;
};
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
float4 _MainTex_ST;
float2 _MainTex_TexelSize;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos).xy;
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    float4 grab = tex2D(_GrabTexture,i.scrPos);
    ApplyShiftWaveColor(grab,i.scrPos);
    return fixed4(grab.xyz,1);
}
ENDCG
		}
    }
}
