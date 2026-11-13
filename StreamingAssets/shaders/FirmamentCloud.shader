// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/FirmamentCloud" //Unlit Transparent Vertex Colored Additive 
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

	float randomThingPerDepth = frac(i.clr.a * 3.141592 * 1000);
	randomThingPerDepth = randomThingPerDepth * 2 - 1;
	randomThingPerDepth *= 0.3;
	half2 winda = _RAIN * half2(-0.25 + randomThingPerDepth, 0.25);
	half2 windb = _RAIN * half2(-0.35 + randomThingPerDepth, 0.125);
	
	float scale = 1.0F / ((1 + i.clr.a)*32);
	scale *= 24 * 1.5;
	float clouda = tex2D(_CloudsTex, (i.uv * half2(1, 1.4) * 2 + winda * 0.25) * scale + half2(0, i.clr.a * 1000)).r;

	half2 texUV = i.uv*half2(1.5,1) - half2(clouda*0.25, 0);
	texUV.x = clamp(texUV.x, 0, 0.99);
	texUV.y *= lerp(1, 1.2, i.clr.a);
	half4 c = tex2D(_MainTex, texUV);
	float shading = c.g;
	float alpha = c.r;

	
	float cloudb = tex2D(_CloudsTex, (i.uv * half2(1, 1.4) * 5 + winda*0.5 + shading * 0.25) * scale).r;
	float cloudc = tex2D(_CloudsTex, (i.uv * half2(1, 1.4) * 8 + windb*0.5 + shading * 0.25) * scale).r;

	shading = (shading * 2) - 1;
	if (shading > 0) shading *= 1.5;
	shading = clamp(lerp(cloudb, cloudc, 1) + shading * 0.6, 0, 1);

	// color quantization
	const float quantizationFactor = 6;
	shading = sqrt(shading);
	shading = floor(shading * quantizationFactor) / quantizationFactor;
	//shading /= shading;
	alpha = floor(alpha * 16) / 16;
	float distance = i.clr.a * 1.7 - 0.45;
	float parabola = -4 * distance * distance + 4 * distance;
	parabola = 1 - parabola;
	parabola = clamp(parabola, 0, 1);
	float fog = (1 - parabola) * 0.25;
	
	shading = lerp(shading, 0.8, 0.4);
	shading *= smoothstep(1, 0.5, i.clr.a);
	shading = lerp(shading * shading, shading, 0.5);
	alpha *= lerp(smoothstep(1, 0.5, i.clr.a), 1, 0.5);


	
	return half4(lerp(lerp(_AboveCloudsAtmosphereColor.rgb * 0.2, float(0.8).rrr, shading), _AboveCloudsAtmosphereColor.rgb, 1 - fog), alpha);
}



ENDCG
				
				
				
			}
		} 
	}
}
