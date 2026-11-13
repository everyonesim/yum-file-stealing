// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


Shader "Futile/KingTusk" //Unlit Transparent Vertex Colored Additive 
{
Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
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

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}



half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);

//return half4(i.uv.xy, 0, 1);
half y = i.uv.y;

if(y < 0.4)
y -= pow(y-0.4, 2)*7;
else
y += pow(y-0.4, 2)*4;


y += i.clr.w;
y -= floor(y);

half h = tex2D(_NoiseTex, half2(i.uv.x, y)).x;
//if(h<0.5) h = pow(h, 2);
//else h = pow(h, 0.5);

h -= sin(y*6.0*3.14)*0.7;

if(h < 0.5) return half4(0,0,0,0);

return half4(i.clr.xyz, 1);



}
ENDCG
				
				
				
			}
		} 
	}
}






















