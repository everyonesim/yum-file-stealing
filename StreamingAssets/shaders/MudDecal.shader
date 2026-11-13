Shader "Futile/MudDecal"
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

uniform float _RAIN;
uniform float4 _spriteRect;

uniform float _light;
uniform float4 _lightDirAndPixelSize;
uniform float _fogAmount;
uniform float _waterLevel;
uniform float _WetTerrain;
uniform float _cloudsSpeed;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _LevelTex;
sampler2D _PalTex;
sampler2D _CloudsTex;

uniform float2 _screenSize;

sampler2D _DynamicLevelElements;
sampler2D _OrigLevelTex;
#include "_RippleClip.cginc"
#include "_DynamicLevelClip.cginc"
#include "_Functions.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
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
    float2 textCoord = floor(i.scrPos * _screenSize) / _screenSize;
    textCoord = (textCoord - _spriteRect.xy) / (_spriteRect.zw - _spriteRect.xy);

    dynamicLevelClip(i.scrPos, textCoord);

    float ugh = fmod(fmod(   round(tex2D(_LevelTex, float2(textCoord.x, textCoord.y)).x*255)   , 90)-1, 30)/300.0;
    float displace = tex2D(_NoiseTex, float2((textCoord.x * 1.5) - ugh + (_RAIN*0.01), (textCoord.y*0.25) - ugh + _RAIN * 0.05)   ).x;
    displace = clamp((sin((displace + textCoord.x + textCoord.y + _RAIN*0.1) * 3 * 3.14)-0.95)*20, 0, 1);

    if (_WetTerrain < 0.5 || 1-i.scrPos.y > _waterLevel)
        displace = 0;

    half4 texcol = tex2D(_LevelTex, float2(textCoord.x, textCoord.y + displace * 0.001));

    if (texcol.x == 1.0 && texcol.y == 1.0 && texcol.z == 1.0)
    {
       return half4(0,0,0,0);
    }

    int red = round(texcol.x * 255);
    
    half shadow = tex2D(_NoiseTex, float2((textCoord.x*0.5) + (_RAIN*0.1*_cloudsSpeed) - (0.003*fmod(red, 30.0)),
                                        1-(textCoord.y*0.5) + (_RAIN*0.2*_cloudsSpeed) - (0.003*fmod(red, 30.0))
                                        )).x;
    shadow = 0.5 + sin(fmod(shadow+(_RAIN*0.1*_cloudsSpeed)-textCoord.y, 1)*3.14*2)*0.5;
    shadow = saturate(((shadow - 0.5)*6)+0.5-(_light*4));

    if (red > 90) red -= 90;
    else  shadow = 1.0;

    int paletteColor = clamp(floor((red-1)/30.0), 0, 2);//some distant objects want to get palette color 3, so we clamp it

    red = fmod(red-1, 30.0);

    if (shadow != 1 && red >= 5)
    {
        float4 shadowFix =FixEdgeShadowStretch(i.scrPos,true);
        half2 grabPos = half2(i.scrPos.x + -_lightDirAndPixelSize.x * _lightDirAndPixelSize.z * (red-5) * shadowFix.x,
                              i.scrPos.y +  _lightDirAndPixelSize.y * _lightDirAndPixelSize.w * (red-5) * shadowFix.y);
        grabPos = lerp(grabPos,((grabPos-half2(0.5, 0.3))*(1 + (red-5.0)/460.0))+half2(0.5, 0.3),shadowFix.zw);
        float4 grabTexCol2 = tex2D(_GrabTexture, grabPos);
        if (grabTexCol2.x != 0.0 || grabTexCol2.y != 0.0 || grabTexCol2.z != 0.0)
        {
            shadow = 1;
        }
    }
   
    half4  terrainCol = lerp(tex2D(_PalTex, float2((red)/32.0, (paletteColor + 3 + 0.5)/8.0)), tex2D(_PalTex, float2((red)/32.0, (paletteColor + 0.5)/8.0)), shadow);

    terrainCol = lerp(terrainCol, tex2D(_PalTex, float2(1.5/32.0, 7.5/8.0)), clamp(red*_fogAmount/30.0, 0, 1));
        

    if (red >= 5)
    {
        float4 grabTexCol = tex2D(_GrabTexture, float2(i.scrPos.x, i.scrPos.y));
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            return half4(0,0,0,0);
    }
        
    half lightness = (1.0 - shadow) * (paletteColor != 2 ? 0.2 : 0.9);
    lightness = lightness * 0.5 + min(red / 15.0, 1);
    lightness *= tex2D(_PalTex, float2(30.5 / 32.0, 7.5 / 8.0)).r;
    
    half4 color = tex2D(_MainTex, i.uv) * half4(i.clr.rgb, 1.0);
    half4 black = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));
    half spots = (1 - tex2D(_CloudsTex, textCoord * float2(1400 / 397.0, 800 / 212.0)).r) * 0.5
               + (1 - tex2D(_CloudsTex, textCoord * float2(1400 / 397.0 * 2.3, 800 / 212.0 * 2.3)).r) * 0.5;

    lightness *= pow(length(i.uv * 2 - 1), 0.5);
    color = lerp(black, color, lightness);
    color.w = 1.5 - 1.5 * length(i.uv * 2 - 1) - spots * spots;
    half rounded = round(color.w * 4.0) / 4.0;
    if (rounded < 0.0)
        return half4(0,0,0,0); // would result in a NaN result below
    color.w = saturate(pow(rounded, 0.75));

    #if RIPPLE
    color.w *= 1 - allRippleColorMask(i.scrPos);
    #endif

    return color;
}
ENDCG
            }
        } 
    }
}
