// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/DustDunes" //Unlit Transparent Vertex Colored Additive 
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
    o.uv = v.texcoord;
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

	float weirdOffset0 = tex2D(_NoiseTex, i.uv.xy * half2(1, 0.2) * 20 + i.clr.a * 100).r;
	float weirdOffset = tex2D(_NoiseTex, i.uv.xy * half2(1, 0.2) * 20 + i.clr.a * 100 + half2(-_RAIN * (1 - i.clr.a) * 2 + weirdOffset0*0.1, 0)).r;
	weirdOffset = floor(weirdOffset * 12) / 12;
	weirdOffset = weirdOffset * 2 - 1;
	float middle = (i.scrPos.x - 0.8F);
	float h = 1 - i.uv.y;
	h *= h;
	half2 uv = half2(i.uv.x + middle * i.uv.y * 0.2, i.clr.a * 0.5F) + half2(weirdOffset, 0) * 0.01 * (1-i.clr.a);
	half4 c = tex2D(_MainTex, uv);
	
	float parabola = -4 * i.uv.x * i.uv.x + 4 * i.uv.x;
	float height = (c.r) * 0.8 + 0.2;
	height *= sqrt(parabola);
	height *= 1.2;
	if (i.uv.y > height) discard;
	if (i.uv.y < (1 - parabola) * 0.2) discard;
	float color = tex2D(_NoiseTex, half2(i.uv.x * 5, i.clr.a + i.uv.y * middle)).r;
	color = color + weirdOffset * 0.05;
	color *= height;
	
	float brightness = c.g;
	float sideFade = 1 - i.uv.x;
	sideFade *= sideFade * sideFade * sideFade * sideFade;
	brightness *= 1 - sideFade;
	float frontFade = clamp(i.clr.a * 5, 0, 1);
	brightness *= frontFade;
	brightness += (color * 2 - 1) * 0.5;
	brightness = floor(brightness * 7) / 7;
	brightness = clamp(brightness + 0.5, 0, 1.2);
	brightness *= brightness;
	
	float fogginess = 1 - i.clr.a;
	fogginess *= fogginess * fogginess * fogginess;
	//return half4(0, frontFade, 0, 1);
	half4 baseColor = lerp(float(0.5).rrrr, _AboveCloudsAtmosphereColor * 0.5, 1-brightness);
	baseColor = lerp(baseColor, 0.5, 0.5);
	half4 finalColor =  lerp(baseColor, _AboveCloudsAtmosphereColor, 1 - fogginess);
	finalColor.a *= smoothstep(0, 0.2, i.uv.x);
	return finalColor;
}



ENDCG
				
				
				
			}
		} 
	}
}
