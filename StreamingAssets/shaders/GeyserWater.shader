Shader "Futile/GeyserWater"
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

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NoiseTex;
sampler2D _LevelTex;
sampler2D _PalTex;
float _RAIN;
float4 _spriteRect;
float2 _screenSize;
float _waterLevel;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;

    // (length factor, seed x, seed y, life)
    float4 color : COLOR;
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

half LevelDepth(float2 screenPos, float2 pixelOffset)
{
    float2 textCoord = floor(screenPos * _screenSize + pixelOffset) / _screenSize;

    textCoord -= _spriteRect.xy;
    textCoord /= _spriteRect.zw - _spriteRect.xy;

    half4 texcol = tex2D(_LevelTex, textCoord);

    half grad = fmod(round(texcol.x * 255)-1, 30.0)/30.0;
    if(texcol.x == 1.0 && texcol.y == 1.0 && texcol.z == 1.0) grad = 1;

    return grad;
}

half4 frag (v2f i) : SV_Target
{
    float t = 1.0 - i.color.a;
    float life = i.color.a;

    float2 uv = i.uv;
    uv.x -= 0.5;
    uv.x *= lerp(1.5 + 0.5 * life, 1.0, pow(uv.y, 0.5)); // Apply a cone shape
    uv.y = pow(uv.y, 1.3);

    float noise = tex2D(_NoiseTex, uv * float2(1.0, i.color.r) + float2(0.0, 1.0 * life * life) + i.color.gb).r;

    // Clip to cone
    float threshold = pow(t, 1.5);

    float2 fadeDist = abs(uv / float2(0.5, 0.75) - float2(0.0, 0.25));
    threshold = lerp(threshold, 1.0, pow(fadeDist.x, 3.0) + pow(fadeDist.y, 3.0));

    // Depth goes before discard so derivatives can still be calculated
    float depth = sqrt(max(0.0, noise - threshold));
    float2 warp = float2(ddx(depth), ddy(depth)) * -100.0;
    if(noise <= threshold) discard;

    // Change behavior underwater
    //if (1.0 - i.scrPos.y > _waterLevel + 102.0 / _screenSize.y) return float4(0.0, 1.0 / 255.0, 0.0, 1.0);

    half grad = LevelDepth(i.scrPos, warp) * 0.75 + (1.0 - depth) * 0.25;
    
    half4 fgColor = tex2D(_PalTex, float2(5.5/32.0, 7.5/8.0));
    half4 bgColor = tex2D(_PalTex, float2(4.5/32.0, 7.5/8.0));
#if RIPPLE
    fixed rippleMask  = allRippleColorMask(i.scrPos);
    fgColor = lerp(fgColor, tex2D(_GameplayRipplePalTex, float2(5.5/32.0, 7.5/8.0)), rippleMask);
    bgColor = lerp(bgColor, tex2D(_GameplayRipplePalTex, float2(4.5/32.0, 7.5/8.0)), rippleMask);
#endif
    return lerp(fgColor, bgColor, grad);
}
ENDCG
            }
        }
    }
}
