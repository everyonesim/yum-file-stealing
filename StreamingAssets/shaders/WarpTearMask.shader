Shader "Futile/WarpTearMask"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags { "Queue" = "Geometry"}
		// Blend SrcAlpha OneMinusSrcAlpha 
		Blend One One 
		ZWrite Off
		//Alphatest Greater 0
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

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float2 texCoord : TEXCOORD2;
    float4 pos : SV_POSITION;
    float4 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};
float _RAIN;
sampler2D _NoiseTex2;
sampler2D _LevelTex;
float2 _MainTex_TexelSize;
float4 _MainTex_ST;
float4 _spriteRect;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
    o.clr = v.color;
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    fixed sDepth = get_depth01_sat(tex2D(_LevelTex,i.texCoord).x);

    float riftOpen = i.clr.y;
    riftOpen = smoothstep(0,1,i.clr.y);
    float2 absUV = abs(i.uv);
    float riftOpening = saturate(pulse(riftOpen,.5,.5)*2);
    float noise = tex2D(_NoiseTex2,float2(absUV.x+_RAIN*.5,i.uv.y+i.clr.z)*.1).x;
    noise += tex2D(_NoiseTex2,float2(absUV.x-_RAIN*.25,i.uv.y)*.6).y;
    noise *=.5;
    fixed thinLine = iLerp(.1,.0,absUV.x);
    fixed edge = smoothstep(1,.27,absUV.y);
    fixed sideFade = smoothstep(1,.5,absUV.x);
    fixed distortionField = saturate(iLerp( 1, .0+noise*.3,absUV.x+noise*.4))
                            -sin(i.uv.y*10+_RAIN*10+i.clr.x*13)*.05
                            -sin(i.uv.y*8+_RAIN*12+i.clr.x*11)*.07;
    fixed distEdge = saturate(smoothstep(0.99,0.27,absUV.y));
    float offset = 1.9;
    float sinMix =max(sin(i.uv.y*2+i.clr.z*13),sin(i.uv.y*2.5+i.clr.z*11));
    float open = smoothstep(0,1,abs(i.uv.x*(2-1.9*smoothstep(0,1,saturate(riftOpen*1.2-0.3)))));
    float strandThinness = .8*smoothstep(0,1,saturate(riftOpen*8-.9));
    float tearVisibility = saturate(smoothstep(1,.8,riftOpen));
    float strands = pulse(sinMix,1,open*4+.9-strandThinness)*tearVisibility;
    distortionField*=sideFade;
    thinLine*=saturate(1-strands*riftOpening);
    return fixed4((distortionField*(1-strands))*distEdge*.2,thinLine*edge*.3,smoothstep(.5,.1,absUV.x)*i.clr.x*distEdge,0);
}
ENDCG
}
}
}
