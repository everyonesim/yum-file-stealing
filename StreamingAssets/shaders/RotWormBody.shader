Shader "Futile/RotWormBody"
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

    o.uv.x = o.uv.x * 2.0 - 1.0; // Range from -1 to 1
    o.uv.y *= 80.0;
    
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float2 textCoord = floor(i.scrPos*_screenSize)/_screenSize;
    textCoord.xy -= _spriteRect.xy;
    textCoord.xy /= (_spriteRect.zw - _spriteRect.xy);
    
    BackgroundClip(_LevelTex, _GrabTexture, textCoord, i.scrPos);

    // Segmentation
    float width = 1.0 - 0.2 * pow(abs(i.uv.y % 2.0 - 1.0), 10.0);
    width *= lerp(1.0, tex2D(_NoiseTex, float2(sign(i.uv.x) * 0.25, i.uv.y * 0.5)).r, i.uv.y / 320.0 + 0.1);
    if (abs(i.uv.x) > width) return half4(0,0,0,0);

    half4 tex = tex2D(_MainTex, i.uv * float2(0.5, 0.5) + float2(0.5, 0.0));
    half4 sky = half4(0,0,0,1);//tex2D(_PalTex, float2(0.5 / 32.0, 7.5 / 8.0));
    //half4 black = tex2D(_PalTex, float2(2.5 / 32.0, 7.5 / 8.0));
    half4 skin = half4(0.06,0.055,0.06,1.0);
    half4 blue = half4(0.185,0.055,0.416,1);

    float z = sqrt(1.0 - (i.uv.x / width) * (i.uv.x / width));
    
    float rFac = lerp(tex.r, 0.5, min(1, tex2D(_NoiseTex, i.uv * 0.1).r * 1.0)) * z * (1.0 - i.uv.y / 80.0) * 1.5;
    rFac = saturate(round(rFac * 10.0) / 10.0);

    float gFac = tex.g * (tex2D(_NoiseTex, float2(i.uv.x * 0.75 + i.uv.y * 0.025, i.uv.y * 0.15)).r * 3.0 - 1.5);

    if(gFac > 0.35) return blue;
    return lerp(sky, skin, rFac);
}
ENDCG
            }
        } 
    }
}