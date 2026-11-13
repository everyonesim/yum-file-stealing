Shader "Futile/WeaverFeather"
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

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.clr = v.color;
    
    return o;
}

half4 frag (v2f i) : SV_Target
{
    half4 black = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));
    half4 gold = half4(0.529, 0.365, 0.184, 1.0);
    half4 sky = tex2D(_PalTex, float2(0.5/32.0, 7.5/8));

    half4 rootColor = lerp(gold, black, i.clr.b);
    half4 tipColor = lerp(gold, black, i.clr.g);
    half4 col = tex2D(_MainTex, i.uv) * lerp(rootColor, tipColor, pow(i.clr.r, 0.75));

    // Keep in sync with VoidWeaver.cs
    float darkFac = pow(i.clr.a, 0.75) * 0.5;
    float skyFac = pow(i.clr.a, 0.5) * 0.5;
    //col.rgb = lerp(lerp(col.rgb, black, darkFac), sky.rgb, skyFac);

    return col;
}
ENDCG
            }
        } 
    }
}