Shader "Futile/MonolithDetailed"
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
};
sampler2D _MainTex;
sampler2D _NoiseTex;
float3 _MonolithFogColor;
float4 _MainTex_ST;
float _MonolithSceneTime;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
    o.uv *=float2(1.2,1.1);
    o.uv = o.uv*.5+.5;
    o.clr = v.color;
    o.scrPos = ComputeScreenPos(o.pos).xy;
    return o;
}


half4 frag (v2f i) : SV_Target
{
    float dim = smoothstep(5.7f, 8.5, _MonolithSceneTime);
    float2 cuv = i.uv*2-1;
    float2 acuv = abs(cuv);
    fixed4 monolith = tex2D(_MainTex,i.uv);
    fixed fog = i.clr.y*.5;
    fixed shape = monolith.y!=1;
    monolith.y += step(monolith.y,0.004)*.35;
    monolith.y = smoothstep(0.3,.5,monolith.y);
    float noise = tex2D(_NoiseTex,i.uv*fixed2(1,.5)*2+float2(0,-_RAIN+monolith.z*.4+monolith.y*.1+monolith.x*.1));
    monolith.z*=smoothstep(0.0,1,noise);
    shape =saturate(shape + monolith.z*(.8+sin(_RAIN*2)*.2));
    fixed3 gradient = lerp(_RippleGold*1,_GoldRGB*2,i.uv.y*(monolith.x))*(monolith.x+monolith.y);
    fixed3 color = _RippleGold*.25*gradient;
    fixed active  = (monolith.x*shape*.75)*smoothstep(.57,1-i.clr.w*.25,i.uv.y);
    active  += monolith.z*.5*smoothstep(.25,1-i.clr.w*.25,i.uv.y);
    active = saturate(active)*i.clr.w;
    color =lerp(color,_RippleGold.xyz*(1+2*i.clr.w),active);
    color = lerp(color,_MonolithFogColor,fog);
    color *=(1-dim*.9);
    return fixed4(color,shape);
}
            ENDCG
		}
    }
}
