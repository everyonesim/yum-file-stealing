// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/Rainbow" //Unlit Transparent Vertex Colored Additive 
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
				GrabPass { }
				
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

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _PalTex;

//sampler2D _PalTex;
//uniform float _fogAmount;
//uniform float _waterPosition;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;

uniform float4 _spriteRect;
uniform float2 _screenSize;
uniform float _waterLevel;

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

float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

textCoord.x -= _spriteRect.x;
textCoord.y -= _spriteRect.y;

textCoord.x /= _spriteRect.z - _spriteRect.x;
textCoord.y /= _spriteRect.w - _spriteRect.y;

float dst = distance(i.uv, half2(0.5, 0.5))*2;

if(dst > 1 || dst < i.clr.x) return half4(0,0,0,0);

float n = 0.5 + 0.5 * sin((tex2D(_NoiseTex2, half2(textCoord.x*30, textCoord.y*15 + _RAIN*0.12)).x * 3 + tex2D(_NoiseTex, half2(textCoord.x*4, textCoord.y*2 + _RAIN*0.04)).x)*6.28*2.5);

n = n * 3 - floor(n*3);
n = 0.5 + 0.5 * n;

half d = clamp((dst-i.clr.x) * 1.0 / (1.0 - i.clr.x), 0, 1);

half4 col = tex2D(_MainTex, half2(0.5, d));

if(n > 0.99995){
	half add = tex2D(_NoiseTex2, half2(textCoord.x*30, textCoord.y*15 + _RAIN*0.2812)).y;
	col = half4(clamp(col.x*(1+3*add), 0, 1), clamp(col.y*(1+3*add), 0, 1), clamp(col.z*(1+3*add), 0, 1), 1);
	n *= 1+add;
}

n *= clamp(sin(d*3.14)*1.5, 0, 1);


col.w *= n;

half4 levCol = tex2D(_LevelTex, textCoord);
half dp = ((int)(levCol.x * 254) % 30)/30.0;
if(levCol.x == 1 && levCol.y == 1 && levCol.z == 1) dp = 1;

col.w *= max(0, (dp - 0.2) * 1.5);

half4 grabCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
     
return half4(1.0 - (1.0-grabCol.x) * (1.0-col.x*col.w), 1.0 - (1.0-grabCol.y) * (1.0-col.y*col.w), 1.0 - (1.0-grabCol.z) * (1.0-col.z*col.w), i.clr.w);

}
ENDCG
				
				
				
			}
		} 
	}
}