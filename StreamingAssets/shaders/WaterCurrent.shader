Shader "Futile/WaterCurrent"
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

float SampleVortex(float theta, float tilt, float y, float speed)
{
    float time = _RAIN * 4.0;
    float2 uv = float2(5.0, -2.0) * (theta + time * (abs(speed) + 0.5) * 2.0 * tilt) / PI * 0.5
              + float2(-1.0, 4.0) * tilt * (y + time * speed);

    // These can be longer than whirlpools, so sample the noise texture twice to hide repetition
    float t = abs(tex2D(_NoiseTex, uv).r - tex2D(_NoiseTex, uv * float2(-0.2, 0.3) + float2(0.5, 0.5)).r) * 2.0;
    return saturate(pow(1.0 - abs(t * 2.0 - 1.3), 2.0));
}

half4 frag (v2f i) : SV_Target
{
    float left = 0.25 * tex2D(_NoiseTex, float2(0.2 * _RAIN, 0.0) + float2(0.2, 0.25) * (i.uv.y + _RAIN * i.color.a * 7.0)).r;
    float right = 0.25 * tex2D(_NoiseTex, float2(0.0, 0.25) + float2(0.2 * _RAIN, 0.0) + float2(0.2, 0.25) * (i.uv.y + _RAIN * i.color.a * 7.0)).r;
    float t = (i.uv.x * 2.0 - 1.0) / (1.0 - left - right) + (left - right);
    float theta = acos(t);

    float front = SampleVortex(theta, i.color.r * 0.9, i.uv.y, i.color.a * 1.25);
    float back = SampleVortex(-theta, i.color.r * 0.9, i.uv.y, i.color.a * 1.25);

    const float innerShrink = 1.5;
    if(t * innerShrink < 1.0)
    {
        float innerTheta = acos(t * innerShrink);
        front = max(SampleVortex(innerTheta, i.color.r * 0.75, i.uv.y, i.color.a * 1.75), front);
        back = max(SampleVortex(-innerTheta, i.color.r * 0.75, i.uv.y, i.color.a * 1.75), back);
    }

    float threshold = 0.75;
    threshold = lerp(1.0, threshold, abs(i.color.a));

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
