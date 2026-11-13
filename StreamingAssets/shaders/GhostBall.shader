Shader "Futile/GhostBall"
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
#include "_RippleClip.cginc"
#define PI 3.14159265359

sampler2D _MainTex;
sampler2D _NoiseTex2;
sampler2D _PalTex;
uniform float _RAIN;
uniform float _echoAlpha;

float4 _MainTex_ST;

struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    
    // (yaw, pitch, -, -)
    float4 clr : COLOR;
};

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
    rippleClip(i.scrPos);
    
    // Project onto sphere
    float3 pos = float3(i.uv.x * 2.0 - 1.0, i.uv.y * 2.0 - 1.0, 0.0);
    float zSquared = 1.0 - pos.x * pos.x - pos.y * pos.y;
    if(zSquared <= 0) discard;
    pos.z = sqrt(zSquared);

    // Tilt head downwards
    float c = cos(i.clr.y * PI * 2.0);
    float s = sin(i.clr.y * PI * 2.0);
    pos.yz = float2(pos.y * c + pos.z * s, pos.z * c - pos.y * s);

    // Calculate spherical coordinates
    half2 uv = half2(atan2(pos.x, pos.z) / PI + 0.5 + i.clr.x, 1.0 - acos(pos.y) / PI);

    uv.x = floor(uv.x*32.0)/32.0;
    uv.y = floor(uv.y*64.0)/64.0;

    half4 texCol = tex2D(_MainTex, uv * float2(2.0, 1.0));

    half glimmer = 0;

    if(texCol.x > 0)
        glimmer = tex2D(_NoiseTex2, half2(texCol.x, _RAIN*0.02 + i.clr.x*0.2)).x;

    glimmer = max(0, glimmer - saturate(uv.y * 3.0 - 1.8));

    half4 texCol2 = tex2D(_PalTex, half2(2.5/32.0, 7.5/8.0));
    texCol2.w = _echoAlpha;
    return lerp(texCol2, half4(0.529, 0.365, 0.184, _echoAlpha), glimmer);
}



ENDCG
                
                
                
            }
        } 
    }
}