Shader "Futile/WallLightFlat" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		ZWrite Off
		Lighting Off
		Cull Off //we can turn backface culling off because we know nothing will be facing backwards

		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}

		SubShader   
		{
Pass 
			{
                Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float4 clr : COLOR;
    float2 scrPos : TEXCOORD1;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos);
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float glw = (1-pulse(abs(i.uv.x*2-1),1,1.0+i.uv.y*.1))*saturate(pulse(i.uv.y,.3,.3,.7))*(1-i.uv.y)*.65;

    half4 result = half4(i.clr.xyz,glw*i.clr.w);
    result = saturate(result);
    smoothRippleClip(result,i.scrPos);
    return result;
}

ENDCG
}
				Pass 
			{
        Blend One One 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float4 clr : COLOR;
    float2 scrPos : TEXCOORD1;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos);
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float glw = (1-pulse(abs(i.uv.x*2-1),1,1.0+i.uv.y*.1))*saturate(pulse(i.uv.y,.3,.3,.7))*(1-i.uv.y)*.65;
    half4 result = half4(i.clr.xyz*glw*i.clr.w,glw);
    result = saturate(result);
    smoothRippleClipAdditive(result,i.scrPos);
    return result;
}

ENDCG
}	

		} 
	}
}

