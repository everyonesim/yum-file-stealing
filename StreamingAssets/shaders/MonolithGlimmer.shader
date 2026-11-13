Shader "Futile/MonolithGlimmer"
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
    float4 clr : COLOR0;
    float2 scrPos : TEXCOORD1;
    float2 texCoord[3] : TEXCOORD2;
};
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _UniNoise;
float2 _screenSize;
float2 _UniNoise_TexelSize;
float3 _MonolithFogColor;
float _MonolithSceneTime;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float2 _MonolithHorizon;
float _MonolithGlimmerScale;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv -=_MonolithHorizon;
    o.uv.y+=o.uv.x*.01;// small hack to help pixel dots move across the screen more nicely
    o.uv *= _MonolithGlimmerScale;
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.texCoord[0]= o.uv*2*float2(1,_screenSize.y/_screenSize.x);
    o.texCoord[1]= o.uv*float2(1,.75)*.25+float2(0.03,.48);
    o.texCoord[2]= float2(o.uv.x*.75+.2,0);
    return o;
}

half4 frag (v2f i) : SV_Target
{
float dim = smoothstep(5.7f, 9.5, _MonolithSceneTime);
float middle = pow(saturate(iLerp(.4,0,abs(i.uv.y+sin(i.uv.x*16+_RAIN*5)*.006))),2);
float4 smallNoise = tex2D(_UniNoise,i.texCoord[0]);
float2 glimmerGrid = mod(i.texCoord[0]+_UniNoise_TexelSize,_UniNoise_TexelSize*1)/(_UniNoise_TexelSize*1);
float roundGrid = smoothstep(.5,.2,distance(glimmerGrid,.5));
float4 verticalNoise = tex2D(_NoiseTex2,i.texCoord[2]);
float shapes1 = step(verticalNoise.y,.4)*step(.96,middle);
float shapes2 = step(verticalNoise.x,.4)*step(.94,middle);
float shapes3 = step(verticalNoise.z+.2,.5)*step(.91,middle);
float shapes = max(max(shapes1*2,shapes2*1.5),shapes3*1);
float intensity = mirror(fmod(smallNoise.y+_RAIN,1),.5);
float n = tex2D(_NoiseTex,i.texCoord[1]).x;
float strayGlimmer = step(smallNoise.z+n*.02,.01);
n=pulse(n,0.4,.1);
float glimmerStrands = step(smallNoise.x+.09,n*.1);
float middleGlimmer = step(smallNoise.x+.05,middle*.09);
float glimmer = (glimmerStrands*5+middleGlimmer*3+strayGlimmer*1.5)*intensity;
glimmer *=roundGrid;
float3 color = _MonolithFogColor;
color -=middle*.05;
color *=(1-dim*.6);
color +=glimmer*_RippleGold;
color = lerp(color,_MonolithFogColor*(.5-dim),shapes);
    return float4(color,1);
}
            ENDCG
		}
    }
}
