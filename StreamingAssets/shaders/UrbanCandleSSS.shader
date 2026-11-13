Shader "Futile/UrbanCandleSSS"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
        // Blend SrcAlpha One
		ZWrite Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
		GrabPass {"_PreUrbanCandleSSSGrab"}
		Pass
		{ 
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"
#include "_DynamicLevelElementFunctions.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR0;
    float2 texCoord : texcoord2;
};

sampler2D _MainTex;
sampler2D _PalTex;
sampler2D _NoiseTex;
sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _PreUrbanCandleSSSGrab;
float4 _spriteRect;
uniform float2 _screenSize;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

float2 QuantizeToPixels(float2 coord){
    float2 pixel = 1/_screenSize;
    return coord - fmod(coord, pixel);
}

fixed4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float candle = max(.01,Candle(i.clr,i.uv,_NoiseTex,_RAIN, false).x);
    fixed d = tex2D(_LevelTex,QuantizeToPixels(i.texCoord)).z;
    if (distance(i.clr.z*.9,d)>0.004 || d == 1) discard;
    fixed4 creatures =  tex2D(_PreLevelColorGrab,i.scrPos);
    fixed creatureMask = creatures != 0 ;
    if (i.clr.x < 0.9 && creatureMask) discard;
    float noise = tex2D(_NoiseTex, i.uv*fixed2(.02,.2)*.1+float2(_RAIN*.02+i.clr.z,-_RAIN*.6+i.clr.y))*2-1;
    fixed3 grab =  tex2D(_PreUrbanCandleSSSGrab,i.scrPos).xyz;
    float glowGradient = i.uv.y*fixed2(1,1/i.clr.w);
    glowGradient = glowGradient*1.1-candle*.1;
    glowGradient = smoothstep(.2-i.clr.w*.1+noise*.15,1+noise*.05,glowGradient);
    fixed topIndend = (2+smoothstep(.5,1,saturate(length((float2(i.uv.x,1-i.uv.y)*fixed2(1,1/i.clr.w)*2-1)*1+fixed2(0,1.1)))))*.333;
    glowGradient *= topIndend;
    candle = step(0.01,candle)*(.1+glowGradient*.9);
    fixed3 candleColor = fixed3(1,.75-i.clr.z*.1,.5-i.clr.x*.1)*candle;
    candleColor = max(candleColor,grab);
    return fixed4(candleColor,.5+i.clr.x*.2-(i.clr.y+i.clr.z)*.1);
}
ENDCG
		}
    }
}
