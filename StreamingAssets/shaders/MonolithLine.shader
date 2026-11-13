Shader "Futile/MonolithLine"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
    }
	SubShader
	{
        Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
        Blend One One 
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
};
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
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
    float auvy =abs(i.uv.y-.5);
    i.clr.w = saturate(i.clr.w-.4);
    fixed fadeEnds = smoothstep(.5,.4,auvy);
    fixed awayFromCenter = smoothstep(.5,.0,auvy);
    fixed disconnect = 1-pulse(saturate(auvy-i.clr.w*.7),0,i.clr.w*1);
    fixed noise = tex2D(_NoiseTex2,float2(0,i.uv.y)+float2(0,_RAIN*0.4)).x;
    fixed sparks = step(.9,noise);
    i.uv.x +=sin(i.uv.y*31-_RAIN*40*sign(i.uv.y-.5))*saturate(i.clr.w*(1.3+awayFromCenter*5.0))*saturate(i.clr.w*8);

    fixed ray = pulse(i.uv.x,.5,.08);
    fixed mask = fadeEnds*ray*disconnect*(sin(i.uv.y*10+_RAIN*30)*.3+1.0);
    fixed3 color =i.clr.xyz*mask*(.3-awayFromCenter*.1+i.clr.w*3.95+sparks); 
    return fixed4(color,1);
}
            ENDCG
		}
    }
}
