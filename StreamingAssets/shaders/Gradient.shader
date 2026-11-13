Shader "Futile/Gradient"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
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
float4 _MainTex_ST;
float2 _MainTex_TexelSize;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    return fixed4(i.clr.xyz,i.uv.y*i.clr.w);
}
            ENDCG
		}
    }
}
