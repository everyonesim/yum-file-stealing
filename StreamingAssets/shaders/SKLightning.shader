Shader "Futile/SKLightning" 
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
		Cull Off 

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
            // Blend SrcAlpha OneMinusSrcAlpha 
            Blend One OneMinusSrcAlpha
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_local _ foreground flash
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _CloudsTex;
sampler2D _UniNoise;
sampler2D _PalTex;
sampler2D _MainTex;
float _waterLevel;
float4 _spriteRect;
float3 _SKLightningColor;
float4 _MainTex_ST;
float2 _SKLightningBlindness;
uniform float _fogAmount;
uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
    float2 texCoord : TEXCOORD3;
};

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
    rippleClip(i.scrPos);
float levelCol= tex2D(_LevelTex,i.texCoord).x;
float depth = get_depth_sat(levelCol);
fixed3 blueColor = fixed3(.25,.5,1.5);
fixed levelMask;
#if flash // cloudy background flash
float2 dir = normalize(i.uv*2-1);
float clouds = tex2D(_CloudsTex,i.texCoord*fixed2(1,1)*.7+float2(_RAIN*.01,0)).x;
float highlight =  clouds- tex2D(_CloudsTex,i.texCoord*fixed2(1,1)*.7+float2(_RAIN*.01,0)-dir*.055+sin(_RAIN*20)*.0005).x;
highlight = smoothstep(0,.45,highlight);
fixed3 flashCol = lerp(float(1).rrr,_SKLightningColor,.25);
    levelMask = saturate(iLerp(20,30,depth));
    float len = length(i.uv*2-1);
    float l1 = iLerp(1,0,len);
    float l2 = smoothstep(.8,.3,len);
    float t = pulse(i.clr.w,0.3,.2,.8);
    float t2 = pulse(i.clr.w,0.3,.2,.5);
    clouds = l2*levelMask*(pulse(clouds,1.9-t*1.3,.3)+highlight*t);
    return fixed4(flashCol*clouds*.1+(l1*.2+l1*levelMask*.3)*t2,l1*levelMask*.3*t2);
#endif

#if foreground
    float blind = smoothstep(0,2,_SKLightningBlindness.x);
#endif
float edgeFade = smoothstep(.5,.3,abs(i.uv.y-.5));
float sidesFade = smoothstep(.5,.2,abs(i.uv.x-.5));
float fgMult = 1;
#if foreground
fgMult = .5;
#endif
float bigNoise = tex2D(_NoiseTex,i.texCoord*1+i.clr.y*.2+float2(_RAIN*.01,-_RAIN*4)).x;

float bn = bigNoise*2-1;
float noise = tex2D(_NoiseTex2,i.uv*.0001+i.clr.y*.5*fgMult+float2(_RAIN*.01,-_RAIN*.09)).x;
noise += tex2D(_NoiseTex2,-i.uv*.0005+i.clr.y*.4*fgMult+float2(+_RAIN*.1,_RAIN*.01)).x;
float n = noise-1;
n*=smoothstep(.4,.2,abs(i.uv.y-.5));
float reveal = saturate(iLerp(.1+i.clr.x,0+i.clr.x,i.clr.y));
float peak = pulse(i.clr.y,i.clr.x,.1);
float fade = smoothstep(1,0.9,i.clr.z);
float breakup = saturate(iLerp(0.25,1,i.clr.z));
float discharge = pulse(i.clr.z,0.125,.125,.75)+i.clr.a*.5;
float mask = 1-abs(i.clr.y*2-1);
float intensify = i.clr.w*.3;
fixed cutoff = step(abs(i.uv.y-.5),.43);
float c;
float coreField;
fixed core;
fixed glow;
#if foreground
levelMask = saturate(iLerp(3,6,depth));

    float instability = smoothstep(.5,1,i.clr.x);
    c = smoothstep(0,.125,i.clr.x)*fade*.05f+pulse(i.clr.y,1,.3)*.3*(1-i.clr.x)-.02*blind;
    coreField = abs(i.uv.x-.5+n*(.1+i.clr.x*.5)+bn*instability*.2)+bigNoise*instability*.3;
    fixed glowField = abs(i.uv.x-.5+n*(.05+i.clr.x*.05)+bn*instability*.1)+bigNoise*instability*.3;
    core =  smoothstep(c,-0.2+c,coreField+i.clr.z+i.clr.z*noise)*edgeFade;
    glow =  smoothstep(.2+c,-0.1+c,glowField+i.clr.z)*edgeFade;
    return fixed4(core.xxx*(1-blind*.3)+glow*lerp(fixed3(2,2,1)*.5,_SKLightningColor,blind),core*blind)*levelMask;
#else
    fixed watermask = clamp(1-smoothstep(_waterLevel,_waterLevel+.20*smoothstep(.0,.82,bigNoise),1-i.scrPos.y),0,1);
    levelMask = saturate(iLerp(28,30,depth));
    c = reveal*fade*(.05+peak*.2+discharge*saturate(.1-bn*1*i.clr.z))*saturate(lerp(1-i.clr.y,mask,discharge)+peak*(1-i.clr.x)*.5);
    coreField = abs(i.uv.x-.5+n*(.1+i.clr.z*.3))+breakup;
    core =  smoothstep(c,-0.08+c,coreField);
    fixed coreGlow = smoothstep(0.+c*3,-.6+c*3,coreField);
    glow = smoothstep(.3-(1-discharge),-.5-(1-discharge),abs(i.uv.x-.5))*.25*saturate(discharge-breakup);
    glow += coreGlow;
    glow *=edgeFade*sidesFade;
    fixed alpha = max(min(glow,edgeFade)*.3*i.clr.x,core);
    core = saturate(core*cutoff);
    glow *=.3;
    return fixed4((core.xxx+glow*_SKLightningColor),core)*levelMask*watermask;
#endif

}

ENDCG
}

		} 
	}
}

