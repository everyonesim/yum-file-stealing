// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/BackgroundDune" //Unlit Transparent Vertex Colored Additive 
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

	// discard any pixels not in the background
	BackgroundClipVanilla(_LevelTex, _GrabTexture, textCoord, i.scrPos);

	// for sampling the terrain noise....
	// todo: bake all of this into a single texture
	// will improve peformance significantly.
	float depth = i.clr.z;
	float2 terrainCoords = float2(i.uv.x + 0.5F, depth);
	half2 offsetCoords = textCoord * 2 - 1 + half2(_RAIN * (1/depth), 0);
	half2 toffset = half2(tex2D(_NoiseTex, offsetCoords * 5 / (1-depth) * half2(1, 2)).rg);
	toffset = floor(toffset * 4.0) / 4.0;
	terrainCoords += toffset * 0.005;
	float bigDunes = 1.0 - abs(tex2D(_NoiseTex, terrainCoords).r * 2.0 - 1.0);
	
	float duneHeight = tex2D(_NoiseTex, terrainCoords * 0.3).r;

	// bias the hell out of it!
	duneHeight = duneHeight * duneHeight * (3.0 - 2.0 * duneHeight);
	duneHeight = duneHeight * duneHeight * (3.0 - 2.0 * duneHeight);
	duneHeight = duneHeight * duneHeight * (3.0 - 2.0 * duneHeight);
	duneHeight = duneHeight * duneHeight * (3.0 - 2.0 * duneHeight);

	float teenyDunes = (1.0 - abs(tex2D(_NoiseTex, terrainCoords * 8.0).r * 2.0 - 1.0));

	float multiplier = 1.0 - depth;
	multiplier *= multiplier * multiplier * multiplier;
	float terrainHeight = bigDunes * (1.0 - multiplier);
	terrainHeight *= duneHeight * 0.8;
	terrainHeight += teenyDunes * (1.0 - bigDunes) * 0.1;
	//terrainHeight -= (1-(depth * depth)) * 0.5;
	terrainHeight -= 0.8;
	// discard any pixels below the terrain height.
	if (i.uv.y * 2.0 - 1.0 > terrainHeight) return half4(0,0,0,0);

	float color = 0.1 + floor( (duneHeight + teenyDunes * (1 - bigDunes)) * 16.0) / 16.0;
	return lerp(half4(color, color, color, 1), _AboveCloudsAtmosphereColor, sqrt(depth));
}



ENDCG
				
				
				
			}
		} 
	}
}
