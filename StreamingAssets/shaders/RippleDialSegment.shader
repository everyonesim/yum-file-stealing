Shader "Futile/RippleDialSegment"
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

sampler2D _MainTex;
float4 _MainTex_ST;
float _RAIN;

struct appdata {
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 clr : COLOR;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.uv;
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{   
    half4 color;
    float bump = pow(sin(_RAIN * 10 - length(i.clr.rg) * 6) * 0.5 + 0.5, 2);
    if (i.clr.b < 0.5) {
        // Unlit
        color = half4(0.3, 0.2, 1, 0.3);
        color.rgb = lerp(color.rgb, half3(1, 1, 1), max(0, i.clr.r) * 0.2);
        color.a *= cos(saturate(i.uv.y * 2.5) * 3.14159) * 0.5 + 0.5;
        color.a *= bump * 0.5 + 0.5;
    } else {
        // Lit
        color = half4(0.5, 0.1, 1, 1);
        color.rgb = lerp(color.rgb, half3(1, 1, 1), max(0, i.clr.r) * 0.2);
        color.rgb = lerp(color.rgb, half3(1,1,1), bump * 0.1);
        color.a *= pow(cos(i.uv.y * 3.14159) * 0.5 + 0.5, 1.5);
    }
    color.a *= i.clr.a;
    color.a *= pow(smoothstep(-0.8, 0.6, i.clr.r), 1.5);
    return color;
}
ENDCG
            }
        }
    }
}
