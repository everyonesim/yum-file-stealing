Shader "Futile/RippleDepths"
{//this shader is WIP but will probably stay unused
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
float2 _NoiseTex_TexelSize;
sampler2D _LevelTex;
float2 _SlowFollowCreatureScreenPos;
float2 _FollowCreatureScreenPos;
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

float drops(float2 uv) {
    float amount = .25;
    float2 pulsation = float2(sin(_RAIN), cos(_RAIN)) * .08;
    float2 down = float2(0, -_RAIN * .25);
    float wind = tex2D(_NoiseTex, uv * .666 + down).x * .01;
    float noise1 = tex2D(_NoiseTex, uv * .777 + down).x;
    noise1 *= tex2D(_NoiseTex, uv + pulsation).x;
    float noise2 = tex2D(_NoiseTex, uv * .779 + down + float2(0., _NoiseTex_TexelSize.x)).x;
    noise2 *= tex2D(_NoiseTex, uv + pulsation + float2(0., _NoiseTex_TexelSize.x)).x;
    float difference = pulse(noise2 - wind, amount, .2) - pulse(noise1 - wind, amount, .2);
    return difference ;
}

fixed4 frag (v2f i) : SV_Target
{
    float fadeAway=1-i.clr.x;
    float closeEnoughToPlayer = distance(_FollowCreatureScreenPos,_SlowFollowCreatureScreenPos);
    closeEnoughToPlayer = smoothstep(1,0.0,closeEnoughToPlayer);
    fixed drp = saturate(drops(i.texCoord*4));
    float2 playerCentered = (i.scrPos-_SlowFollowCreatureScreenPos)*fixed2(2,1);
    float2 playerDir = normalize(playerCentered);
    float followField = (1-length(playerCentered))*closeEnoughToPlayer;
    float smallPlayerAura = smoothstep(.3,0,length((i.scrPos-_FollowCreatureScreenPos)*fixed2(2,1)));
    fixed4 creatures = tex2D(_PreLevelColorGrab, i.scrPos);
    fixed noCreatures = creatures == 0;
    float levelTex = tex2D(_LevelTex,i.texCoord).x;
    float depth = get_depth01_sat(levelTex.x);
    float foreground = saturate(iLerp(0.04,.0,depth));
    float outline = depth>get_depth_sat(tex2D(_LevelTex,i.texCoord+fixed2(0,.01)).x);
    fixed3 grab = tex2D(_GrabTexture,i.scrPos).xyz;
    fixed light = lightness(grab);
    fixed3 ripple = lerp(_RippleGold.xyz * fixed3(.5,1,1),_RippleColor.xyz,depth);
    fixed movingBrightness = sin(light*PI*8+_RAIN)*.5+.5;
    movingBrightness = movingBrightness*.5+.5;
    movingBrightness +=drp*.5;
    movingBrightness += outline;
    movingBrightness *=noCreatures;
    movingBrightness *= max(followField,(drp*3+1.7)*smallPlayerAura);
    fixed3 result =ripple.xyz*movingBrightness*depth; 
    result = lerp(result,grab*ripple,foreground);
    result = lerp(result,grab,saturate(depth-1+fadeAway*2));
    return fixed4(result,1);
}
ENDCG
		}
    }
}
