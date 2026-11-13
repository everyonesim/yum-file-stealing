Shader "Futile/PearlReaderArm"
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
sampler2D _NoiseTex2;
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
    i.clr.w = i.clr.w*.5+.5;
    float s = .15*(1-i.clr.w*.4);
    float segments = smoothstep(2,0,abs((mod(i.uv.y,s)/s)*2-1));
    float roundness = pulse(i.uv.x,.5,.5);
    fixed widePart = step(segments,.95);
    fixed shape = step(smoothstep(.8,1.2,segments),roundness);
    fixed3 color = i.clr.xyz;
    color = lerp(color*.2,color,widePart);
    color = lerp(color,lerp(color*.9,1,(1-roundness)*.2),widePart);
    color = lerp(color,lerp(color*3,1,.5),(1-widePart)*step(roundness,.87));

    return fixed4(color,shape);
}
            ENDCG
		}
    }
}
