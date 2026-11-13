Shader "Futile/SkyWhaleBody"
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
#include "_RippleClip.cginc"

#define PI 3.1415926

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NoiseTex;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    float2 scrPos : TEXCOORD1;
};

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
    float roll = (i.color.a - 0.5) * PI;

    float bumpHeight = tex2D(_NoiseTex, i.uv.x * float2(15, 1) + roll * float2(-1, 15) * 0.02) - 0.4;
    clip (1.1 - 0.1 * sin(roll) - i.uv.y - bumpHeight * 0.03);
    clip (0.1 + 0.1 * sin(roll) + i.uv.y - bumpHeight * 0.03);

    return tex2D(_MainTex, i.uv) * half4(i.color.rgb, 1);
}
ENDCG
            }
        }
    }
}
