Shader "Futile/WatcherMorphFin"
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
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
uniform float4 _lightDirAndPixelSize;
uniform float4 _spriteRect;
uniform float2 _screenSize;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
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
rippleClip(i.scrPos);
half n = tex2D(_NoiseTex, half2(i.clr.y, i.uv.y * 9-_RAIN));

float arm =  smoothstep(0.8,.7,i.uv.y)*.8*(1-i.clr.w);
n = saturate(n + 0.1);
n -= pulse(i.uv.x,1.2,1.2+arm);

if(n <= 0) return 0;

fixed d  = 0.5+ pulse(i.uv.x,.1,.1,0.8-(1-n)*.5)*(.45-(1-n)*.3);
d = floor(d*16.0)/16.0;

fixed r = max(0, pow(i.uv.x - n, 0.5) - max(0, (0.1-i.uv.y)*20));

fixed3 col = i.clr.xyz;

if(r > 0.4){
	n = tex2D(_NoiseTex2, half2((i.uv.y + i.uv.x*lerp(0.025, -0.05, i.uv.y))*2, (i.uv.y + i.uv.x*lerp(0.025, -0.05, i.uv.y)) * 20));

	if(n - pow((r-0.5)*2, 0.9) <= 0)
	return half4(0,0,0,0);
	
	col = lerp(col,_GoldRGB.xyz*1.4,i.clr.w);
	
}else if (r > 0.3)
col = lerp(col,_GoldRGB.xyz*(2+d),i.clr.w);

return half4(col, 1);



}
            ENDCG
		}
    }
}
