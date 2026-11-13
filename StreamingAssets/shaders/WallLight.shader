Shader "Futile/WallLight" 
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
#pragma multi_compile_local _ softShadow
#pragma multi_compile_local _ staticNoise
#pragma multi_compile_local _ softEdge
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_Functions.cginc"
#include "_RippleClip.cginc"
#include "_Snow.cginc"

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

sampler2D _LevelTex;
sampler2D _NoiseTex2;
sampler2D _PalTex;
sampler2D _MainTex;
sampler2D _UniNoise;
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
    return o;
}

half4 frag (v2f i) : SV_Target
{
    i.uv.y*=.7+smoothstep(.8,1,i.uv.y)*.3;
    half4 texcol = tex2D(_LevelTex, i.texCoord);
    fixed3 col = i.clr.xyz;
    fixed sparkles = 0;
#if SNOW_ON
    sparkles = texcol.x;
#endif 
    texcol = AddSnow(texcol,i.texCoord,i.scrPos);

    int paletteColor = floor(((int)round(texcol.x * 255) % 90 )/30.0);
    if(texcol.y >= 16.0/255.0) paletteColor = 3;
    
    float fade = 1- (1-pulse(abs(i.uv.x*2-1),1,0.1+i.uv.y*.5))*(1-i.uv.y);

    half dist = get_depth01(texcol.x);
#if SNOW_ON
    sparkles = texcol.x!=sparkles.x;
    sparkles = Sparkles(dist,i.uv,i.texCoord,sparkles*texcol, _UniNoise, _RAIN);
#endif 
    float2 dir = mul(fixed2(1,0),rotate2d((i.clr.w)*PI*2))*2; 
#if softShadow
    fixed uniNoise = tex2D(_UniNoise,i.texCoord*fixed2(2,1)*8+dir).y;
    float2 noiseMovement = 0;
#if !staticNoise
    noiseMovement = dir*_RAIN*.05;
#endif//staticNoise
     uniNoise += tex2D(_UniNoise,i.texCoord*fixed2(2,1)*8-noiseMovement+i.texCoord*3*uniNoise).x;
     uniNoise*=.5;
    float n = (uniNoise*2-1);
    fade +=n*.01;
#endif//softShadow
    float centerDist =fade*.48 ;
    half2 highLightPos = i.texCoord - (dir * 0.003 * pow(centerDist*2, 0.25));
#if softShadow
    centerDist +=uniNoise*(.04+dist*.08)*saturate(i.uv.y);
    dir = mul(fixed2(1,0),rotate2d((i.clr.w+n*(.12+dist*.08)*saturate(i.uv.y))*PI*2))*2; 
#endif//softShadow
    half2 shadowPos = i.texCoord - (dir * pow(centerDist+.5, 1.25) * pow(dist, 2) * 0.1);
    half2 oldShadowPos = i.scrPos.xy - (dir * pow(centerDist+.5, 1.25) * pow(dist, 2) * 0.1);
    centerDist = 1-(1-centerDist  )*saturate(iLerp(-.1,.1,i.uv.y));
	texcol = tex2D(_LevelTex, shadowPos);
    texcol = AddSnow(texcol,shadowPos,i.scrPos);
    half shadowDist = get_depth01(texcol.x);
	texcol = tex2D(_LevelTex, highLightPos);
    texcol = AddSnow(texcol,highLightPos,i.scrPos);
    half highLightDist = get_depth01(texcol.x);

    if (dist > 5.0/30.0){
        half4 grabColor = tex2D(_GrabTexture, i.scrPos);
        if( grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
            return half4(0,0,0,0);
    }

    if (shadowDist > 5.0/30.0){
        half4 grabColor = tex2D(_GrabTexture, oldShadowPos);
        if( grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
            shadowDist = 6.0/30.0;
    }

    float shadow = dist - shadowDist - (paletteColor == 1 ? 0 : 2.0/30.0);
    shadow = pow(clamp(shadow, 0, 1), lerp(1.0-dist, 0.5, 0.5));

    float highLight = 0;
    if(highLightDist > dist + 0.05) highLight = sin(centerDist*3.14*2);

    if(paletteColor == 0){
    half2 sd2Pos = i.texCoord - (dir * 0.01 * centerDist);
    texcol = tex2D(_LevelTex, sd2Pos);
    texcol = AddSnow(texcol,sd2Pos,i.scrPos);
    float sd2 = get_depth01(texcol.x);
    if(sd2 < dist && sd2 > dist - 0.1) shadow = lerp(shadow, 1, pow(centerDist*2.0, 2.5-4.0*centerDist));
    }

    half d = dist;

    if(dist < 0.2) dist = pow(1.0-(dist * 5.0), 0.35);
    else dist = clamp((dist - 0.2) * 1.3, 0, 1);

    dist = 1.0-dist;
    dist *= pow(pow((1-pow(centerDist * 2, 2)), 3.5), lerp(0.5, 3.5, d));


    dist = clamp(lerp(dist, 0, shadow)-shadow*0.3, 0, 1);

    if(paletteColor == 0) dist *= 0.8;
    else if (paletteColor == 2) dist = pow(dist, 0.8);
    else if(paletteColor == 3){
        dist *= 0.2;
        highLight = 0;
    }

    fixed mask = dist * 1 * (0.65 + highLight * 0.35);
    col = col*(1+smoothstep(0.0,1,mask)*1)*mask*2;
#if SNOW_ON
    col*=1+sparkles*4*highLight;
#endif

    half4 result =half4(saturate(col),saturate(mask));
    smoothRippleClipAdditive(result,i.scrPos);
#if softEdge
    result *= pulse(i.uv.x*2-1,0,.8);
#endif
    return result;
}

ENDCG
}

		} 
	}
}

