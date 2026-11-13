// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/SootMark" //Unlit Transparent Vertex Colored Additive 
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
sampler2D _NoiseTex2;
sampler2D _PalTex;
//uniform float _fogAmount;
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

//if(distance(i.uv, half2(0.5, 0.5)) > 0.5)
//return half4(0,0,0,0);

float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

textCoord.x -= _spriteRect.x;
textCoord.y -= _spriteRect.y;

textCoord.x /= _spriteRect.z - _spriteRect.x;
textCoord.y /= _spriteRect.w - _spriteRect.y;

half4 levCol = tex2D(_LevelTex, textCoord);



half terrainDpth = ((int)round(levCol.x * 255) % 30)/30.0;
if(levCol.x == 1 && levCol.y == 1 && levCol.z == 1)
return half4(0,0,0,0);

if(terrainDpth > 6.0/30.0){
float4 grabTexCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
return float4(0,0,0,0);
}

terrainDpth -= 0.18;
terrainDpth = max(terrainDpth, 0) / 0.82;

float centerDist = distance(i.uv, half2(0.5, 0.5)) * 2;
half alpha = 1-tex2D(_MainTex, i.uv + normalize(i.uv-half2(0.5, 0.5)) * (-0.06 + terrainDpth * 0.12) * centerDist).x;

alpha *= i.clr.w - tex2D(_NoiseTex2, half2(textCoord.x*20, textCoord.y*12.5)).x * (1 + centerDist*0.5 + pow(abs(terrainDpth-0.3),2) * (3 + centerDist * 6));


half3 setCol = tex2D(_PalTex, half2(0, 1.5/8.0));

if(alpha < 0.1)
return half4(0,0,0,0);
else if(alpha > 0.25)
return half4(setCol, i.clr.w * 0.9 * pow(1-terrainDpth, 0.75));
else
return half4(setCol, i.clr.w * 0.5 * pow(1-terrainDpth, 0.75));

}
ENDCG
				
				
			}
		} 
	}
}















