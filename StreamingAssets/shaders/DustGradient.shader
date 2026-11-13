// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/DustGradient" //Unlit Transparent Vertex Colored Additive 
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
#include "_TerrainMask.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _CloudsTex;
sampler2D _PalTex;
uniform float _fogAmount;
uniform half4 _AboveCloudsAtmosphereColor;
uniform half4 _MultiplyColor;
//uniform float _waterPosition;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;
uniform float _windDir;

uniform float4 _spriteRect;
uniform float2 _screenSize;


struct v2f {
    float4 pos : SV_POSITION;
   	float2 uv : TEXCOORD0;
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
	
	BackgroundClipVanilla(_LevelTex, _GrabTexture, textCoord, i.scrPos);

	half2 uv = i.uv.xy;
	if (uv.y > 0.99) return half4(0,0,0,0);

	float gradient = tex2D(_MainTex, uv).r;
	gradient *= 1.5;

	half2 noiseUV = half2(i.uv.x * 5.0 + i.clr.x, i.uv.y);
	noiseUV *= 3.0;

	half2 cloudUV = noiseUV;
	float windOffset = (_RAIN / i.clr.z);
	noiseUV += half2(windOffset * -0.001F, windOffset * -0.01F);
	cloudUV += half2(windOffset * -0.01F, windOffset * -0.005F);

	float noiseSize = 1.0F;
	float noiseTexture = tex2D(_NoiseTex, noiseUV * half2(noiseSize, noiseSize)).r * 0.2F;
	float cloudTexture = tex2D(_CloudsTex, cloudUV + half2(noiseTexture, noiseTexture)).r;
	float adjustedGradient = gradient - (1.0 - cloudTexture);
	float layers = 12.0;
	adjustedGradient = lerp(adjustedGradient, floor(adjustedGradient * layers) / layers, 1.0);

	half4 c = tex2D(_PalTex, half2(1.5 / 32.0, 7.5 / 8.0));
    c = half4(lerp(c.xyz, c.xyz * 0.8F, i.clr.z), adjustedGradient) * _MultiplyColor;
    smoothRippleClip(c,i.scrPos);
	return c;
}



ENDCG
				
				
				
			}
		} 
	}
}
