Shader "Futile/DevUIDepthPreview"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend One OneMinusSrcAlpha 
		ZWrite Off
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
        // Blend SrcAlpha One
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
    float4 pos : SV_POSITION;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR0;
    float2 texCoord : texcoord2;
};

sampler2D _MainTex;
sampler2D _LevelTex;
fixed4 _DevUIDepthPreviewColor;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    fixed depth = get_depth01(tex2D(_LevelTex,i.texCoord).x);
    if (depth < i.clr.x || depth > i.clr.y) discard;
    if (length(i.uv*2-1)>1) discard;
    return fixed4(_DevUIDepthPreviewColor.xyz*(1-fmod(depth,0.0333333333*2)*10),i.clr.w);
}
ENDCG
		}
    }
}
