// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/GreebleGrid" //Unlit Transparent Vertex Colored Additive 
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

	float bigNoise = tex2D(_NoiseTex, i.uv + i.clr.a).r;
	bigNoise = bigNoise * 2 - 1;

#if defined(SHADER_API_SWITCH)
	// a good approximation that saves us two samples
	float greeble = -bigNoise;
#else
	float greeblea = tex2D(_MainTex, i.uv * 5 + i.clr.a * 100).b;
	greeblea = greeblea * 2 - 1;
	float greeble = tex2D(_MainTex, i.uv * half2(1, 0.25) * 5 + i.clr.a * 100 + greeblea * 0.005).b;
	greeble = greeble * 2 - 1;
#endif

	half2 warble = half2(0, -tex2D(_NoiseTex2, i.uv*half2(1,0.1)*0.5 + i.clr.a * 50 + _RAIN*0.01).r);
	//warble = warble * 2 - 1;
	warble *= 0.005;
	
	half2 texUv = i.uv + greeble * 0.001 + bigNoise * 0.05 + warble;
	half4 c = tex2D(_MainTex, texUv);
	float bar = i.clr.r * c.r + (1 - i.clr.r) * c.g;
	clip(bar - 0.9);

	half4 cOffset = tex2D(_MainTex, texUv + half2(-0.001,0.002));
	float greebleb = tex2D(_MainTex, i.uv*5 + greeble * 0.001 + bigNoise * 0.05 + warble).b;
	clip(greebleb - 0.2);

	float fog = 1 - i.clr.a;
	float threshold = 0.8;
	fog = fog < threshold ? fog/threshold : (1-fog)/(1-threshold);
	fog = fog * fog * fog;
	
	float brightness = c.b + greebleb;
	
	float vx = abs(screenCoords.x - 0.5)*1.5 + bigNoise*0.1;
	float vy = abs(screenCoords.y - 0.5)*1 + bigNoise*0.1;
	float vignette = smoothstep(1, 0, sqrt(vx * vx + vy * vy));
	brightness *= vignette;
	
	brightness = floor(brightness * 32) / 32;
	brightness *= min(screenCoords.y*2,1);

	float shading = i.clr.r * cOffset.r + (1 - i.clr.r) * cOffset.g;
	shading = 1-shading;
	shading /= 0.2;
	shading = shading * 2 - 1;

	float shadows = min(shading, 0);
	float highlights = clamp(shading, 0, 1);
	brightness = brightness * 0.3 + shadows*0.4 + highlights*0.5;
	//half3(30.0, 28.0, 30.0)/30.0
	return half4(lerp(half3(1,1,1) * brightness * 0.3, _AboveCloudsAtmosphereColor.xyz, 1-fog), 1.0);
}



ENDCG
				
				
				
			}
		} 
	}
}
