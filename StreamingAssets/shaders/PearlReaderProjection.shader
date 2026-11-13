Shader "Futile/PearlReaderProjection"
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
        GrabPass { }
        Pass
        { 
            CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#pragma multi_compile_local _ debug opaque
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
    float2 texCoord[3] : TEXCOORD3;
};
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _MainTex;
sampler2D _PearlReaderGrab;
sampler2D _LevelTex;
sampler2D _NoiseTex2;
uniform float4 _spriteRect;
uniform float2 _screenSize;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.texCoord[0] = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.texCoord[1] = float2(o.texCoord[0].x*4+_RAIN*.4, o.texCoord[0].y*8 - _RAIN*10);
    o.texCoord[2] = float2(o.texCoord[0].x*4.1-_RAIN*.4, o.texCoord[0].y*8.1 - _RAIN*9);
    o.clr = v.color;
    return o;
}

half Screen(half hA, half hB){return 1.0-(1.0-hA)*(1.0-hB);}
half Overlay(half hA, half hB){if(hA > 0.5)return 1.0-(1.0-hA)*(1.0-hB); else return hA*hB;}

half4 frag (v2f i) : SV_Target
{
float len = saturate(length((i.uv*1.2)));

#if debug
    return fixed4(tex2D(_PearlReaderGrab, i.scrPos).xyz *(1-step(1,len)*.2), i.clr.w);
#endif

if(len >= 1.0) discard;
i.clr.w = smoothstep(0,1,i.clr.w);

half h = tex2D(_NoiseTex2, i.texCoord[1]).z;
half h2 = tex2D(_NoiseTex2, i.texCoord[2]).y;

float distMask = smoothstep(0.5*i.clr.w, .8+.4*i.clr.w, len);
float2 dst =  normalize(i.uv)*distMask*(.09-i.clr.w*.05);

float n = .2;
float2 sclCoord = i.texCoord[0].y*20 - _RAIN*0.15*40 -dst.y*3 ;
float scanlines = mod(sclCoord,n)/n;
fixed everyOther = step(mod(sclCoord,n*2),n); 
h = lerp(h,h2,everyOther);

scanlines = smoothstep(.5,0,abs(scanlines-.5));
dst = dst*(1+scanlines*(1-i.clr.w*.9)*.5);

fixed4 rawProjection = fixed4(tex2D(_PearlReaderGrab, i.scrPos - dst).xyz,1);

float thresh = .65;
thresh *= 1-distMask*.4;
fixed l = lightness(rawProjection);
#if opaque
l =  iLerp(-.1+scanlines*.1,.3,l);
#endif

l*=i.clr.w;

h += scanlines*lerp(0.1, 0.08, l);
rawProjection*=1+h*.2;

h = pow(h, lerp(lerp(0.5, 10, l), 0.5, len));

#if !opaque
half4 grabCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
half4 effectCol = half4(.4, .4, .4, 1.0);

rawProjection = lerp(rawProjection,half4(Overlay(rawProjection.x, effectCol.x), Overlay(rawProjection.y, effectCol.y), Overlay(rawProjection.z, effectCol.z), l), 1-l);
rawProjection = half4(Screen(rawProjection.x, grabCol.x), Screen(rawProjection.y, grabCol.y), Screen(rawProjection.z, grabCol.z), l);

rawProjection = lerp(rawProjection, effectCol, pow(1.0-l, 1.5));
thresh *= (.5+l*.9);
#endif

float activationBrightness = (1.5-i.clr.w*.5+smoothstep(0.3,.8,h)*.6);
fixed alpha = step(h*(3-i.clr.w*2),thresh);
fixed4 result = fixed4(rawProjection.xyz*activationBrightness,alpha);
smoothTransRippleClip(result,i.scrPos);

return result;
}
            ENDCG
		}
    }
}
