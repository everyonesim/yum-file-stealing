Shader "Futile/Darken" 
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
		Cull Off 

		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}

		SubShader   
		{
            GrabPass{}
				Pass 
			{
            Blend SrcAlpha OneMinusSrcAlpha 
            // Blend One OneMinusSrcAlpha
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _CloudsTex;
sampler2D _PalTex;
sampler2D _MainTex;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _SKLightningBlindness;
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
    float2 texCoord : TEXCOORD3;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float blind = smoothstep(0,2,_SKLightningBlindness.x);
    float flash = pulse(_SKLightningBlindness.x,0.2,.2)*_SKLightningBlindness.y>0;
    fixed4 grab = tex2D(_GrabTexture,i.scrPos);
    grab = lerp(grab+flash,smoothstep(0.4,1.3,grab),blind);
    grab = fixed4(grab.xyz,1);
    smoothRippleClip(grab,i.scrPos);
    return grab;
}

ENDCG
}

		} 
	}
}

