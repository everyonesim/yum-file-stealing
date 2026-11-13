// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance
Shader "Futile/HoloGrid" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend SrcAlpha OneMinusSrcAlpha 
		Fog { Color(0,0,0,0) }
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
				//SetTexture [_MainTex] 
				//{
				//	Combine texture * primary
				//}
				
				
				
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"

sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex2;
sampler2D _PalTex;
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;
uniform float4 _spriteRect;
uniform float2 _screenSize;
uniform float _waterDepth;
uniform float _hologramThreshold;



struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
    return o;
}

#if defined(SHADER_API_PSSL)
half DepthAtTextCoord(half2 txc, half2 scrPos)
#else
half DepthAtTextCoord(half2 txc, half2 scrPos) : FLOAT
#endif
{
	half4 texcol = tex2D(_LevelTex, txc);
    half d = fmod(round(texcol.x * 255)-1, 30.0)/30.0;
	if(texcol.x == 1.0 && texcol.y == 1.0 && texcol.z == 1.0) d = 1.0;
	if (d > 6.0/30.0){
		half4 grabColor = tex2D(_GrabTexture, half2(scrPos.x, scrPos.y));
			if(grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
				return 6.0/30.0;
	}
	return d;
}


half4 frag (v2f i) : SV_Target
{
float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

textCoord.x -= _spriteRect.x;
textCoord.y -= _spriteRect.y;

textCoord.x /= _spriteRect.z - _spriteRect.x;
textCoord.y /= _spriteRect.w - _spriteRect.y;







float light = 0;

float centerDist = clamp(distance(half2(0.5, 0.5), i.uv)*2 + (1.0-i.clr.w), 0, 1);

half dpth = DepthAtTextCoord(textCoord, i.scrPos);
if(dpth >= 0.999) return half4(0,0,0,0);

i.uv += ((textCoord - half2(0.5, 0.66))*0.4 + (i.uv - half2(0.5, 0.5))*0.4) * dpth;

if(dpth > 0.03 && (floor(i.uv.x * 300) % 20 == 10 || floor(i.uv.y * 300) % 20 == 10))
light = 0.35;


i.scrPos -= normalize(i.uv - half2(i.clr.x, i.clr.y))* lerp(-0.2,(0.2-dpth)*centerDist/ 40.0, i.clr.z);
textCoord -= normalize(i.uv - half2(i.clr.x, i.clr.y))*lerp(-0.2,(0.2-dpth)*centerDist/ 40.0, i.clr.z);

dpth = DepthAtTextCoord(textCoord, i.scrPos);


if((dpth > 3.0/30.0 && dpth < 7.0/30.0) || (dpth > 14.0/30.0 && dpth < 17.0/30.0)|| (dpth > 22.0/30.0 && dpth < 24.0/30.0)){
	if(DepthAtTextCoord(textCoord + half2(-1.0/1400, 0), i.scrPos+ half2(-1.0/_screenSize.x, 0)) > dpth
	 ||DepthAtTextCoord(textCoord + half2(1.0/1400, 0), i.scrPos+ half2(1.0/_screenSize.x, 0)) > dpth
	 ||DepthAtTextCoord(textCoord + half2(0, 1.0/800), i.scrPos+ half2(0, 1.0/_screenSize.y)) > dpth
	 ||DepthAtTextCoord(textCoord + half2(0, -1.0/800), i.scrPos+ half2(0, -1.0/_screenSize.y)) > dpth)
	 light = dpth < 7.0/30.0 ? 1 : 0.35;
	 centerDist = pow(centerDist, 2);
}

half h = tex2D(_NoiseTex2, half2(textCoord.x*4, textCoord.y*8 - _RAIN*10)).x*2;
h -= pow(i.clr.w, 2) * (1.0-pow(centerDist, 2));
if(fmod( round((textCoord.y - _RAIN*0.15) * 400) , 3 ) == 0)
h += lerp(0.6, 0.15, light);// * (1-i.clr.w *light);

if(h > _hologramThreshold*i.clr.w)
return half4(0,0,0,0);

light *= 1.0-centerDist;

return half4(0.87, 0.72, 0.35,light*0.6);

}
ENDCG
				
				
				
			}
		} 
	}
}