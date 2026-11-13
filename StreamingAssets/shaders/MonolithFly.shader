Shader "Futile/MonolithFly"
{//this shader is WIP but will probably stay unused
Properties
{
    _MainTex ("Texture", 2D) = "white" {}
}
SubShader
{
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
    float2 texCoord[3] : TEXCOORD3;
    float2 timings[3] : TEXCOORD6;
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
sampler2D _CloudsTex;
float2 _NoiseTex_TexelSize;
float4 _spriteRect;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;
float _MonolithSceneTime;
float2 _MonolithHorizon;
float2 _screenSize;
float _RAIN;

float2 scale_from(float2 uv, float2 p, float scale) {
    uv -= p;
    uv *= scale;
    return uv += p;
}

float2 faceCloudCoord(float2 cuv,float variation,float timeOffset){
    float t = _RAIN*6+timeOffset;
    float cloudTime = mod(t,1);
    float cloudStep = (t-cloudTime)*.1+variation;
    float cloudOffset = (1-(cloudTime))*38;
    float v = sin(cloudStep*11+variation);
    float2x2 rotation = rotate2d(-_RAIN*(.8+v*.1)*10+variation*1);
    float offset= _RAIN*.3+cloudStep+v*.77;
    return scale_from(mul(cuv,rotation)+offset,offset,cloudOffset);
}

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos).xy;
    o.clr = v.color;
    float2 cuv = o.uv;
    cuv-=_MonolithHorizon-.5;
    cuv = cuv*2-1;
    cuv *=fixed2(.05,.05*(_screenSize.y/_screenSize.x));
    o.texCoord[0] = faceCloudCoord(cuv,.11,0); 
    o.texCoord[1] = faceCloudCoord(cuv,.22,0.333333); 
    o.texCoord[2] = faceCloudCoord(cuv,.33,0.666666); 
    float openProgression = _MonolithSceneTime+11.36; 
    float vortexGetClose = iLerpClamp(1,4,openProgression);
    float transition = smoothstep(2,3,openProgression);
    float clearSky = iLerpClamp(2.5,3,openProgression);
    float adjustment = smoothstep(2.6,3.5,openProgression);
    float starsFade = smoothstep(3.0,5,openProgression);
    float distortionFade = smoothstep(6,1,openProgression);
    o.timings[0].x=vortexGetClose;
    o.timings[0].y=transition;
    o.timings[1].x = clearSky;
    o.timings[1].y = adjustment;
    o.timings[2].x = starsFade;
    o.timings[2].y = distortionFade;
    return o;
}

float faceCloud(float2 cuv,float l,float variation,float timeOffset, float noise){
    float t = _RAIN*6+timeOffset;
    float len = length(cuv);
    float cloudTime = mod(t,1);
    float cloudStep = (t-cloudTime)*.1+variation;
    float cloudOffset = (1-(cloudTime))*38;
    float v = sin(cloudStep*11+variation);
    cuv *=0.1;
    float visible = iLerpClamp(0,.3,cloudTime)*iLerpClamp(1,len*.5+.5,cloudTime);
    noise = 1-pulse(noise,cloudTime*1+v*.2,.0+visible*.8);
    float cloudPlane = (1-cloudTime*.7+.2+v*.1)*0.5;
    noise =lerp(cloudPlane,cloudPlane+2,noise);
    return noise*clamp(l*.025,0.3,10);
}


fixed4 frag (v2f i) : SV_Target
{
    // _RAIN=3.6;
    i.uv-=_MonolithHorizon-.5;
    float2 cuv = i.uv*2-1;
    cuv *=fixed2(1,(_screenSize.y/_screenSize.x));
    float vortexGetClose = i.timings[0].x;
    float transition = i.timings[0].y;
    float clearSky = i.timings[1].x;
    float adjustment = i.timings[1].y;
    float starsFade = i.timings[2].x;
    float distortionFade = i.timings[2].y;
    float angle1 = atan2(cuv.x,cuv.y);
    float angle2 = atan2(-cuv.x,-cuv.y);
    float p1 = pulse(angle2,0,0.5);
    float p2 = pulse(angle1,0,0.5);
    float len = length(cuv);
    float l = 1/len;
    float noise3 = tex2D(_CloudsTex,float2(angle2+l*.5,l+_RAIN*20)*.125);
    noise3 = lerp(noise3,.43,p2);
    fixed starsChange = step(0.2,transition);
    float starsBoost = _RAIN*9*starsChange;
    float2 starCoord = float2(angle1-l*.1, angle1*2+l*0.2+starsBoost);
    float stars = tex2D(_UniNoise,(starCoord+float2(0,_RAIN*2.4))*(.25+starsChange)).x;
    stars = max(stars,tex2D(_UniNoise,(starCoord+float2(0,_RAIN*0.5))*(.5+starsChange)).y);
    stars = step(0.99,stars*step(l,16-noise3*16-starsFade*20));
    l=1/saturate(len-noise3*vortexGetClose-transition);
    float2 noiseCoord = float2(l*.125-noise3,l*.25+_RAIN*2.5);
    float noise1 = tex2D(_CloudsTex,noiseCoord + float2(angle1*.25,.125));
    float noise2 = tex2D(_CloudsTex,noiseCoord + float2(angle2*.25,0));
    noise1 = lerp(noise1,.5,p1);
    noise2 = lerp(noise2,.5,p2);
    float noise = ((noise1+noise2)*.5+noise3)*.5;
    float shine = pulse(noise,.0,.5);
    float tunnel = noise*2 * l/(noise3*20)-.07;
    fixed final = clamp(tunnel,0,100);
    final -= shine*0.1;
    final += stars*2*(l*.5+1.9)*shine;
    final = min (final,faceCloud(cuv*.5,l,.11,0,tex2D(_NoiseTex,i.texCoord[0])));
    final = min (final,faceCloud(cuv*.5,l,.22,0.333333,tex2D(_NoiseTex,i.texCoord[1])));
    final = min (final,faceCloud(cuv*.5,l,.33,0.666666,tex2D(_NoiseTex,i.texCoord[2])));
    final *= smoothstep(.5,.2,noise3*len+1-iLerpClamp(0,1.5,_MonolithSceneTime+12.36)*2);
    float thresh = transition+l*transition*.1;
    float2 grabDistortion = normalize(cuv)*pulse(noise3,0.2,.4)*smoothstep(lerp(-.1,.2,adjustment),1,len)*lerp(.5,.05,adjustment)*distortionFade;
    fixed3 grab = tex2D(_GrabTexture,i.scrPos-grabDistortion).xyz;
    grab = lerp(grab,_RippleGold.xyz,adjustment*stars*saturate(len));
    grab = lerp(((_RippleGold.xyz)+clamp(grab,.06,1))*3,grab,adjustment);
    grab = lerp(grab,final*_RippleGold.xyz,smoothstep(thresh-.3,thresh,noise));

    return fixed4(grab,1);
}
ENDCG
		}
    }
}
