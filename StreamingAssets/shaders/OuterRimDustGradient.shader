// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/OuterRimDustGradient" //Unlit Transparent Vertex Colored Additive 
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

uniform float4 _spriteRect;
uniform float2 _screenSize;


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
    o.uv = v.texcoord;//TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}


half4 frag (v2f i) : SV_Target
{
	// calculate screen coordinates
	float2 screenCoords = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
	screenCoords.x -= _spriteRect.x;
	screenCoords.y -= _spriteRect.y;
	screenCoords.x /= _spriteRect.z - _spriteRect.x;
	screenCoords.y /= _spriteRect.w - _spriteRect.y;

	// discard any pixels not in the background
	BackgroundClipVanilla(_LevelTex, _GrabTexture, screenCoords, i.scrPos);
	float curve = 1 - screenCoords.x;
	curve *= curve * curve * curve;
	float alpha = (-i.scrPos.y + lerp(1.3, 0.5, 1-curve)) * 2;
	float noiseTex = tex2D(_NoiseTex, screenCoords * 0.5).r;
	noiseTex = noiseTex * 2 - 1;
	
	float windSpeed = 0.25;
	float cloudsTex = tex2D(_CloudsTex, screenCoords * 1.5 + half2(-_RAIN, _RAIN * 0.1) * windSpeed - noiseTex * 0.1).r;
	float cloudsTex2 = tex2D(_CloudsTex, screenCoords + half2(-_RAIN, _RAIN * 0.5) * windSpeed * 0.7 + noiseTex * 0.1).r;
	float clouds = max(cloudsTex, cloudsTex2);
	float cloudColor = clouds * 1.5 - 0.5;

	clouds = clouds * 2 - 1;
	alpha += clouds;
	alpha = floor(alpha * 12) / 12;
	
	cloudColor = lerp(cloudColor, 0, smoothstep(0, 1, alpha*0.5 - 1));
	cloudColor = floor(cloudColor * 8) / 8;

	//return half4(cloudColor,cloudColor,cloudColor, 1);
	return half4(half3(i.clr.r, i.clr.g, i.clr.b) + cloudColor*0.05, alpha);
}



ENDCG
				
				
				
			}
		} 
	}
}
