Shader "Futile/PearlReaderContent"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
        _IsText ("IsText", Float) = 0
        _CropRect ("CropRect", Vector) = (0.34, 0, 1, 1)
    }
	SubShader
	{
        Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha 
            ZWrite Off
            Lighting Off
            Cull Off 
            BindChannels 
            {
                Bind "Vertex", vertex
                    Bind "texcoord", texcoord 
                    Bind "Color", color 
            }
        Pass
        { 
            CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag		
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 pos : SV_POSITION;
    float4 clr : COLOR0;
    float2 scrPos : TEXCOORD1;
};
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex2;
uniform float4 _lightDirAndPixelSize;
uniform float4 _spriteRect;
uniform float2 _screenSize;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float4 _CropRect;
float _IsText;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    if (i.scrPos.x<_CropRect.x || i.scrPos.x>_CropRect.z || i.scrPos.y<_CropRect.y || i.scrPos.y>_CropRect.w)
        return 0;
    fixed4 t = tex2D(_MainTex,i.uv);
    if (_IsText > 0.5)
        return fixed4(i.clr.xyz,(1-lightness(t))*i.clr.w);
    else
        return fixed4(t.xyz*i.clr.xyz,t.w*i.clr.w);
}
            ENDCG
		}
    }
}
