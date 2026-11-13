Shader "Futile/RotWormFin"
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
#include "_TerrainMask.cginc"

sampler2D _MainTex;
sampler2D _PalTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;
uniform float4 _spriteRect;
uniform float2 _screenSize;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

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
    // Discard pixels behind objects or terrain
    float2 textCoord = floor(i.scrPos*_screenSize)/_screenSize;
    textCoord.xy -= _spriteRect.xy;
    textCoord.xy /= (_spriteRect.zw - _spriteRect.xy);
    
    BackgroundClip(_LevelTex, _GrabTexture, textCoord, i.scrPos);

    half4 tex = tex2D(_MainTex, float2(i.uv.x * (1.02 - i.uv.y) * 0.5, i.uv.y * 2.0));
    half4 sky = half4(0,0,0,1);//tex2D(_PalTex, float2(0.5 / 32.0, 7.5 / 8.0));
    half4 skin = half4(0.06,0.055,0.06,1.0);
    half4 blue = half4(0.185,0.055,0.416,1);

    half lowerEdgeNoise = tex2D(_NoiseTex, i.uv.y * float2(8.0, 0.2)).r;
    half upperEdgeNoise = tex2D(_NoiseTex, i.uv.y * float2(2.0, 0.1) + float2(0.5, 0.5)).r;
    half blobNoise = tex2D(_NoiseTex, i.uv.y * float2(2.2, 28.0)).r;
    if (i.uv.x < lowerEdgeNoise * 0.4)
    {
        return i.uv.x > blobNoise * 0.2 ? blue : half4(0,0,0,0);
    }

    if (i.uv.x > 1.0 - upperEdgeNoise * 0.2)
        return half4(0,0,0,0);

    float rFac = i.uv.x * (1 - i.uv.x) * i.uv.y * (1 - i.uv.y) * 16.0 * tex.r * 0.7;
    rFac = saturate(round(rFac * 10.0) / 10.0);

    return lerp(sky, skin, rFac);
}
ENDCG
            }
        } 
    }
}