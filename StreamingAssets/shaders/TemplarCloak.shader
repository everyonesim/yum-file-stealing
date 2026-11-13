Shader "Futile/TemplarCloak"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }

    Category
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        Blend One OneMinusSrcAlpha
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
#include "_RippleClip.cginc"

sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _PalTex;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 color : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.color = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);

    float noise = tex2D(_NoiseTex, i.uv * 0.5 + i.color.aa);
    float noiseClip = noise - pow(max(0, i.uv.y * 2 - 1), 2);
    half4 black = tex2D(_PalTex, float2(2.5 / 32.0, 7.5 / 8.0));
    half4 color = half4(i.color.rgb, 1) * tex2D(_MainTex, i.uv);

    if (noiseClip < 0.1) discard;
    else if (noiseClip < 0.3) color = lerp(color, black, 0.5);
    else if (noise < 0.75 * i.uv.y) color = lerp(color, black, 0.25);
    
    return color;
}
ENDCG
            }
        }
    }
}