Shader "Futile/UrbanShadowsBlur"
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Blend One One 
		ZWrite Off
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
				Pass 
			{
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_Snow.cginc"

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

sampler2D _MainTex;
sampler2D _UrbanShadowsGrab;
float4 _spriteRect;
float4 _MainTex_ST;
uniform float2 _screenSize;

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
    float2 texCoord[8] : TEXCOORD3;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    float hp = 1 / _screenSize.x;
    float vp = 1 / _screenSize.y;
    float2 h = float2(hp,vp)*.5;

    o.texCoord[0] = float2(0,vp)+h;
    o.texCoord[1] = float2(-hp,vp)+h;
    o.texCoord[2] = float2(-hp,0)+h;
    o.texCoord[3] = float2(-hp,-vp)+h;
    o.texCoord[4] = float2(0,-vp)+h;
    o.texCoord[5] = float2(hp,-vp)+h;
    o.texCoord[6] = float2(hp,0)+h;
    o.texCoord[7] = float2(hp,vp)+h;
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    float blur = tex2D(_UrbanShadowsGrab,i.scrPos);
    for (int k = 0; k < 8; k++){
        blur += tex2D(_UrbanShadowsGrab, i.scrPos + i.texCoord[k]*1);
        blur += tex2D(_UrbanShadowsGrab, i.scrPos + i.texCoord[k]*2);
        blur += tex2D(_UrbanShadowsGrab, i.scrPos + i.texCoord[k]*3);
    }
    blur /=8*3;
    blur = blur*blur;
    return blur;
}

ENDCG
}

		} 
	}
}

