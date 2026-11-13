Shader "Futile/AetherRainbowMinimalGrain" 
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
				GrabPass { }
				Pass 
			{
            Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"

sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _PalTex;
sampler2D _MainTex;
float4 _spriteRect;
float4 _MainTex_ST;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

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
    return o;
}

float ease(float v){
    return v*(2-v);
}

float mirror(float v){
    return 1-abs(1-mod(v,2));
}
float2 mirror(float2 v){
    return float2(mirror(v.x),mirror(v.y));
}

half4 frag (v2f i) : SV_Target
{
    i.uv.y +=.5;
    fixed fade =  ease(i.clr.w);
    fade *= smoothstep(1,.9,abs(i.uv.x*2-1));

    float blend = smoothstep(0,.5,mirror(i.uv.y-.5)*2-1+.2);
    float2 muv = float2(i.uv.y,i.uv.y+1);
    muv = mirror(muv);
    muv = clamp(muv,.01,.99);

    half4 col = lerp(tex2D(_MainTex, float2(.5,muv.x)),
                     tex2D(_MainTex, float2(.5,muv.y)),
                     blend);

	float n = 0.5 + 0.5 * sin((tex2D(_NoiseTex2, half2(i.texCoord.x*30, i.texCoord.y*15 + _RAIN*0.03)).x * 3 
                             + tex2D(_NoiseTex,  half2(i.texCoord.x*4,  i.texCoord.y*2 + _RAIN*0.01)).x
                              )*6.28*2.5);
    n = n * 3 - floor(n*3);
	n = 0.9 + n * 0.1;
	
    float specks = n;
    specks = n-specks;

    n=saturate(n*fade);
    col.w *= n;

    fixed creatures = tex2D(_PreLevelColorGrab, i.scrPos.xy) != (fixed4)0;

    fixed depth = get_depth_sat(tex2D(_LevelTex, i.texCoord).x);
    depth = lerp(depth,min(depth,creatures*6),creatures);
    fixed tDepth = i.clr.y*42;
    col.w *= saturate(iLerp(clamp(-6+tDepth,-1,29),clamp(tDepth,0,30),depth));
    col.w+=specks*i.clr.x;

    half4 grabCol = tex2D(_GrabTexture, i.scrPos.xy);
    half4 result = half4(1.0 - (1.0-grabCol.x) * (1.0-col.x*col.w),
                 1.0 - (1.0-grabCol.y) * (1.0-col.y*col.w),
                 1.0 - (1.0-grabCol.z) * (1.0-col.z*col.w),
                 fade);
    smoothRippleClip(result,i.scrPos);
    return result;
}

ENDCG
}

		} 
	}
}