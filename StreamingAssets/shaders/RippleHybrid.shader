Shader "Futile/RippleHybrid" 
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
            GrabPass{"_PreRippleHybrid"}
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

sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _PreRippleHybrid;
float4 _spriteRect;

uniform float _RAIN;

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

float annoyingRings(float2 uv, float scale, float t){
    uv*=4*scale;
    t*=2;
    float len = length(uv);
    float circle = length(uv+circularMotion(t+(len-fmod(len,.31415))*t)*.06);
    float rings = abs(sin(circle*10));
    rings = smoothstep(0.6,1.,rings);
    return rings;
}


half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    _RAIN+=i.clr.x*11;
    fixed3 palCol =  tex2D(_GameplayRipplePalTex,float2(0.5/32.0, 7.5/8.0));
    float2 cuv = i.uv*2-1;
    fixed sgn =  sign(i.clr.x-.5);
    float2 rcuv = mul (rotate2d(_RAIN*i.clr.x*4*sgn),cuv);
    float fan = sin(atan2(rcuv.x,rcuv.y)*7);
    fixed depth = get_depth_sat(tex2D(_LevelTex, i.texCoord).x);
    depth = saturate(iLerp(2,6,depth));

    float len = length(cuv);
    fan *= len;
    float radial = 1-len;
    fixed edgeFade = saturate(radial);

    float noise = tex2D(_NoiseTex,i.texCoord*fixed2(2,1)*8+float2(0,_RAIN*4+i.clr.x*.25)).x;
    float screenNoise = tex2D(_NoiseTex,i.texCoord*fixed2(2,1)*3).x;
    float rings = annoyingRings(cuv,.3-i.clr.x*.1, sgn*_RAIN*(15+i.clr.x*5)+i.clr.x*111+noise*.5)-fan*.5;
    float waves = sin(length(cuv*(5+i.clr.x))-_RAIN* (14+i.clr.x*6)+i.clr.x*77);
    waves+=rings;
    waves *= i.clr.y;
    float2 dst = normalize(cuv)*waves*(radial+screenNoise*.5);
    fixed3 distortion = tex2D(_PreRippleHybrid, i.scrPos - dst*.015);
    fixed3 tinted =fixed3(0,0.666,1)*max(max(distortion.x,distortion.y),distortion.z);
    distortion = lerp(distortion, tinted, smoothstep(1,.5,len)*waves);
    fixed garbage = step(1.8-i.clr.y*0.9,radial+waves*.15+screenNoise*.8);
    distortion = lerp(distortion, palCol,garbage);

// return 0;
return fixed4(distortion,depth*edgeFade*.5*i.clr.y);
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

sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
float4 _spriteRect;

uniform float _RAIN;

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

float annoyingRings(float2 uv, float scale, float t){
    uv*=4*scale;
    t*=2;
    float len = length(uv);
    float circle = length(uv+circularMotion(t+(len-fmod(len,.31415))*t)*.06);
    float rings = abs(sin(circle*10));
    rings = smoothstep(0.6,1.,rings);
    return rings;
}


half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    _RAIN+=i.clr.x*11;
    float2 cuv = i.uv*2-1;
    fixed depth = get_depth_sat(tex2D(_LevelTex, i.texCoord).x);
    depth = saturate(iLerp(2,6,depth));
    cuv = mul(rotate2d(PI*1.75+PI*2*i.clr.x+_RAIN*(5+i.clr.x*5)),cuv);
    fixed edgeFade = smoothstep(.0,.3,(1-abs(cuv.x))*(1-abs(cuv.y)));
    float noise = tex2D(_NoiseTex,i.uv+float2(0,_RAIN*2+i.clr.x)).x;
    float screenNoise = tex2D(_NoiseTex,i.texCoord*fixed2(2,1)*3).x;
    float rings = annoyingRings(cuv,.3-i.clr.x*.1, sign(i.clr.x-.5)*_RAIN*(15+i.clr.x*5)+i.clr.x*111+noise*.5);
    float waves = sin(length(cuv*(5+i.clr.x))-_RAIN* (14+i.clr.x*6)+i.clr.x*77);
    waves+=rings;
    cuv *= 1+waves*1;
    screenNoise *= tex2D(_NoiseTex,mul(rotate2d(i.clr.x*PI*2),i.texCoord*fixed2(2,1)*3)+float2(0,_RAIN*10)).x;
    float circle = saturate(1-length(cuv*2+noise));

    fixed3 col = fixed3(.125,noise*.5,.75);
    float mask =saturate(1-length(cuv-noise*.3))*(.2-i.clr.x*.05); 
    mask*=saturate(.5+screenNoise*.5);
    mask-=circle;
    mask = saturate(mask);
    col = lerp(col,fixed3(1+i.clr.x*30,10,10),circle*10);
    mask *= depth;
    mask *= edgeFade;
    mask *= waves;
    mask *= i.clr.y;
    return fixed4(col*mask*(1-circle),step(.0001,mask));

}
ENDCG
			}
		} 
	}
}
