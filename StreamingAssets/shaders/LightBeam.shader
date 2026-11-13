// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// This Edit adds a shader variant that enables proper interaction with snow
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/LightBeam" //Unlit Transparent Vertex Colored Additive 
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
				//GrabPass { }
				
				Pass 
			{
				//SetTexture [_MainTex] 
				//{
				//	Combine texture * primary
				//}
				
				
				
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Snow.cginc"
#include "_TerrainMask.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;


#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

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

half alpha = i.uv.y * sin(i.uv.x*3.14);

half4 levCol = tex2D(_LevelTex, textCoord);
levCol = AddSnow(levCol,textCoord,i.scrPos);
half dp = ((int)(levCol.x * 254) % 30)/30.0;
if(levCol.x == 1 && levCol.y == 1 && levCol.z == 1) dp = 1;
dp = min(dp, TerrainAtLevelPos(textCoord, _spriteRect).r);
if (dp > 6.0/30.0){
		half4 grabColor = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
			if(grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
				dp = 6.0/30.0;
	}

int tp = floor(i.clr.w * 3.0);

if(tp == 1) alpha *= clamp((dp - 0.2) * 10, 0, 1);
else if(tp == 2) alpha *= clamp((dp - 0.5) * 20, 0, 1);

alpha *= i.clr.w*3.0 - tp;
half4 result = half4(i.clr.xyz, alpha);
smoothRippleClip(result,i.scrPos);
return result;
}
ENDCG
				
				
				
			}
		} 
	}
}
