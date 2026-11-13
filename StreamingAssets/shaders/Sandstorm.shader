Shader "Futile/Sandstorm"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        ZWrite Off
        Lighting Off
        Cull Off

        SubShader   
        {
            Pass
            {
                Blend One OneMinusSrcAlpha
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "SlopedTerrain/TerrainCommon.cginc"
#include "_TerrainMask.cginc"

sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex2;
sampler2D _CloudsTex;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _SandstormSurfaceMask;
float4 _SandstormSurfaceMask_TexelSize;
sampler2D _UniNoise;
float4 _sandstormParams; // (scroll X, scroll Y, surface wind amount, _)
float4 _sandstormColor;

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR; // (_, _, _, intensity)
    float2 texCoord : TEXCOORD3;
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

float SampleNoise(float2 uv)
{
    float a = tex2D(_NoiseTex, uv * 0.4);
    float b = tex2D(_NoiseTex, uv * 1.5);
    return a * b * 1.5;
}

half4 frag (v2f i) : SV_Target
{
    // Get level info
    float2 levelPos = ScreenToLevelTex(i.scrPos);
    float2 worldPos = _camInRoomRect.xy / _camInRoomRect.zw * _screenSize + i.scrPos * _screenSize;
    half levelDpth = TerrainAndLevelDepth(_LevelTex, levelPos, _spriteRect) / 30.0;

    if(levelDpth > 6.0/30.0)
    {
        float4 grabTexCol = tex2D(_GrabTexture, i.scrPos);
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            levelDpth = 6.0/30.0;
    }

    // Get palette colors
    half4 dustColor = _sandstormColor;
    half4 blackColor = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));

    float distortion = SampleNoise(float2(worldPos.x / 10000.0, _RAIN * 0.5)) * 0.5;
    distortion += SampleNoise(float2(worldPos.y / 8000.0 + 0.5, _RAIN * 0.35)) * 0.25;

    float2 scroll = _sandstormParams.xy;
    float intensity = i.clr.a;

    // Add surface sandstorms
    if (_sandstormParams.z > 0)
    {
        half mask = tex2D(_SandstormSurfaceMask, worldPos / 20.0 * _SandstormSurfaceMask_TexelSize.xy).a;
        mask = max(mask, tex2D(_SandstormSurfaceMask, (worldPos + float2(0, distortion * 200 - 50)) / 20.0 * _SandstormSurfaceMask_TexelSize.xy).a);
        mask = pow(min(mask * 1.5, 1), 0.8);
        mask *= lerp(0.2, 1, min(levelDpth * 2, 1));

        intensity = lerp(intensity, 1, _sandstormParams.z * mask);
    }

    distortion = lerp(0.5, distortion, intensity);

    // Top layer, light soft noise with a bit of grain
    float2 layerACoord = worldPos + float2(0, distortion * 500) - scroll;
    half layerA = SampleNoise(layerACoord / 256.0 * float2(0.05, 0.3));
    half4 grain = tex2Dlod(_UniNoise, float4(floor(layerACoord) / 256.0, 0, 0));
    layerA *= lerp(grain.r, 1, layerA * 0.9);

    // Bottom layer, darker clouds that move slower
    float2 layerBCoord = worldPos + float2(0, distortion * 400 + 100) - scroll * 0.7;
    half layerB = tex2D(_CloudsTex, layerBCoord / 256.0 * float2(0.05, 0.3)).r;
    layerBCoord = worldPos + float2(0, distortion * 50) - scroll * 0.5;
    layerB = max(layerB, tex2D(_CloudsTex, layerBCoord / 256.0 * float2(0.05, 0.3) + 0.5).r);

    // Background layer, puffs of sand in the sky
    float2 layerCCoord = worldPos - scroll * 0.2;
    half layerC = tex2D(_CloudsTex, layerCCoord / 256.0 * float2(0.2, 0.6)).r;
    layerCCoord = worldPos - scroll * 0.18;
    layerC = max(layerC, tex2D(_CloudsTex, layerCCoord / 256.0 * float2(0.15, 0.3) + 0.5).r);
    layerC *= saturate(tex2D(_NoiseTex, layerCCoord / 256.0 * float2(0.06, 0.15)).r * 4 - 1);
    layerC *= (levelDpth >= 1);

    // Modulate layers based on effect intensity
    layerA = (pow(layerA, 0.8) * 0.25 + 0.75) * pow(intensity, 2);
    layerB = sqrt(max(layerB - max(1 - 2 * intensity, 0), 0));
    layerB *= intensity;
    layerC *= min(max(i.clr.a, _sandstormParams.z) * 3, 1);


    // Apply a gradient to top layer, with added noise for debanding
    half4 col = lerp(dustColor, blackColor, 0.5 * (1 - i.uv.y) + grain.g * 0.02) * layerA;
    col += lerp(dustColor, blackColor, 0.6) * layerB * (1 - col.a);
    col += blackColor * layerC * 0.1 * (1 - col.a);
    
    // Turn terrain and objects into silhouettes
    col += lerp(dustColor, blackColor, pow(saturate(1 - levelDpth), 1.25)) * 0.5 * pow(intensity, 2) * (1 - col.a);

    smoothRippleClipAdditive(col,i.scrPos);

    return col;
}

ENDCG
            }
        }
    }
}
