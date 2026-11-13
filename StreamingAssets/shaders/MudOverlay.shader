Shader "Futile/MudOverlay"
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
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"

sampler2D _MainTex;
sampler2D _PalTex;
sampler2D _NoiseTex;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float2 mudUv : TEXCOORD2;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

half4 UnpackColor(float c)
{
    float3 color = float3(c, c * 255.0, c * 65025.0);
    color = frac(color);
    color.rg -= color.gb / 255.0;
    return half4(color, 1);
}

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = UnpackColor(v.color.b);
    o.mudUv = v.color.rg;
    o.clr.a = v.color.a;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);

    half4 black = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));
    half4 color = i.clr;

    //float lightness = 1 - max(i.clr.a * 10 - 9, 0) * 0.5;
    float lightness = 0.8;
    
    lightness *= tex2D(_PalTex, float2(30.5 / 32.0, 7.5 / 8.0)).r;
    color = lerp(black, color, lightness);

    float threshold = 1 - pow(i.clr.a, 0.2) * 0.6;
    float noise = tex2D(_NoiseTex, i.mudUv).r;
    if(noise < threshold)
        discard;
    return half4(color.rgb, tex2D(_MainTex, i.uv).a);
}
ENDCG
            }
        } 
    }
}
