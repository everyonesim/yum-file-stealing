Shader "Futile/BrainStem"
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
        Lighting Off
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
sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _PalTex;
uniform float _fogAmount;
uniform float _RAIN;
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

half4 terrainColor (float depth, float paletteIndex)
{
    return lerp(
        tex2D(_PalTex, float2((depth + 0.5) / 32.0, (paletteIndex + 0.5) / 8.0)),
        tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0)),
        _fogAmount * (depth / 30.0)
    );
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);

    float depth = tex2D(_NoiseTex, float2(i.uv.x, i.uv.x) + i.clr.rg).r * 0.75 + sqrt(1 - pow(i.uv.x * 2 - 1, 2)) * 0.25;
    depth *= 0.5 + 0.5 * pow(1 - min(i.uv.y * 1.5, 1), 1.25);

    //return tex2D(_PalTex, float2(lerp(8.5, 0.5, depth) / 32.0, 1.5 / 8.0));
    return terrainColor(lerp(9.0, 2.0, depth), 1);
}
ENDCG
            }
        }
    }
}