Shader "Futile/PearlReaderHolder"
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
            GrabPass{}
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
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

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
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float len = length(i.uv);
    float2 dist = normalize(i.uv);
    float a = _screenSize.x/_screenSize.y;
    float ring = pulse(len,.5+sin(_RAIN*10)*.05,.2);
    float halfWayMask=smoothstep(-.5,.2,i.uv.y);
    ring *= halfWayMask;
    dist.y*=a;

    fixed4 grab = tex2D(_GrabTexture,i.scrPos-dist*ring*.004*i.clr.w);
    grab.xyz = lerp(grab.xyz,grab.xyz*(1+.51*smoothstep(.5,1,i.clr.w + sin((_RAIN*10)*.1)*i.clr.w)*halfWayMask),saturate(1-len));

    return fixed4(grab.xyz,1);
}
            ENDCG
		}
    }
}
