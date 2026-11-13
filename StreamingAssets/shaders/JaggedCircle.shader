// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/JaggedCircle" //Unlit Transparent Vertex Colored Additive 
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
		//GrabPass { }
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
#pragma multi_compile _ custom_depth
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#if custom_depth
#include "_TerrainMask.cginc"
#endif

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;
sampler2D _MainTex;
sampler2D _LevelTex;
sampler2D _NoiseTex;
//sampler2D _PalTex;
//uniform float _fogAmount;
uniform float _waterPosition;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;

uniform float4 _spriteRect;
uniform float2 _screenSize;


struct v2f {
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
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



half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);

    half f = 1-min(distance(i.uv.xy, half2(0.5, 0.5))*2, 1);

    half n = tex2D(_NoiseTex, i.uv.xy);

#if custom_depth
    float2 textCoord = floor(i.scrPos * _screenSize) / _screenSize;
    textCoord -= _spriteRect.xy;
    textCoord /= _spriteRect.zw - _spriteRect.xy;
    half levelDepth = TerrainAndLevelDepth(_LevelTex, textCoord, _spriteRect) / 30.0;
    half depth = 1 - i.clr.w;

    if(levelDepth > 6.0/30.0) {
        float4 grabTexCol = tex2D(_GrabTexture, i.scrPos);
        if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0)
            levelDepth = 6.0 / 30.0;
    }
    
    if(depth > levelDepth)
        discard;

    f -= pow(n, f*lerp(10, 200, 0.1));
#else
    f -= pow(n, f*lerp(10, 200, i.clr.w));
#endif


    if(f <= 0)
    return half4(0,0,0,0);


    return half4(i.clr.xyz, 1);
}
ENDCG
				
				
            }
        }
    }
}
