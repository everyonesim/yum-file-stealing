Shader "Futile/TemplarCircle"
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
sampler2D _LevelTex;
sampler2D _NoiseTex;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float4 _spriteRect;
uniform float2 _screenSize;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float2 grabPos : TEXCOORD2;

    // (thickness, unused, unused, opacity)
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.grabPos = ComputeGrabScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    // Color constants
    half4 gold = half4(1, 0.73, 0.37, 1);

    rippleClip(i.scrPos);

    // Clip when behind terrain
    float2 textCoord = floor(i.scrPos * _screenSize) / _screenSize;
    textCoord -= _spriteRect.xy;
    textCoord /= _spriteRect.zw - _spriteRect.xy;

    half4 levelCol = tex2D(_LevelTex, textCoord);
    half levelDepth = (((int)round(levelCol.x * 255)-1) % 30) / 30.0;
    if(levelCol.x == 1 && levelCol.y == 1 && levelCol.z == 1)
        levelDepth = 1;

    if(levelDepth > 6.0/30.0)
    {
        float4 grabTexCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            levelDepth = 6.0/30.0;
    }
    clip(levelDepth - 6.0 / 30.0);
    
    // Draw circle
    float thickness = i.clr.x;
    half centerDist = length(i.uv * 2 - 1);
    half ringDist = abs(centerDist - (1 - thickness / 2)) / thickness * 2;
    clip(1 - ringDist);

    return saturate(gold * pow(1 - ringDist, 3) * 1.5) * i.clr.a;
}
ENDCG
            }
        }
    }
}