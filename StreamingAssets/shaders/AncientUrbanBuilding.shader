// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/AncientUrbanBuilding" //Unlit Transparent Vertex Colored Additive 
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

	half4 c = tex2D(_MainTex, i.uv);

	// early clipping to save us a ton of samples below
	// note: _MainTex has binary alpha (0 or 1)
	clip(c.a - 0.9);

	float shading = c.r;
	float depth = c.g;
	float inLight = step(0.5, c.b);

	// discard anything "in front"
	clip(i.clr.y - depth);

	float palettePos = (3.0 * shading) - 0.5F + inLight * 3.0;

	half4 returnCol = tex2D(_PalTex, half2(20.5 / 32.0, palettePos / 8.0));
	returnCol = lerp(returnCol, tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0)), _fogAmount);

    returnCol = half4(lerp(returnCol.xyz, tex2D(_PalTex, float2(0.5 / 32.0, 7.5 / 8.0)).xyz * half4(0.85, 0.85, 0.85, 1.0), i.clr.x).xyz, 1.0) * _MultiplyColor;
    smoothRippleClip(returnCol,i.scrPos);
	return returnCol;
}



ENDCG
				
				
				
			}
		} 
	}
}
