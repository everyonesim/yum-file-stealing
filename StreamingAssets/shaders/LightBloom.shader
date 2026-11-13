// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// This Edit adds a shader variant that enables proper interaction with snow
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance


Shader "Futile/LightBloom" //Unlit Transparent Vertex Colored Additive 
{
Properties 
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category 
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        //Alphatest Greater 0
        Blend SrcAlpha OneMinusSrcAlpha 
        Fog { Color(0,0,0,0) }
        Lighting Off
        Cull Off //we can turn backface culling off because we know nothing will be facing backwards

        BindChannels 
        {
            Bind "Vertex", vertex
            Bind "texcoord", texcoord 
            Bind "Color", color 
        }

        SubShader   
        {
        GrabPass { }
        
                Pass 
            {
                //SetTexture [_MainTex] 
                //{
                //	Combine texture * primary
                //}
                
                
                
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Snow.cginc"
#include "_TerrainMask.cginc"
#include "_CreatureMask.cginc"
#include "_UrbanLife.cginc"
#include "_Functions.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
//sampler2D _PalTex;
//uniform float _fogAmount;
//uniform float _waterPosition;

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

bool IsLevelLit(float2 textCoord, float2 scrPos)
{
    half4 col = tex2D(_LevelTex, textCoord);
    col = AddSnow(col, textCoord,scrPos);
    col = AddTerrain(col, textCoord, _spriteRect);

    int red = round(col.x * 255);
#if URBANLIFE
    if (red > 90 && red != 255) 
        red -= 90*UrbanLifeShadows(scrPos,get_depth(col));
#endif
    return red > 90 && red < 255 && CreatureMask(red, scrPos);
}

half4 frag (v2f i) : SV_Target
{
    float2 textCoord = i.scrPos;//float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

    textCoord.x -= _spriteRect.x;
    textCoord.y -= _spriteRect.y;

    textCoord.x /= _spriteRect.z - _spriteRect.x;
    textCoord.y /= _spriteRect.w - _spriteRect.y;

    //half4 texcol = tex2D(_LevelTex, textCoord);

    half2 screenPos = half2(i.scrPos.x, i.scrPos.y);

    half4 texcol = half4(0,0,0,1);
    float div = 0.0;
    float coef=1.0;
    float fI = 0;
    float _BlurAmount = 0.0012;// * i.clr.w;
    float horFac = _screenSize.y / _screenSize.x;
    
    half red = 0;
    half2 snow = 0;
    half mask = 0;

#if defined(SHADER_API_SWITCH)
    const int loopInc = 2;

    for (int j = 0; j < 4; j += loopInc) {
        fI++;
        coef = pow(0.82, j + 1);
#else
    for (int j = 0; j < 4; j++) {
        fI++;
        coef*=0.82;
#endif

     if (IsLevelLit(float2(textCoord.x, textCoord.y + fI * _BlurAmount), i.scrPos))
        texcol += tex2D(_GrabTexture, float2(screenPos.x, screenPos.y + fI * _BlurAmount)) * coef;
        
     if (IsLevelLit(float2(textCoord.x - fI * _BlurAmount * horFac, textCoord.y), i.scrPos))
        texcol += tex2D(_GrabTexture, float2(screenPos.x - fI * _BlurAmount * horFac, screenPos.y)) * coef;
        
     if (IsLevelLit(float2(textCoord.x + fI * _BlurAmount * horFac, textCoord.y), i.scrPos))
        texcol += tex2D(_GrabTexture, float2(screenPos.x + fI * _BlurAmount * horFac, screenPos.y)) * coef;
        
     if (IsLevelLit(float2(textCoord.x, textCoord.y - fI * _BlurAmount), i.scrPos))
        texcol += tex2D(_GrabTexture, float2(screenPos.x, screenPos.y - fI * _BlurAmount)) * coef;
        
        div += 4*coef;
    }

    //if(tex2D(_LevelTex, float2(textCoord.x, textCoord.y - 0.1)).x * 255 < 90)
    //return half4(1, 0, 0, 1);
 
    // texcol = half4(max(texcol.x - 0.25, 0), max(texcol.y - 0.25, 0), max(texcol.z - 0.25, 0), 0);
 
    half4 grabCol= tex2D(_GrabTexture, float2(screenPos.x, screenPos.y));
 
    div *= 0.5;
 
    texcol = grabCol + (texcol / div)*i.clr.w;

    return texcol;
}
ENDCG
                
                
                
            }
        } 
    }
}
