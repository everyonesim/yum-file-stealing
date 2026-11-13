Shader "Futile/UrbanLife" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
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
            // Blend SrcAlpha OneMinusSrcAlpha 
            Blend SrcAlpha One
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_local _ first
#pragma multi_compile_local _ shadow
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _CloudsTex;
sampler2D _UniNoise;
sampler2D _UrbanShadowsGrab;
sampler2D _UrbanShadowsBlurGrab;
sampler2D _PreLevelColorGrab;
float4 _spriteRect;
float3 _UrbanLifeLightColor;
float4 _AUrbanLifeCoord[10];

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
    float2 texCoord : TEXCOORD3;
    float2 windowCoord : TEXCOORD4;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    int index = int(v.color.z*255);
#if shadow
    o.windowCoord = lerp(_AUrbanLifeCoord[index].zx,_AUrbanLifeCoord[index].wy,o.uv);
#else
    o.windowCoord = lerp(_AUrbanLifeCoord[index].zy,_AUrbanLifeCoord[index].wx,o.uv);
#endif
    o.clr = v.color;

    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float intensity = i.clr.y;
#if first
    float clouds = tex2D(_CloudsTex,i.uv*fixed2(.5,0.1)+i.clr.w*PI);
    clouds += tex2D(_CloudsTex,i.uv*fixed2(1.5,-0.8)+i.clr.w*PI*2)*.25;
    intensity = .8*clouds ;
    bool creatures =  tex2D(_PreLevelColorGrab,i.scrPos).xyz != 0;
    if (creatures){
        return 0;
    }
#endif
    fixed startingOpacity = lerp(0,.3,intensity);
    fixed2 fade = fixed2(.5,.1+i.clr.x*.39);
    float dither = abs(fmod(tex2D(_UniNoise,i.texCoord*fixed2(6,4)).x+_RAIN*4,1)-.5)*2;
    fixed edgeFade = smoothstep(fade.x,fade.y,abs(i.uv.x-.5))*smoothstep(fade.x,fade.y,abs(i.uv.y-.5));
    fixed opacity = lerp(0,startingOpacity,i.clr.x); 
    fixed circle = saturate(smoothstep(.2,.5,length(i.uv*2-1+fixed2(fmod(_RAIN*3+sin(_RAIN*10)*.2,3)-1.5,.75))));
    fixed shadows = saturate(1-tex2D(_UrbanShadowsBlurGrab,i.windowCoord).x*1.3);
#if first
    shadows = saturate(shadows + clouds*2);
#endif
    fixed alpha = shadows*edgeFade;
    alpha = clamp(alpha+dither*lerp(.2-opacity*.2,0.02,intensity)*step(0.0001,alpha),0,1);
    return fixed4(_UrbanLifeLightColor,alpha*opacity);
}

ENDCG
}

		} 
	}
}
