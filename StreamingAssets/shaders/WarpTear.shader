Shader "Futile/WarpTear" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
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
            GrabPass {}
            Pass 
			{
            Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma multi_compile _ RoomHasWater
#pragma multi_compile_local _ bad outer
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"
#include "_TerrainMask.cginc"

sampler2D _LevelTex;
sampler2D _PreLevelColorGrab;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _MainTex;
sampler2D _WarpTearGrab;
sampler2D _UniNoise;
uniform float2 _screenSize;
float4 _spriteRect;
float4 _MainTex_ST;
float _waterLevel;
int _warpTearIgnoreCreatures;

#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif

uniform float _RAIN;

struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float2 scrPos : TEXCOORD1;
    float2  cuv : TEXCOORD4;
    float4 clr : COLOR;
    float2 texCoord : TEXCOORD3;
};

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.cuv = o.uv*2-1;
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

fixed get_pal(fixed red){
    red*=255;
    if (red >90)
        red-=90;
    return red/255/.3;
}

fixed grey(fixed3 a){
    return max(a.x,max(a.y,a.z));
}


half4 frag (v2f i) : SV_Target
{
    float fade = smoothstep(0,1, i.clr.z);
    if (fade == 0) discard;
    float dist = length(i.cuv);
    if (dist >= 1) discard;

    float waterMap = 0;
#if RoomHasWater
        waterMap = smoothstep(_waterLevel,_waterLevel+.3,1-i.scrPos.y);
#endif

    fixed3 gold =fixed3(1,.6,0);
    fixed3 rippleGold = fixed3(0.355, 0.31, 0.87);
    float rippleMask = allRippleColorMask(i.scrPos);
    fixed4 weaverCol = fixed4(lerp(gold,rippleGold,rippleMask),1);
    #if !ripple_other_side 
    rippleMask = 1-rippleMask;
    #endif
    rippleMask = smoothstep(0.2,.5,rippleMask);
    fixed4 creatures;
    if (_warpTearIgnoreCreatures) {
        creatures = 0.0;
    } else {
        creatures = tex2D(_PreLevelColorGrab,i.scrPos);
    }
    fixed critMask = creatures != 0;
    fixed4 levelTex= tex2D(_LevelTex,i.texCoord);
    levelTex = AddTerrain(levelTex, i.texCoord, _spriteRect);
    float2 dir = normalize(i.cuv);
    float depth = get_depth_sat(levelTex.x);
    float depth01 =depth*0.0333333333; 
    float pal = get_pal(levelTex.x);
    fixed sky = depth == 30;
    critMask = saturate(critMask-(step(depth,5)));
    fixed weaverBlock = i.clr.y*fade;
    float branchBlock = weaverBlock;
    float riftOpen = i.clr.x*fade;
    riftOpen += 0.00001;
    riftOpen = smoothstep(0,1,riftOpen);
    float weaverCompleteBlock = smoothstep(0.8,1,weaverBlock);
    float weaverCompleteGold = smoothstep(0.7,0.9,weaverBlock);
    float time = fmod(_RAIN*0.8,1.7);
    float grain = abs(fmod(tex2D(_UniNoise,i.texCoord*fixed2(6,4)).x+_RAIN*4,1)-.5)*2;
    float noise1 = tex2D(_NoiseTex,i.cuv*2+_RAIN*.1);
    float noise2 = tex2D(_NoiseTex,-i.cuv*1.9+_RAIN*.1*fixed2(1,-1));
    float noise = noise2*noise1;
    float4 tearMap =  tex2D(_WarpTearGrab,i.scrPos+(noise*2-.5)*.06*(1-weaverCompleteGold*.3));
    tearMap *= fade;
    float weaverMask = smoothstep(.14-tearMap.x*.06,0.02-tearMap.x*.06,dist)*weaverBlock*2+smoothstep(0.6,0.00,dist+.6-branchBlock*1)*0.8;
    float goldMask = smoothstep(.7,0.00,dist+.6-branchBlock*1.7)*pulse(tearMap.x,0.01+dist*.5,.3);
    weaverMask+=weaverCompleteBlock;
    riftOpen *= (1-weaverMask);
    float fg = saturate(iLerp(1,5,depth));
    float invFg = 1-fg;
    float sinWave = sin(dist*40-_RAIN*10)*.5+.5 ; 
    float perBranchSin = saturate(sin(dist*7+_RAIN*9+tearMap.z*PI*3)*.5+.5 ); 
    float revSinWave = sin(dist*40+_RAIN*2)*.5+.5 ; 

    float wave_time =  pulse(time,.03,.03,.8);
    float wave_progression =  smoothstep(.3,1,time);
    float ring = pulse(dist*1,wave_progression-.1,0.2,.1); 
    float big_ring = pulse(dist*1,wave_progression-.2,1.4-smoothstep(.3,1.7,time)*1.3,.1)*smoothstep(1.5,1,time); 
    big_ring *= saturate(1-weaverBlock*2);
    ring *= saturate(1-weaverBlock*2);
    float entrance = smoothstep(.12*riftOpen+big_ring*.01-noise*.05*riftOpen,.0+big_ring*.01+noise*.05*riftOpen,saturate(dist*(1+noise*10*(1-riftOpen)))-.01);
    entrance *= saturate(1-weaverBlock*2);
    entrance *=smoothstep(.5,1,riftOpen);
    float dro = dist*.5-riftOpen*.8;
    float bigCrack= smoothstep(saturate(0.5+dro),saturate(.7+dro)+.1,tearMap.x+entrance*riftOpen);
    riftOpen+=big_ring*.2*smoothstep(.75,0.0,dist);
    float chaosMask= smoothstep(saturate(0.65+dro)+.04,
                                saturate(.7+dro)+.07,
                                tearMap.x+(entrance-invFg*(.1-.1*big_ring)*smoothstep(.2,0,weaverBlock))*riftOpen);
    float portalMask = smoothstep(0.01,.2,entrance-noise*.5+bigCrack*saturate(1-dist)*.25);
    portalMask*=riftOpen;

    float2 distortion = dir;

    fixed4 bgPortalCol = fixed4(0,0.2,.7,1);
#if outer
    bgPortalCol = lerp(bgPortalCol,fixed4(0.3,0.35,.3,1),riftOpen);
#elif bad
    bgPortalCol = lerp(bgPortalCol,fixed4(0.2,0.05,.3,1),riftOpen);
#endif
    fixed4 portalCol = bgPortalCol*depth01*(1+grain*.2);
    portalCol = lerp(portalCol,fixed4(0,0,.7,1)*.1,smoothstep(.11*riftOpen,(0.01+depth01*.08)*riftOpen,dist+tearMap.x*.04));
    portalCol = lerp(portalCol,weaverCol,weaverMask*5+weaverBlock+goldMask*(1+depth01));
    float grainBoost = 0;
#if outer 
    grainBoost = .002f;
#endif
    float4 colNoise = tex2D(_NoiseTex2,
            i.cuv*.02+depth01*fixed2(0,1)*0.007+noise*.01-_RAIN*fixed2(0,.003)
            +(revSinWave+big_ring*0.5)*distortion*saturate(.01-entrance*.01-goldMask*.02)
            +grain*(.0005+grainBoost+invFg*.0005));
    colNoise *=(1-(pal*2-1)*.2);
#if outer
    fixed greyNoise = grey(colNoise);
    colNoise = lerp(colNoise,
                    lerp(greyNoise.xxxx*.125,
                         fixed4(0,.25,0.11,1),
                         smoothstep(0.77,1,greyNoise)),
                    riftOpen);
#elif bad
    colNoise *= fixed4(0.2,0.0,0.4,1);
#else
    colNoise.x *= .7;
    colNoise.y *= .5;
#endif
    colNoise = lerp(colNoise,weaverCol,weaverMask*(2+depth01*2)+goldMask*depth01);
    float4 colNoiseRaw = colNoise;
    fixed playerLayerHighlight = pulse(depth,5,3);
    fixed poleLayer = pulse (depth,4,6.0);
    fixed4 otherSideCol = saturate(iLerp(15,0,depth))*colNoise;
    otherSideCol = lerp(portalCol,otherSideCol,.75);
    otherSideCol = lerp(otherSideCol,0,sky-goldMask);
    otherSideCol = lerp(colNoise,otherSideCol,saturate(fg));
    otherSideCol = lerp(otherSideCol,portalCol,entrance*.7);
    otherSideCol = lerp(otherSideCol,otherSideCol*saturate(.8+big_ring*.2+fg)+colNoise*poleLayer*(.2+big_ring*.2),smoothstep(.75+dist*.1,1+dist*.1,riftOpen));
    otherSideCol = lerp(otherSideCol,weaverCol,weaverCompleteGold);
    float bigDimm=smoothstep(1,0.2,dist+weaverBlock)*(.2+smoothstep(.5,1,riftOpen)*.2);

    distortion = distortion*(ring*(.1-depth*.002)*wave_time*(.1+rippleMask*.9)
                             +(smoothstep(0,1,tearMap.x)*.2*big_ring
                             +smoothstep(0,1,tearMap.y)*.1*sinWave
                             +bigCrack*rippleMask*(.05+revSinWave*.1))*saturate(1-playerLayerHighlight*4)
                             +smoothstep(0,1,tearMap.x)*(smoothstep(0,.35,dist))*weaverMask*.08);

    float cracks =saturate( step((.3-.2*max(big_ring,big_ring))+weaverMask*.7,tearMap.y));
    float tiny =step(0.2+perBranchSin+weaverBlock*.8,tearMap.y);

    fixed4 grab =  tex2D(_GrabTexture,mirror(i.scrPos- distortion*(fg+.1+weaverMask)*fade,_screenSize));
    fixed4 grabNoDist =  tex2D(_GrabTexture,i.scrPos);
    fixed4 recoloredGrab = fixed4(grey(grabNoDist.xyz)*colNoiseRaw.xyz,1);
    fixed4 finalColor = grab;
    fixed4 tinted = fixed4(grey(grab)*rippleGold,1);
    tinted = max(grey(grab)*colNoise,tinted);
    finalColor = lerp(finalColor,tinted,bigDimm*fade);
    finalColor = lerp(finalColor,otherSideCol,max(cracks,tiny));
    finalColor = lerp(finalColor,max(otherSideCol,recoloredGrab),chaosMask);
    finalColor = lerp(finalColor,portalCol,portalMask*saturate(fg+.5)*(1-poleLayer)+smoothstep(.4,0,dist)*chaosMask*.5*fg);
    finalColor = lerp(grab,finalColor,rippleMask);
    finalColor = lerp(finalColor,weaverCol*1.4,(smoothstep(.01,1.,tearMap.y*(.5+invFg*pal))+tearMap.x*.2)
                                                *weaverMask*smoothstep(1.0,-0.2,dist)*1.6);//closed scars
    finalColor = lerp(finalColor,creatures,critMask*chaosMask);
    float alpha = smoothstep(1,0.7,dist);
#if RoomHasWater
    waterMap = lerp(waterMap,0,ring);
    waterMap =  1-waterMap*(1.0-smoothstep(0.1,.5,portalMask)*.2);
    alpha *=waterMap;
#endif
    return fixed4(finalColor.xyz,saturate(alpha));
}

ENDCG
}

		} 
	}
}

