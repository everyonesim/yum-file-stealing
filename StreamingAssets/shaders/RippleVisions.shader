Shader "Futile/RippleVisions"
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
GrabPass{}
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
    float2 scrPos : TEXCOORD1;
    float4 clr : COLOR0;
    float2 texCoord : TEXCOORD3;
};
#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _PreLevelColorGrab;
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _UniNoise;
float2 _NoiseTex_TexelSize;
sampler2D _PalTex;
sampler2D _LevelTex;
float2 _SlowFollowCreatureScreenPos;
float2 _FollowCreatureScreenPos;
sampler2D _PearlReaderGrab;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _RAIN;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

float4 divideUV(float2 uv){
    float v = mod(uv.x,.1);
    float vS = uv.x-v;
    v = abs(v/.1-.5)*2;
    uv.y *=1+pulse(v,0,3)*.06;
    float h = mod(uv.y+vS*11.11,.7);
    float hS=uv.y-h;
    h = abs(h/.7-.5)*2;
    return float4(v,h,vS,hS);
}

fixed4 frag (v2f i) : SV_Target
{

    fixed3 gold = fixed3(.8,.5,0);
    fixed3 rippleColor = fixed3(0.03,.05,.4)*2.0;
    fixed3 alternativeColor = fixed3(.1,0.25,.45);
    float2 cuv = i.uv*2-1;
    float4 t = _RAIN*float4(.01,.1,.2,.5);
    float fade = smoothstep(0,1,i.clr.w);
    float lateFade = smoothstep(0.5,1,i.clr.w);
    float len = length(cuv) + (1-fade)*.2;
    float intensity = smoothstep(1,.2,len);
    float noise = (tex2D(_NoiseTex,i.uv+fixed2(t.y,-t.x)+i.clr.xy)*2-1)*.2*len;
    cuv = mul(cuv,rotate2d(i.clr.x*PI*2));
    float angle = atan2(cuv.x+noise,cuv.y-noise);
    float2 radial = float2(abs(angle+PI)*0.1591549431,len);
    float4 n = tex2D(_NoiseTex2,radial*float2(.05,.005)*radial.y+i.clr.xy);
    float playerDist = saturate(1-distance(_SlowFollowCreatureScreenPos,i.scrPos));
    float nearSeam = iLerp(.5,.4,abs(radial.x-.5));
    radial.y-=sin(-t.z+i.clr.x*11+fade*.5)*.30;
    radial.y = mirror(mod(radial.y,2),1);
    radial.x-=cos(t.z+i.clr.y*11+fade*3)*.01*nearSeam;
    radial.x = mirror(mod(radial.x,2),1);
    float4 div = divideUV(radial+n.xy*float2(.03*nearSeam,.2)*.6);
    float2 offset = float2(sin((div.z*2-1)*10+t.w),
                           cos((div.w*2-1)*10+t.w)
                           )*fade;
    float2 textureOffset = offset*.02*intensity;
    float2 scrPosOffset = i.scrPos+textureOffset;
    fixed sparks = step(0.9,tex2D(_NoiseTex2,
                                  float2(angle,
                                         (1-(1-len*.5)*(1-len*.5)*.9)-t.y)*.2).y).x;
    float3 visions = tex2D(_PearlReaderGrab, scrPosOffset).xyz;
    float depth = get_depth_sat(tex2D(_LevelTex,i.texCoord+textureOffset).x);
    fixed3 shatterColor = lerp(rippleColor,
                        alternativeColor,
                        mirror(mod(depth*.02+(offset.x+offset.y)*11,2),1))*(.5+pulse(depth*.3,.2,.2,.8));
    fixed3 grab = tex2D(_GrabTexture,scrPosOffset);
    fixed glowIntensity = saturate(lightness(grab)*2);
    fixed3 creatures = tex2D(_PreLevelColorGrab,scrPosOffset);

    float visionsFade = smoothstep(mod(div.w+div.z+.001,.5),1,i.clr.w);
    fixed3 color = lerp(grab,shatterColor+grab*shatterColor,intensity*lateFade*glowIntensity);//add shatterColors
    // color = grab;
    fixed creatureMask = creatures != 0;
    float webWidth = smoothstep(1,.3,len)*.010*fade*glowIntensity;
    float web = max(pulse(div.x,1,webWidth/len),
                    pulse(div.y,1,webWidth)
                   )*(.5+sparks*4+n.z*.4);
    color = lerp(color, gold*2*glowIntensity, sparks*smoothstep(.4,.0,len)*fade*.5);//add sparks
    color =lerp(color,color*(1+visions)+visions*(.5+shatterColor*4), visionsFade*playerDist*intensity);//add visions
    // if (depth>6 && creatureMask ==1)//bring creatures forward
    //     color = creatures;
    color += gold*glowIntensity*smoothstep(.6,.0,len)*fade*.6*lateFade;//add glow
    color +=web*gold*1.5*glowIntensity;//add web

    return fixed4(color,smoothstep(1,.6,len));
}
ENDCG
		}
    }
}
