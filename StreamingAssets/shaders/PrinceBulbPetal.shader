Shader "Futile/PrinceBulbPetal"
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
sampler2D _PalTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
float4 _MainTex_ST;

uniform float _RAIN;
uniform float4 _spriteRect;
uniform float2 _screenSize;

struct appdata {
    float4 pos : POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.pos);
    o.uv = TRANSFORM_TEX (v.uv, _MainTex);
    o.color = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    return i.color;
}
ENDCG
            }
        } 
    }
}