// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/RedsIllness" //Unlit Transparent Vertex Colored Additive 
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

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;


#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
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
float dist = distance(i.uv, half2(0.5, 0.5));
half2 dir = normalize(i.uv - half2(0.5, 0.5)); 
     
half2 grabPos = half2(i.scrPos.x, i.scrPos.y) - (dir * pow(sin(pow(clamp(1-dist*2, 0, 1), 4)*3.14), 10.0)*0.045 * i.clr.x) + dir*pow(dist, 6)*1335 * i.clr.x;
     
grabPos.x = (floor(grabPos.x*_screenSize.x)+0.5)/_screenSize.x;
grabPos.y = (floor(grabPos.y*_screenSize.y)+0.5)/_screenSize.y;

half4 grabColor = tex2D(_GrabTexture, grabPos);
grabColor.w = 1;

grabColor.x *= lerp(1, pow(clamp(1.0-dist*lerp(3,6,i.clr.y), 0, 1), 0.75), i.clr.y);
grabColor.y *= lerp(1-i.clr.y, pow(clamp(1.0-dist*lerp(0.3,6,i.clr.y), 0, 1), 4), i.clr.y);
grabColor.z *= lerp(1-i.clr.y, pow(clamp(1.0-dist*lerp(0.3,6,i.clr.y), 0, 1), 4), i.clr.y);

return grabColor;
}
ENDCG
				
				
				
			}
		} 
	}
}