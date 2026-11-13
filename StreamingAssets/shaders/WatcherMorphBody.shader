Shader "Futile/WatcherMorphBody"
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

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float4 clr : COLOR0;
    float2 scrPos : TEXCOORD1;
};
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
uniform float4 _lightDirAndPixelSize;
uniform float4 _spriteRect;
uniform float2 _screenSize;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float strings = 0;
    float widthMix=i.uv.x*.5-.5;
    float stringWidth =saturate(smoothstep(0,.2,i.uv.y)*.04+saturate(i.uv.y-.4)*.1-.22+i.clr.w*.22);
    float tail = lerp(i.uv.y*10,0,i.uv.y+1.5);
    float stringMap =lerp(sin(tail)+.2,sin(tail+PI*.5),widthMix);
    strings +=pulse(stringMap,0.0,stringWidth);
    stringMap = lerp(cos(tail+PI*.5+1.5),cos(tail+1.5)+.7,widthMix);
    strings +=pulse(stringMap,0.0,stringWidth);
    stringMap = lerp(cos(tail+PI*.75+3.5)+.9,cos(tail+3.5),widthMix);
    strings +=pulse(stringMap,0.0,stringWidth);
    fixed segments =  step(0.0000001,pulse(i.uv.x,.5,.45+smoothstep(0,.008,abs(mod(i.uv.y-.06,.1)-.05))*.05));
    float showHead=(1-i.clr.w)*.14;
    float spikes = sin(i.uv.x*100+_RAIN*33)+sin(i.uv.x*77-_RAIN*31.5);
    float n = tex2D(_NoiseTex,i.uv*float2(.5,8)+float2(0,-_RAIN*4));
    float headRound = saturate(smoothstep(.00+showHead,-.08+showHead,i.uv.y));
    spikes *=smoothstep(0.04,0,i.uv.y)*i.clr.w;
    float a = abs(i.uv.x*2-1);
    float b = distance(i.uv*fixed2(2,25),float2(1,1));
    float body = lerp(a,b,step(i.uv.y,.04));
    i.clr.xyz += _GoldRGB.xyz*strings*0.8;
    i.clr.xyz += _GoldRGB.xyz*step(1-stringWidth*.3 ,strings)*1.5;
    body += n*headRound*1.5+n*.4*smoothstep(.05,.0,i.uv.y);
    return fixed4(i.clr.xyz, step(body-spikes*.05,0.999)*segments);
}
            ENDCG
		}
    }
}
