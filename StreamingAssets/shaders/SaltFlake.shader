Shader "Futile/SaltFlake" 
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
            Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile_local _ shadow
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _LevelTex;
sampler2D _NoiseTex;
sampler2D _PalTex;
float4 _spriteRect;
float4 _MainTex_ST;

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
    float2 texCoord : TEXCOORD3;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    o.clr.x = DecodeFloatRG(o.clr.xy);
    return o;
}

float shape(float2 uv, float scale, float offset){
    float2 suv = abs(abs(uv*1.2)+scale*0.5-.65);
    return min(1-suv.x,(1-suv.y));
}

float3 flake(float2 cuv, inout float s,float t)
{
    float shp = shape(cuv,s,t);
    float flk = smoothstep(.88-s*s*.01,.94-s*s*.01,shp);
    s+=.1+sin((s+t)*1111)*.05;
    return float3(flk,step(.999999,flk), fmod(s*911,1));
}

void growFlake(float2 cuv,inout float s,inout float3 f, float t){

    float2 offset = float2(sin((s+t)*9190),cos((s+t)*1999))*.09;
    float2 scale = 1-float2(sin((s+t)*3130),cos((s+t)*4979))*.14;
    float3 flk = flake((cuv+offset)*scale,s,t);
    f = lerp(f,flk*.25+ fmod(s*.25,1),step(0.1,flk.x));
    return;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    if (i.clr.w == 0 && get_depth_sat(tex2D(_LevelTex,i.texCoord).x) < 30)
    discard;

    float2 uv = i.uv;
    float2 cuv = uv*2-1;
    float t = i.clr.x*11111;
    float nt =  fmod(t*.03,1);
    float tinyNoise = tex2D(_NoiseTex,uv*1.66666+nt).x;

    float noise = tex2D(_NoiseTex,uv*.22+nt).x;
    float noise1 = tex2D(_NoiseTex,uv*.10+nt+float2(.91,.14)).x;
    float2 bigFlakeUV = cuv*(1.2+nt*.2) + normalize(cuv)*step(.5,noise1)*.2;
    float bigFlake = min( 1-abs(bigFlakeUV.x),1-abs(bigFlakeUV.y));
    float bfwave =abs(sin(saturate(bigFlake)*20));
    bfwave *= step((1-bigFlake)*.5+tinyNoise*.2,noise);
    bfwave = bfwave*=tinyNoise;
#if shadow
    fixed fm = step(0.1,bfwave);
    return fixed4(fm*(1.0/255.0),0,0,fm);
#else
    float s = 0.008;
    float3 shape = 0;
    for(int j = 0;j<12;j++)
        growFlake(cuv,s,shape,t);
    s=48.89;
    growFlake(cuv,s,shape,t);
    float shine = smoothstep(.88,1.,sin((shape.z*10+shape.x*2-4.4)*step(.001,shape.x)-(_RAIN+i.clr.x)*6+uv.y*1+uv.x*2+noise1*4));

    float3 sky = tex2D(_PalTex,float2(20/32.0, 5/8.0) );
    float3 cd = lerp(tex2D(_PalTex,float2(10.0/32.0, 7/8.0) ).xyz,sky,.75);
    float3 cl = lerp(tex2D(_PalTex,float2(1.5/32.0, 7.5/8.0) ),1,.5);
    float d = saturate(distance(cd,cl)*4);
    cd = lerp(cd*.125,cd,d);

    fixed grey = lerp(0,.7,step(.7,smoothstep(0.0,0.55,bfwave))*bigFlake);
    grey = lerp(grey,saturate(iLerp(0,0.7,shape.x)*1.3),step(.001,shape.x));
    grey =lerp(float(grey).xxx,cl*1.9+.3,shine*step(0.01,grey));

    return fixed4(lerp(cd,cl,grey),step(0.001, grey));
#endif

}

ENDCG
}

		} 
	}
}

