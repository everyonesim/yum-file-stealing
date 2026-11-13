Shader "Futile/MonolithSphere"
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
            GrabPass{"_MonolithGrab"}
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
sampler2D _MonolithGrab;
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
float3 _MonolithFogColor;
float2 _SlowFollowCreatureScreenPos;
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
    fixed open = i.clr.w;
    fixed variation = i.clr.x;
    fixed variation2 = variation * 2 - 1;
    fixed fog = i.clr.y;
    float len = length(i.uv*2-1);
    float uv = i.uv;
    float2 cuv = (i.uv*2-1)*1.3;
    float sphereToScreen = smoothstep(0,1,i.clr.z);
    fixed noise2 = tex2D(_NoiseTex,i.uv*.8+_RAIN*.4+variation);
    float sphere = length(cuv);
    float scale =  .2 - pow(sphere,2)*.1 + .2*sphereToScreen;
    float2 sphereCoord = lerp(_SlowFollowCreatureScreenPos-scale,_SlowFollowCreatureScreenPos+scale, i.uv);
    sphereCoord = (sphereCoord - _SlowFollowCreatureScreenPos)*fixed2(0.61,1) + _SlowFollowCreatureScreenPos;
    float2 texCoord = lerp(sphereCoord,i.scrPos,sphereToScreen);
    fixed3 grab = tex2D(_MonolithGrab, texCoord).xyz;
    fixed shape = smoothstep(1.04,.96,sphere);
    fixed lerplen = iLerp(1,0.66,len);
    if (lerplen < 0.0)
        return half4(0,0,0,0); // would result in a NaN result below
    fixed glow = pow(lerplen,1.5)*(.5+open);
    shape = shape+glow;
    grab = lerp(grab, half3(0,0,0), smoothstep(open*2-.03,open*2+.03,noise2+sphere));
    grab += _RippleGold.xyz*smoothstep(0,2,sphere);
    grab = lerp(grab,lerp(grab*1.1,_GoldRGB.xyz*2,open),smoothstep(open*.49+.5,1,sphere));
    grab = lerp(grab,_RippleGold.xyz*(1+sin(variation*111+_RAIN*10)*.5),fog);
    return fixed4(grab,shape);
}
            ENDCG
		}
    }
}
