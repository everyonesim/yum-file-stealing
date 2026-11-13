Shader "Futile/WeaverThread" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		ZWrite Off
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
            Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _PreLevelColorGrab;
sampler2D _MainTex;
float4 _MainTex_ST;
float _waterLevel;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.texcoord;
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    _waterLevel+=.1;
    float waterMap = smoothstep(_waterLevel+.07,_waterLevel-.03,1-i.scrPos.y);
    float rippleMask = allRippleColorMask(i.scrPos);
    fixed3 gold =fixed3(0.529+i.clr.y*.3, 0.365, 0.184);
    fixed3 rippleGold = fixed3(0.255, 0.11, 0.87+i.clr.y*.3)*2;
    fixed4 weaverCol = fixed4(lerp(gold,rippleGold,rippleMask),1);
    float p = i.clr.x*1.2;
    float mask = smoothstep(0+p,-0.2+p,i.uv.x);
    float middle = smoothstep(.5,0.3,abs(i.uv.y-.5));
    float endsMask = smoothstep(.5,.2,abs(i.uv.x-.5));
    float alpha = endsMask*middle*mask*(.6+i.clr.y*.4)*.9;
    alpha *=waterMap;
    weaverCol.a = alpha;
    smoothTransRippleClip(weaverCol,i.scrPos);
    return fixed4(weaverCol.xyz,weaverCol.a*.5);
}

ENDCG
}
				Pass 
			{
            Blend One One 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _PreLevelColorGrab;
float _waterLevel;

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.texcoord;
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    _waterLevel+=.1;
    float waterMap = smoothstep(_waterLevel+.07,_waterLevel-.03,1-i.scrPos.y);
    float rippleMask = allRippleColorMask(i.scrPos);
    float bigShine = pulse(i.scrPos.x,fmod(.5+i.clr.y*.3+_RAIN*.5+(i.scrPos.y*2-1)*.3,1.8)-.4,.4);
    fixed3 gold =fixed3(0.529+i.clr.y*.3, 0.365, 0.184);
    fixed3 rippleGold = fixed3(0.355, 0.31, 0.87+i.clr.y*.3)*.5;
    fixed4 weaverCol = fixed4(lerp(gold,rippleGold,rippleMask),1);
    float p = i.clr.x*1.2;
    float mask = smoothstep(0+p,-0.2+p,i.uv.x);
    float bright = pulse(i.uv.x,i.clr.x*2-.8,.3);
    float middle = smoothstep(.5,0,abs(i.uv.y-.5));
    float endsMask = smoothstep(.4,.2,abs(i.uv.x-.5));
    float alpha = endsMask*middle*mask*(.6+i.clr.y*.4)*.9;
    float shine = pulse(fmod(i.uv.x+i.clr.y*13+_RAIN+smoothstep(0,1,i.uv.x)*3,1),.5,.2+.03*i.clr.y);
    shine +=pulse(fmod(i.uv.x+i.clr.y*18+bigShine+_RAIN*.9,1),.5,.02+.05*i.clr.y);
    alpha *= 1+shine+bright;
    alpha *= 1+sin((i.uv.x-_RAIN*.1*i.clr.y)*100)*.2;
    alpha *=waterMap;
    weaverCol *= mask*.4+.6+bright*.9;
    weaverCol +=shine*.2*bigShine;
    weaverCol.xyz*=alpha;
    smoothTransRippleClipAdditive(weaverCol,i.scrPos);
    return fixed4(weaverCol.xyz,alpha);
}

ENDCG
}

		} 
	}
}

