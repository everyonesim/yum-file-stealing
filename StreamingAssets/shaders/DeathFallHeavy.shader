// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

//Currently Unused
Shader "Futile/DeathFallHeavy" //Unlit Transparent Vertex Colored Additive 
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
sampler2D _PalTex;
//sampler2D _PalTex;
//uniform float _fogAmount;
uniform float _waterPosition;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _PreLevelColorGrab;

uniform float _RAIN;

uniform float4 _spriteRect;
uniform float2 _screenSize;
uniform float4 _camInRoomRect;

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

float2 textCoord = float2((i.scrPos.x*_screenSize.x)/_screenSize.x, (i.scrPos.y*_screenSize.y)/_screenSize.y);

textCoord.x -= _spriteRect.x;
textCoord.y -= _spriteRect.y;

textCoord.x /= _spriteRect.z - _spriteRect.x;
textCoord.y /= _spriteRect.w - _spriteRect.y;


half4 texcol = tex2D(_LevelTex, textCoord);

 //half4 texcol = tex2D(_LevelTex, textCoord);
 
 


 half dist = fmod(round(texcol.x * 255)-1, 30.0)/30.0;
 
 if(texcol.x == 1.0 && texcol.y == 1.0 && texcol.z == 1.0)
 dist = 1.0;

 if(dist > 6.0/30.0){
    half4 grabCol = tex2D(_PreLevelColorGrab, i.scrPos.xy);
  if(grabCol.x > 1.0/255.0 || grabCol.y != 0 || grabCol.z != 0) return float4(0, 0, 0, 0);
 }

 

	
	float amount = pow(dist, 0.3) * (1.5 - i.uv.y * 1.5);
amount *= 0.5 + 0.5 * pow (distance(i.uv, half2(0.5, 0.5)) * 2 + 1.0 - i.clr.w, 0.8);
amount *= 0.5 + 0.5 * tex2D(_MainTex, float2(_camInRoomRect.x + _camInRoomRect.z * i.scrPos.x, 0.0)).z;

	half4 col = lerp(half4(0,0,0,0), tex2D(_PalTex, float2(0, 7.0/8.0)), 0.2*dist);
	return half4(col.x,col.y,col.z,pow(amount, 1.0 - 0.05 * i.clr.w) * i.clr.w);
}
ENDCG
				
				
				
			}
		} 
	}
}
