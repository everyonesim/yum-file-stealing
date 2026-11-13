Shader "Futile/WeaverGlow"
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
        Fog { Color(0,0,0,0) }
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
#pragma multi_compile _ NO_GRAB
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _LevelTex;
sampler2D _NoiseTex;
uniform float _waterPosition;

#if !NO_GRAB
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
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
    float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

    textCoord.x -= _spriteRect.x;
    textCoord.y -= _spriteRect.y;
    textCoord.x /= _spriteRect.z - _spriteRect.x;
    textCoord.y /= _spriteRect.w - _spriteRect.y;

    half4 texcol = tex2D(_LevelTex, textCoord);

    half dist = fmod(round(texcol.x * 255)-1, 30.0)/30.0;
    if(texcol.x == 1.0 && texcol.y == 1.0 && texcol.z == 1.0) dist = 1.0;

    if(dist < 6.0/30.0) return half4(0, 0, 0, 0);

    #if !NO_GRAB
    half4 grabColor = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
    if(grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) return half4(0,0,0,0);
    #endif

    half4 color = i.clr;
    half glow = saturate(i.uv.x * 4 - abs(i.uv.y - 0.5) * 2);

    color.a *= glow;

    return color;
}
ENDCG
                
                
            }
        } 
    }
}
