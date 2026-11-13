Shader "Futile/WarpTearBlocker"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags { "Queue" = "Geometry"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite Off
		//Alphatest Greater 0
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
Pass
{
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float2 texCoord : TEXCOORD2;
    float4 pos : SV_POSITION;
    float4 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};
float4 _MainTex_ST;
float4 _spriteRect;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
    o.clr = v.color;
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    return fixed4(i.clr.y*.4,0,0,saturate(1-length(i.uv))*(i.clr.x+i.clr.y*.5));
}
ENDCG
}
}
}
