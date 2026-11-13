Shader "Futile/UrbanCandleFlame"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend One OneMinusSrcAlpha 
		ZWrite Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
		Pass
		{ 
        // Blend SrcAlpha One
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
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
    float2 texCoord : texcoord2;
};

sampler2D _MainTex;
sampler2D _PalTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
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

fixed4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    fixed agitation = .1+i.clr.w*.9;
    agitation *=1;
    fixed4 creatures =  tex2D(_PreLevelColorGrab,i.scrPos);
    fixed creatureMask = creatures != 0 ;
    fixed depth = get_depth01(tex2D(_LevelTex,i.texCoord).x);
    if (depth<(1-i.clr.x)) discard;
    if (i.clr.x < 0.9 && creatureMask) discard;
    fixed3 brightFlameCol =  fixed3(1.00,0.61,0.38);
    fixed3 coldFlameCol =  fixed3(0.01,0.12,0.50);

    float noise = tex2D(_NoiseTex, i.uv*fixed2(.01,.2)+float2(_RAIN*.05+i.clr.z,-_RAIN*2));
    float noise1 = tex2D(_NoiseTex2, i.uv*fixed2(.001,.02)+float2(_RAIN*.03+i.clr.y,-_RAIN*1));
    float noise2 = tex2D(_NoiseTex, i.uv*fixed2(.01,.1)+float2(_RAIN*.03+i.clr.z,-_RAIN*1));
    noise += noise1*.2;
    noise *= agitation;
    i.uv.x+=(noise2*2-1)*i.uv.y*.5*agitation;
    float2 cuv = i.uv*2-1;
    cuv.x*=1.6;
    cuv.x*=1-noise*.6*i.uv.y;
    i.uv.y=clamp(i.uv.y,0,1);
    float tip = smoothstep(0.3-noise*.01,0.95,i.uv.y-noise*.05+.05);
    float bot = smoothstep(0.1,0.6,i.uv.y+noise*.10);
    float flame = 1-length(float2(cuv.x*(1.7+(tip)*.1),clamp(cuv.y*3.3+2.2,-1,0)-tip));
    float emptyPart = 1-length(float2(cuv.x*2.0,clamp(abs(cuv.y*2.3+1.1)-0.5,0,1)));
    float mainShape = smoothstep(0.0001,.03+(1-i.uv.y)*.4,flame);
    float emptyShape = smoothstep(0.0001,.3,emptyPart);
    float glow = 1-length(float2(cuv.x*(1.1-(tip)*.2),clamp(cuv.y*2.6+1.8,-2.9,0)-tip*.90));
    float glowShape = smoothstep(0.07,.7,glow);
    float coldBottom = smoothstep(0.31,.41,glow);
    fixed3 finalColor = 0;
    float smoothEmpty = saturate(1-(1-emptyPart)*(1-emptyPart));
    finalColor = lerp (finalColor, coldFlameCol*2.4,(coldBottom-smoothEmpty*1.1)*(1+bot)*.5*(1-tip*3));
    finalColor = lerp (finalColor, lerp(coldFlameCol,brightFlameCol*1.7,saturate(i.uv.y*2.0-.4)),saturate(glowShape-smoothEmpty*.3*(1-bot))-mainShape*bot);
    finalColor = lerp (finalColor, brightFlameCol*1.5,mainShape*(bot-smoothEmpty*.3));
    finalColor = lerp (finalColor, brightFlameCol*1.5,(mainShape-emptyShape)*bot);
    return  fixed4(finalColor,max(max(finalColor.x,finalColor.y),finalColor.z)*.7);
}
ENDCG
		}
    }
}
