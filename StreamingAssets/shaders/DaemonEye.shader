// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/DaemonEye" //Unlit Transparent Vertex Colored Additive 
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
#include "_RippleClip.cginc"
#include "_Functions.cginc"
#include "_TerrainMask.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex;
sampler2D _PalTex;
uniform float _fogAmount;
uniform float _waterPosition;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;

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
	half2 normalizedUV = (i.uv * 2.0F - 1.0F) * 2;

	float wave = sin(length(normalizedUV) * 15 - _RAIN * 10);

	float depth = i.clr.a + wave * 0.01F;
	
    float2 texCoord = iLerp(_spriteRect.xy,_spriteRect.zw, i.scrPos);
	fixed creatures = tex2D(_PreLevelColorGrab, i.scrPos) != (fixed4)0;
    fixed4 levelTex = tex2D(_LevelTex, texCoord);
    levelTex = AddTerrain(levelTex, texCoord, _spriteRect);
    float levelDepth = get_depth_sat(levelTex.x);
    levelDepth = lerp(levelDepth, min(levelDepth, creatures), creatures) / 30.0F;
	
	// float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
	// textCoord.xy -= _spriteRect.xy;
	// textCoord.x /= _spriteRect.z - _spriteRect.x;
	// textCoord.y /= _spriteRect.w - _spriteRect.y;
	//
	// float levelDepth = TerrainAndLevelDepthUnclamped(_LevelTex, textCoord, _spriteRect) / 30.0F;
	float depthDif = clamp(levelDepth - depth, 0, 1);
	
	half2 rippledUV = normalizedUV + wave * normalize(normalizedUV) * 0.1;
	rippledUV += half2(0, -1) * tex2D(_NoiseTex, normalizedUV * half2(1, 0.3)).r * 0.1;
	half2 eyePos = half2(i.clr.r, i.clr.g) * 2.0F - 1.0F;
	eyePos *= 0.8F;
	
	float dist = length(rippledUV - eyePos);
	float reflection = length(rippledUV - eyePos * -0.5);
	
	float circle = smoothstep(0.8F, 0.0F, dist);
	circle = floor(circle * 15.0F) / 15.0F;
	circle = circle * circle * circle * circle;
	circle *= circle * circle * 8.0F;
	float glow = 1.0F / ((dist + 1) * (dist + 1));
	
	float anticircle = smoothstep(0.3F, 0.0F, reflection);
	anticircle = floor(anticircle * 5.0F) / 5.0F;
	anticircle *= 0.1;

	half3 eyeColor = circle * _GoldRGB.rgb;
	eyeColor += anticircle * _GoldRGB.rgb;
	eyeColor += glow * 0.2F * lerp(_RippleGold.rgb, half3(1, 1, 1), 0.2F);
	//half3 fogCol = tex2D(_PalTex, float2(1.5/32.0, 7.5/8.0)).rgb;
	//eyeColor = lerp(eyeColor, fogCol, depth + 0.1F);
	eyeColor *= smoothstep(2, 0.4, length(normalizedUV));
    eyeColor *= 1+smoothstep(0,1,pulse(i.clr.z,.8,.4,.2)*.5);

	half2 grabPos = half2(i.scrPos.x, i.scrPos.y);
	grabPos += wave * normalize(normalizedUV) * 0.05F * smoothstep(1, 0.8, length(normalizedUV)) * pow(depthDif, 1.5);

	float leakIntensity = min(smoothstep(0, -0.5, normalizedUV.y), smoothstep(-2.0, -0.5, normalizedUV.y));
	leakIntensity *= smoothstep(lerp(0.6, 0.2, smoothstep(-0.5, -2.0, normalizedUV.y)), 0, abs(normalizedUV.x));
	
	float wiggle = sin(normalizedUV.y*7 + _RAIN*10)*0.05;
	leakIntensity -= (sin(tex2D(_NoiseTex, normalizedUV * half2(1, 0.1) + half2(wiggle, 0) + _RAIN * half2(0, 1) * 0.5F).r * 6) * 0.5 + 0.5) * 0.4;
	leakIntensity = 1 - clamp(leakIntensity, 0, 1);

	grabPos += half2(0, 1) * (1-leakIntensity) * 0.02F;

	half3 grabCol = tex2D(_GrabTexture, grabPos).rgb;
	half3 finalCol = grabCol;
	
	half3 fogCol = tex2D(_PalTex, float2(1.5/32.0, 7.5/8.0)).rgb;
	half3 blackCol = tex2D(_PalTex, float2((0.5 + depth*29.0F)/32.0, 0.5/8.0)).rgb;
	blackCol = lerp(blackCol, fogCol, depth * 1-(_fogAmount/30.0F));

	if (depth < levelDepth + (5 / 30.0F))
		finalCol = lerp(blackCol, finalCol, leakIntensity * leakIntensity * leakIntensity);
	blackCol *= 0.75F;
	
	finalCol = lerp(blackCol, finalCol, max(smoothstep(0.1, 0.0, depthDif), smoothstep(0.7, 1.0, length(normalizedUV))));
	finalCol = lerp(grabCol, finalCol, max(0.5, i.clr.b));

	if (depth < levelDepth)
		finalCol += eyeColor * clamp(depthDif * 10, 0, 1) * smoothstep(1, 0.8, length(normalizedUV)) * 0.5F * i.clr.b;

	if (length(grabCol - finalCol) < 0.001)
		discard;
	half4 result = half4(finalCol.r, finalCol.g, finalCol.b, 1.0F);
	//smoothRippleClip(result,i.scrPos);
	return result;
}
ENDCG
				
				
			}
		} 
	}
}
