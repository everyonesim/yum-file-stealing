Shader "Futile/VWEndingShard"
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

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NoiseTex;
float _RAIN;
half4 _AboveCloudsAtmosphereColor;

struct appdata {
    float4 vertex : POSITION;
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR;
    uint index : SV_VertexID;
};

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
    float3 triCoord : TEXCOORD1;
};

v2f vert (appdata v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = v.texcoord;
    o.color = v.color;

    uint i = v.index % 3u;
    o.triCoord = float3(i == 0, i == 1, i == 2);
    
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float cutoff = tex2D(_NoiseTex, i.color.rg * 1.0) * 0.1;
    float bright = tex2D(_NoiseTex, i.color.rg * 2.0 + float2(0.5 - _RAIN * 0.2, _RAIN * 0.2)) * 0.5;
    float edgeDist = min(min(i.triCoord.x, 1.0 - i.triCoord.x * 1.2), min(i.triCoord.y, i.triCoord.z));

    float2 offset = float2(
        tex2D(_NoiseTex, i.triCoord.xy * 0.2).r * 2.0 - 1.0,
        tex2D(_NoiseTex, i.triCoord.xy * 0.2 + 0.5).r * 2.0 - 1.0);
    half4 c = tex2D(_MainTex, i.uv + offset * 0.025);

    half flash = min(abs(i.triCoord.g + i.triCoord.b * 0.2 - i.color.b * 2.0 + 0.6) / 0.6, 1.0);
    c.rgb += 0.2 + smoothstep(0, 1, 1 - flash) * 0.15;

    half3 gold = lerp(half3(0.529, 0.365, 0.184) * 1.5, 1, 0.5);
    if (edgeDist < cutoff) {
        c.rgb = gold;
        c.a *= max(0.0, min(edgeDist / cutoff, 1.0 - 50.0 * (cutoff - edgeDist))) * 0.15;
    } else if (edgeDist < bright) {
        c.rgb += gold * pow(1.0 - (edgeDist - cutoff) / (bright - cutoff), 6.0) * 0.15;
    }
    c.rgb = lerp(_AboveCloudsAtmosphereColor.rgb, c.rgb, i.color.a);
    return c;
}
ENDCG
            }
        } 
    }
}
