Shader "Futile/SoftToy"
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
#pragma multi_compile_local _ eye

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
sampler2D _NoiseTex;
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

fixed4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    float len = length(i.uv);
#if eye
    float3 color = lerp(tex2D(_PalTex,float2(1.5/32.0, 7.5/8.0) ),0.5,.5);
    float3 eyePos = float3(sin(i.clr.w*11+_RAIN*.1*i.clr.w)*.75,
                           cos(i.clr.w*9+_RAIN*.11*i.clr.w)*.75,
                           (.3+.1*sin(i.clr.w+_RAIN*.23*i.clr.w)));
    float eyeHole = step(length(i.uv+float2(eyePos.y*.8,-eyePos.x*.8)),.15);
    float eyeShape = strip(i.uv.x+sin(eyePos.y)*pulse(i.uv.y,eyePos.x,1.8),eyePos.z*pulse(i.uv.y,eyePos.x,.7))*step(len,1); 
    fixed3 eyeCol = i.clr.xyz;
    eyeCol = lerp(eyeCol,color,.5);
    eyeCol = lerp(eyeCol,eyeCol.zxy*.5,eyeHole);
    return fixed4(eyeCol*(.75+len*.25),eyeShape);
#endif
    float angle = atan2(i.uv.x,i.uv.y);
    fixed noise = tex2D(_NoiseTex,fixed2(angle*.30+_RAIN*sin(i.clr.w*11)*.01,len*.1+i.clr.w*1.3)).x;
    return fixed4(i.clr.xyz*(.5+noise*smoothstep(0.3,1,len)*.7),step(len+noise*.67,1));
}
ENDCG
		}
    }
}
