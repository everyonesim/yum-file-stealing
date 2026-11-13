// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/DeathFall" //Unlit Transparent Vertex Colored Additive 
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
            GrabPass{}
				Pass 
			{
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_local _ strong
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"

sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
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
    float2 texCoord : TEXCOORD3;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}



half4 frag (v2f i) : SV_Target
{

    half dist = get_depth01(tex2D(_LevelTex, i.texCoord).x);

 if(dist > 6.0/30.0){
     half4 grabCol = tex2D(_PreLevelColorGrab, i.scrPos.xy);
     if(grabCol.x > 1.0/255.0 || grabCol.y != 0 || grabCol.z != 0) return float4(0, 0, 0, 0);
 }
 
    fixed4 grab = tex2D(_GrabTexture, i.scrPos);
    dist = saturate(iLerp(0.1,0.3,dist));
 
    float amount = pow(dist, 0.3) * smoothstep(1,-.5,i.uv.y);
#if strong
    amount *=2;
#endif

    fixed4 col = grab;
    fixed l = lightness(col);
    col = lerp(col*l*.2,(1-col)*.1*i.clr.w,saturate(iLerp(.2+sin(_RAIN*10)*0.1,0,l)));
	return half4(col.xyz,iLerp(0,1-i.clr.w*.1,amount) * i.clr.w);
}
ENDCG
				
				
				
			}
		} 
	}
}
