Shader "Futile/Monolith"
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

fixed circleShapes(float2 uv){
float circles = length((uv-float2(.5,1.6))*5);
    circles = min(circles, length(uv-float2(.5,1.0))*10);
    circles = min(circles, length(uv-float2(.6,1.25))*20);
    circles = min(circles, length(uv-float2(.38,1.16))*12.5);
    circles = min(circles, length(uv-float2(.5,0.7))*15);
    circles = smoothstep(1,0.90,circles);

return circles;
}

half4 frag (v2f i) : SV_Target
{
    float2 cuv = i.uv*2-1;
    float2 acuv = abs(cuv);
    float hSmooth = smoothstep(1,.6,acuv.x-.06);
    float vSmooth = smoothstep(1,.8,acuv.y-.03);
    float smooth = hSmooth*vSmooth;
    fixed shape = smoothstep(0.05,.15,smooth);
    fixed fog = i.clr.y*.5;
    fixed  topLight = smoothstep(.8+smooth*.1,1,i.uv.y);
    fixed  botLight  = smoothstep(.92+smooth*.08,1,1-i.uv.y);
    fixed3 gradient = lerp(_RippleGold*1,_GoldRGB*2,i.uv.y);
    fixed light =  fixed4(max(topLight,max(botLight,(1-i.uv.y-smooth*.4))),0,0,1);
    fixed3 color = _RippleGold*.25*gradient*(light*.5+.5);
    fixed circles = circleShapes(i.uv*float2(1,2.1));
    float noise = tex2D(_NoiseTex,i.uv*fixed2(1,.5)+float2(0,-_RAIN-smooth*.3));
    fixed glow = smoothstep(1.2,.8,acuv.x)*smoothstep(1.1,.85,acuv.y)*i.clr.w;
    fixed active  = noise*(1-smooth)*smoothstep(0,1-i.clr.w*.5,i.uv.y)*i.clr.w;
    color = lerp(color,lerp(_GoldRGB*.1,_RippleGold*.3,i.clr.w).xyz,circles);
    color =lerp(color,_RippleGold.xyz*(1+3*i.clr.w),active);
    color = lerp(color,_MonolithFogColor.xyz,fog);
    return fixed4(color,max(shape,glow));
}
            ENDCG
		}
    }
}
