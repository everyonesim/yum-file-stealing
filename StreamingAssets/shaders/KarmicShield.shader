Shader "Futile/KarmicShield"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category 
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
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
#define PI 3.14159265359

sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _GrabTexture;
sampler2D _BigKarmaTex;

float _RAIN;
float2 _screenSize;
float4 _spriteRect;

struct v2f
{
    float4 pos : SV_POSITION;
    float2 offset : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float2 grabPos : TEXCOORD2;
    float2 uv : TEXCOORD3;

    // (symbol, extra glow, unused, brightness)
    float4 color : COLOR;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.offset = v.texcoord * 2 - 1;
    o.uv = float2(0.5, v.color.r + 0.5 / 10.0);
    o.scrPos = ComputeScreenPos(o.pos);
    o.grabPos = ComputeGrabScreenPos(o.pos);
    o.color = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    // Color constants
    half4 gold = half4(0.529, 0.365, 0.184, 1);

    rippleClip(i.scrPos);

    float2 textCoord = floor(i.scrPos*_screenSize) / _screenSize;
    textCoord -= _spriteRect.xy;
    textCoord /= _spriteRect.zw - _spriteRect.xy;
    half4 levelCol = tex2D(_LevelTex, textCoord);

    // Get terrain details
    half levelDepth = (((int)round(levelCol.x * 255)-1) % 30)/30.0;
    if(levelCol.x == 1 && levelCol.y == 1 && levelCol.z == 1) levelDepth = 100;
    if (levelDepth > 6.0 / 30.0) {
        half4 grabCol = tex2D(_GrabTexture, i.grabPos);
        if (grabCol.x > 1.0/255.0 || grabCol.y != 0.0 || grabCol.z != 0.0)
            levelDepth = 6.0 / 30.0;
    }

    // Params
    float haloSize = 0.2;
    float zDepth = 8.0 / 30.0;
    float zRad = 8.0 / 30.0;

    float brightness = 0.0;
    float3 pos;
    pos.xy = i.offset * (1.0 + haloSize);
    pos.z = sqrt(1.0 - pos.x * pos.x - pos.y * pos.y);
    
    if (pos.z > 0) {
        // Sphere

        // (-1,-1) to (1,1) representing offset from center of karma glyph
        float2 symbolOffset = normalize(pos.xy) * (acos(pos.z) / PI * 2) * lerp(1.15, 0.7, pow(i.color.g, 3));

        half symbolDist = tex2D(_BigKarmaTex, i.uv + clamp(symbolOffset, -1, 1) / 2.0 / float2(1, 10)).r;

        float frontDepth = pos.z * -zRad + zDepth;
        float backDepth = pos.z * zRad + zDepth;

        clip(levelDepth - frontDepth);

        // Glow near symbol
        float edgeDist = symbolDist * 1.5;

        // Glow near edge of sphere
        edgeDist = min(edgeDist, pow(max(0, 0.95 - dot(pos.xy, pos.xy)) * 1.5, 0.3));

        // Glow where sphere intersects terrain
        if (levelDepth < backDepth){
            edgeDist = min(edgeDist, 0.2 + (backDepth - levelDepth) * 15.0);
            edgeDist = min(edgeDist, 0.2 + (levelDepth - frontDepth) * 15.0);
        }

        brightness = 0.15;
        brightness += max(0, 1 - pow(edgeDist, 0.75));
        brightness *= lerp(1, 0.6, pos.z * (1 - i.color.g));
    } else {
        // Halo
        clip(levelDepth - zDepth);
        brightness = pow(max(0, 1 - (length(pos.xy) - 1.0) / haloSize), 5);
    }

    brightness -= tex2D(_NoiseTex, i.offset * 0.4 + _RAIN * float2(0.6, 1.0)).x * (1 - pow(i.color.a * 2 - 1, 2));
    brightness *= i.color.a;
    return saturate(gold * brightness * (1 + pow(i.color.g, 5)));
}

ENDCG
            }
        }
    }
}