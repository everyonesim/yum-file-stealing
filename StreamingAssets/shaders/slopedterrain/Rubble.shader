Shader "Futile/Rubble" //Unlit Transparent Vertex Colored Additive 
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
#include "TerrainCommon.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

sampler2D _MainTex;
uniform float _fogAmount;


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


// Modified from ColoredSprite2 to use vertex color instead of texture color
half4 frag (v2f i) : SV_Target
{
    float2 rippleParams = GetRippleParams(i.scrPos);

    float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

    textCoord.x -= _spriteRect.x;
    textCoord.y -= _spriteRect.y;

    textCoord.x /= _spriteRect.z - _spriteRect.x;
    textCoord.y /= _spriteRect.w - _spriteRect.y;

    half4 levelcol = tex2D(_LevelTex, textCoord);
    half4 texcol = tex2D(_MainTex, float2(i.uv.x, i.uv.y));

    half dpth = 1.0 - i.clr.w;

    half terrainDpth = (((int)round(levelcol.x * 255)-1) % 30)/30.0;
    if(levelcol.x == 1 && levelcol.y == 1 && levelcol.z == 1)
        terrainDpth = 1;

    if(terrainDpth > 6.0/30.0)
    {
        float4 grabTexCol = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            terrainDpth = 6.0/30.0;
    }

    if(dpth > terrainDpth)
        return float4(0,0,0,0);

    float lightness = 0.3;
    half4 returnCol = lerp(
        LevelPalette(lerp(0.5, 29.5, dpth)/32.0, (lerp(0.5, 2.5, i.clr.z))/8.0, rippleParams),
        LevelPalette(lerp(0.5, 29.5, dpth)/32.0, (lerp(0.5, 2.5, i.clr.z) + 3.0)/8.0, rippleParams),
        lightness);

    returnCol = lerp(returnCol, LevelPalette(1.5/32.0, 7.5/8.0, rippleParams), dpth*_fogAmount * 0.85 + 0.15);
 
    return float4(clamp(returnCol.xyz,0.003921568627451,1), texcol.w);
}
ENDCG

			}
		} 
	}
}
