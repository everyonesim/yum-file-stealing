Shader "Futile/BackgroundJaggedCircle"
{
Properties 
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category 
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        SubShader
        {
            Pass
            {
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile _ RIPPLE
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_TerrainMask.cginc"

sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _GameplayRippleMask;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float4 _spriteRect;
uniform float2 _screenSize;


struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}



half4 frag (v2f i) : SV_Target
{
    #if RIPPLE
        rippleClip(0,tex2D(_GameplayRippleMask,i.scrPos).y);
    #endif

    float2 textCoord = floor(i.scrPos*_screenSize)/_screenSize;
    textCoord.xy -= _spriteRect.xy;
    textCoord.xy /= (_spriteRect.zw - _spriteRect.xy);
    
	BackgroundClipVanilla(_LevelTex, _GrabTexture, textCoord, i.scrPos);

    half f = 1-min(distance(i.uv.xy, half2(0.5, 0.5))*2, 1);

    half n = tex2D(_NoiseTex, i.uv.xy);
    f -= pow(n, f*lerp(10, 200, i.clr.w));


    if(f <= 0)
    return half4(0,0,0,0);


    return half4(i.clr.xyz, 1);
}
ENDCG
                
                
            }
        } 
    }
}
