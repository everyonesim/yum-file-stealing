// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/HazerHaze" //Unlit Transparent Vertex Colored Additive 
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

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _CloudsTex;
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

float dist = clamp(1-distance(i.uv.xy, half2(0.5, 0.5))*2, 0, 1);
 
half h = sin((tex2D(_NoiseTex, half2(textCoord.x*1.5, textCoord.y - _RAIN*0.1)).x + _RAIN*0.2)*6.28*2.5);
float2 dstrt = (float2(0.5, 0.66) - textCoord)*-0.06*h;
h = lerp(h, 1, pow(dist,0.35));

h -= tex2D(_NoiseTex2, float2(textCoord.x*15.2, _RAIN * -0.2 + textCoord.y*7.6) ).x * (1.7 - i.clr.w);
h += pow(tex2D(_CloudsTex, dstrt + half2(textCoord.x * 3, textCoord.y*3 -_RAIN*0.15)).x*1.5, 2);

h *= dist * i.clr.w;


half4 levCol = tex2D(_LevelTex, textCoord);
half dp = ((int)(levCol.x * 254) % 30)/30.0;
if(levCol.x == 1 && levCol.y == 1 && levCol.z == 1) dp = 0.72; //this number should be 1.0, but then there are errors so hey

if(dp > 6.0/30.0){
float4 grabTexCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0) dp = 6.0/30;
}

h *= clamp(((_waterLevel+0.16) - (1.0-i.scrPos.y))*10, 0, 1);

if(h * (0.2 + 0.8 * pow(dp, 0.6)) < 0.2) return float4(0, 0, 0, 0);

h = 0.2+pow(h,0.5)-dp*0.3;

half3 skyCol = tex2D(_PalTex, half2(0.5/32.0, 7.5/8.0));
half3 centerCol = lerp(skyCol, half3(0.1,0.1,0.2), 0.5+0.5*i.clr.x);

if(h < 0.5) return half4(lerp(skyCol, centerCol, round(h*6.0)/3.0), 1);
h = 0.5 + (h-0.5)*i.clr.w;
return half4(lerp(centerCol, half3(0.05,0.05,0.1), round(pow(h-0.5, 0.5)*6.0)/4.0), 1);

}
ENDCG
				
				
				
			}
		} 
	}
}