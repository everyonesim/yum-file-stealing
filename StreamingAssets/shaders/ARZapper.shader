Shader "Futile/ARZapper"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
        GrabPass{"_ARZapperGrab"}
		Pass
		{ 
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#pragma multi_compile_local _ oneEndConnected glow
#pragma multi_compile_local _ omniDirectional
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"

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
    float2 texCoord : TEXCOORD3;
};

sampler2D _ARZapperGrab;
sampler2D _PreLevelColorGrab;
sampler2D _MainTex;
sampler2D _LevelTex;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

float edgeFade(float2 cuv,float amount, float ratio){
    cuv = 1-abs(cuv);
    cuv *= float2(1,1/ratio);
    return smoothstep(0,amount,cuv.x)*smoothstep(0,amount,cuv.y);
}

float3 ZapperCol(float temp){
    return hsv2rgb(1.00-temp*.05,0.8,temp*5);
}

float4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float time = _RAIN;
    float2 cuv = i.uv*2-1;
    float temp = i.clr.x;
    float coolDown = i.clr.y;
    float distortionAmount = smoothstep(0,1,iLerp(.5,1,temp));
#if glow
    float3 g = tex2D(_ARZapperGrab, i.scrPos);
    float m = edgeFade(cuv,.95,1)*(.25*temp+.4*distortionAmount);
    float3 col = ZapperCol(temp*(.3+m*.3));
    float4 glowResult =float4(lerp(g,g+col,distance(g,saturate(col))),m*1);
    smoothRippleClip(glowResult,i.scrPos);
    return glowResult;
#endif
#if omniDirectional
    float middle = edgeFade(cuv,.9,1)*(.5*temp+.4*distortionAmount);
    float bars = smoothstep(3,.6,length(cuv))*2;
    float ends = edgeFade(cuv,.9,.5+temp*.5)*(.5*temp+.4*distortionAmount);

#else //onmiDirectional
    float middle = pulse(cuv.y,0,2);
    float bars = pulse(abs(cuv.x),.5,0.5);
    #if oneEndConnected
        float ends = pulse(i.uv.y,1,saturate(0.5+temp*2));
    #else
        float ends = pulse(abs(cuv.y),1,0.5+saturate(temp*.5*2));
    #endif

#endif //onmiDirectional

    float2 dir = normalize(cuv);
    float creatures =  tex2D(_PreLevelColorGrab,i.scrPos) == 0;
    float strength = 1-length(cuv);
    float2 distortion = dir*sin(middle*40+strength*40-time*50)*bars*middle*.00005*distortionAmount;

    float3 grab = tex2D(_ARZapperGrab, i.scrPos+distortion);
    float depth = get_depth_sat(tex2D(_LevelTex,i.texCoord+distortion).x);

    float firstLayer = saturate(iLerp(9,0, depth));
    float fade = edgeFade(cuv,.1+firstLayer*.3,i.clr.z);
    float innerGlow = pulse(firstLayer,.6,.5);
    float glowShape = lerp(middle,ends,coolDown+temp*.2);
    temp*=1+innerGlow*.2;
    float3 zapperCol = ZapperCol(temp*glowShape);
    float3 zapperColFlat = ZapperCol(temp);
    float3 finalColor = grab + zapperCol * innerGlow * 3;
    float mask = step(.1,firstLayer);
    if (depth>5)
        mask *= creatures;
    grab = lerp (grab,finalColor,fade);
    float4 result = float4(grab,mask);
    smoothRippleClip(result,i.scrPos);
    return result;
}
ENDCG
		}
    }
}
