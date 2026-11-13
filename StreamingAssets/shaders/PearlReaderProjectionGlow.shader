Shader "Futile/PearlReaderProjectionGlow"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
        // Blend SrcAlpha OneMinusSrcAlpha 
        Blend One One 
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
#pragma  multi_compile_local _ ray
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
uniform float4 _lightDirAndPixelSize;
uniform float _hologramThreshold;
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
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.clr = v.color;
    o.clr.w = smoothstep(0,1,o.clr.w);

    fixed3 col = 0;
#if ray
    col = tex2Dlod(_PearlReaderGrab, float4(o.clr.xy,0,0)).xyz;
    col *=o.clr.w;
    o.clr = fixed4(col.xyz,o.clr.w);
    return o;
#endif

    float2 dir = normalize (o.uv *2 - 1);
    for (int i = 0; i < 10; i++){
    col += tex2Dlod(_PearlReaderGrab, float4(o.clr.xy-
                float2(sin(i*.2*PI+_RAIN*333),
                       cos(i*.2*PI+_RAIN*333))
                *o.clr.z*.25*(1+sin(_RAIN*777)*.1),0,0)).xyz;
    }
    col = fixed4(normalize(col.xyz),1);
    col *=.5*o.clr.w;
    o.clr = fixed4(col.xyz,o.clr.w);
    return o;
}

half4 frag (v2f i) : SV_Target
{
    fixed4 result = 0;
#if ray 
    i.clr = lerp(i.clr.wwww*.2,i.clr,saturate(i.uv.y*3));
    result = i.clr*pulse(i.uv.y,.2,.2,.8)*smoothstep(1,0.0,length(i.uv.x*2-1)) ;
    smoothTransRippleClipAdditive(result,i.scrPos);
    return result;
#endif
    result = i.clr*smoothstep(1,0.0,length(i.uv*2-1));
    smoothTransRippleClipAdditive(result,i.scrPos);
    return result;
}
            ENDCG
		}
    }
}
