// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/SkinkStripes" //Unlit Transparent Vertex Colored Additive 
{
	Properties
	{
		_MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
	}

		Category
	{
		Tags {"Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend SrcAlpha OneMinusSrcAlpha
		Fog { Color(0,0,0,0) }
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
			//SetTexture [_MainTex] 
			//{
			//	Combine texture * primary
			//}



CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
	//sampler2D _LevelTex;
	sampler2D _NoiseTex;
	sampler2D _PalTex;

	//uniform float _fogAmount;
	//uniform float _waterPosition;

	//#if defined(SHADER_API_PSSL)
	//sampler2D _GrabTexture;
	//#else
	//sampler2D _GrabTexture : register(s0);
	//#endif

	//uniform float _RAIN;

	//uniform float4 _spriteRect;
	//uniform float2 _screenSize;

	struct v2f {
		float4  pos : SV_POSITION;
	   float2  uv : TEXCOORD0;
		float2 scrPos : TEXCOORD1;
		float4 clr : COLOR;
	};

	float4 _MainTex_ST;

	v2f vert(appdata_full v)
	{
		v2f o;
		o.pos = UnityObjectToClipPos(v.vertex);
		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
		o.scrPos = ComputeScreenPos(o.pos);
		o.clr = v.color;
		return o;
	}



	half4 frag(v2f i) : SV_Target
	{
		rippleClip(i.scrPos);

	half random1 = (i.clr.x * 1000.0) - floor(i.clr.x * 1000.0);
	half random2 = (i.clr.y * 1000.0) - floor(i.clr.y * 1000.0);
	half random3 = (i.clr.z * 1000.0) - floor(i.clr.z * 1000.0);

	float dr = i.clr.w * 2 - 1;// -1 to 1

	float a = i.clr.w;
	float x = i.uv.x;
	float y = i.uv.y;
	float c = 0;

	y += sin((x - dr * .5) * 30 + random1) * .005 * random3;

	float s = (1 - abs(sin(y * (30 - random1 * 23)))) * 1.5 - 1;
	float t = abs(sin(y * (30 - random2 * 23))) * 2.75 - 2;
	if (x > a) {
		x = -x + a * 2;
	}

	s = s - x + a;
	s = (s - s % 1);
	s = min(max(s, 0), 1);

	t = (x + (t - a + 1));
	t = (t - t % 1);
	t = min(max(t, 0), 1);

	c += s;
	c += t;

	c = min(max(c, 0), 1);

	//c *= 1 - (abs(i.uv.x - .5));//1 - (abs(i.uv.x - .5) * 2);

	return half4(i.clr.xyz, c);

	//return half4(0, 0, 0, 0);
	}
	ENDCG



				}
			}
	}
}