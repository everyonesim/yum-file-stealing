Shader "Futile/Whirlpool"
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

#define PI 3.1415926

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NoiseTex;
float _RAIN;


struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;

    // (tilt, water level, -, flow)
    float4 color : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.color = v.color;
    return o;
}

float SampleVortex(float theta, float tilt, float y)
{
    float time = _RAIN * 4.0;

    float t = tex2D(_NoiseTex, float2(2.0, -1.0) * (theta + time * 8.0 * tilt) / PI * 0.5 + float2(-1.0, 2.0) * tilt * (y * saturate(y * 4.0) + time)).r;
    return saturate(pow(1.0 - abs(t * 2.0 - lerp(1.4, 1.7, y)), 2.0));
}

half4 frag (v2f i) : SV_Target
{
    float t = (i.uv.x * 2.0 - 1.0) * (1.5 - i.uv.y * 0.5);
    if(abs(t) > 1.0) discard;
    float theta = acos(t);

    float front = SampleVortex(theta, i.color.r, i.uv.y);
    float back = SampleVortex(-theta, i.color.r, i.uv.y);
    float threshold = lerp(0.5, 1.0, pow(i.uv.y, 0.75));
    threshold = lerp(1.0, threshold, i.color.a);

    threshold = lerp(1.0, threshold, saturate((i.color.g - i.uv.y) * 2.5));

    if (abs(front) > threshold) return float4(0,1.0/255.0,0,1);
    if (abs(back) > threshold) return float4(1.0/255.0,1.0/255.0,1.0/255.0,1);
    return float4(0,0,0,0);
}
ENDCG
            }
        }
    }
}
