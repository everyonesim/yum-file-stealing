Shader "Futile/BallToy"
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
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR0;
};

sampler2D _MainTex;
sampler2D _PalTex;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.clr = v.color;
    return o;
}

fixed strip(float v, float w){
   return step(-w, v)*step(v,w);
}

float2 mirror(float2 uv){
    return abs(float2(mod(uv.x,2),mod(uv.y,2))-1);
}

fixed ring(float distance, float rad, float width){
    return step(rad-width,distance)*step(distance,rad+width);
}

fixed hexgrid(float2 uv, float scale, float w){
    uv *= float2(PI*.5,1)*.5;
    uv = mirror(uv*scale); 
    uv = lerp(w.xx*.5, float2(1,1)-w.xx*0.5,uv);
    float a = saturate(iLerp(.3,.7,uv.y));
    return strip(uv.x-a,w);
}

fixed4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float len = length(i.uv);
    fixed3 light = tex2D(_PalTex,float2(20/32.0, 5/8.0) );
    float3 color = i.clr.xyz;
    float highlight1 = smoothstep(1,0,length(i.uv+fixed2(.5,-.5)));
    float highlight2 = smoothstep(1,0,length(i.uv+fixed2(-.5,+.5)));
    float f = smoothstep(0,1,len);
    fixed rotation = i.clr.w;
    rotation *= PI;
    float edgeInfluence = smoothstep(.7,1,len);
    fixed circleMask = step(len,.95);
    fixed ringMask = ring(len,.95,.05);
    float2 uv1 = mul(i.uv+.2,rotate2d(rotation*8))-.2;
    float2 uv2 = mul(i.uv-.2,rotate2d(rotation*8))+.2;
    fixed h1 = hexgrid(uv1+fixed2(.33,.11)+normalize(uv1*2-1)*.1*edgeInfluence,2.5,.2+edgeInfluence*.3);
    fixed h2 = hexgrid(uv2-normalize(uv2*2-1)*.05*edgeInfluence,2.9,.2+edgeInfluence*.1);
    fixed3 col = color*.75+highlight2*.4*light;
    col = lerp(col,color+highlight1*.5*light,saturate(h1+ringMask));
    return fixed4(col,(h1+h2)*circleMask+ringMask);

}
ENDCG
		}
    }
}
