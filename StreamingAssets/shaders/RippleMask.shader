Shader "Futile/RippleMask"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags { "Queue" = "Geometry"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite Off
		//Alphatest Greater 0
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
            #pragma multi_compile_local _ tear waves ring bubble
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
            #include "_Functions.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
                float2 nuv : TEXCOORD2;
                float2 nuv2 : TEXCOORD3;
                float2 nuv3 : TEXCOORD4;
				float4 clr : COLOR;
                float2 texCoord : TEXCOORD5;
                fixed4 flags : TEXCOORD6;
			};
			float _RAIN;
			sampler2D _NoiseTex;
            uniform float2 _screenOffset;
			sampler2D _RippleLevelTex;
			sampler2D _LevelTex;
            sampler2D _RippleMaskSaved;
            sampler2D _UniNoise;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float2 _screenSize;
			float4 _spriteRect;

            float annoyingRings(float2 uv, float scale, float t){
                uv*=4*scale;
                t*=2;
                float len = length(uv);
                float circle = length(uv+circularMotion(t+(len-fmod(len,.31415))*t)*.06);
                float rings = abs(sin(circle*10));
                rings = smoothstep(0.6,1.,rings);
                return rings;
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
                o.scrPos = ComputeScreenPos(o.pos);
                float2 offset =_spriteRect.xy*fixed2(_screenSize.x/_screenSize.y,1); 
                float2 cuv = o.scrPos*fixed2(_screenSize.x/_screenSize.y,1);
                cuv-=offset;
				o.nuv =cuv*5+float2(0,_RAIN*2);
				o.nuv2 = cuv+float2(sin(_RAIN),cos(_RAIN))*.5;
				o.nuv3 = cuv*.5+float2(0,_RAIN*-0.25);
				o.clr = v.color;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
                int a = o.clr.y*255;
                o.flags = fixed4((a&1)>0,(a&2)>0,(a&4)>0,0);
				return o;
			}

            float sineSmooth(float v){
                return saturate(-v*v*(2*v-3));
            }

			fixed4 frag (v2f i) : SV_Target
            {
                fixed shape = i.flags.y;
                fixed intensity = i.clr.x;
                fixed inverted = i.flags.x;
                fixed fallOff = i.clr.z*.99;
                float len = length(i.uv);
#if bubble
                float2 uv = i.uv;
                float sinmask = smoothstep(-.5,.5,i.uv.y); 
                uv.x+=(sin(sinmask*1+_RAIN*50+i.clr.z*11))*.03*sinmask;
                float t = i.clr.x;
                i.clr.y=saturate(i.clr.y);
                i.clr.w = 1-i.clr.w;
                float transp = smoothstep(0.1,.6,t);
                float infl =smoothstep(0,.7,t); 
                float fadeIn = smoothstep(0,.3,t);
                float tension = smoothstep(0.3,.9,t);
                float burst = lerp(0,.6,i.clr.y);
                float infltens = infl*.75+tension*.25;
                float fade = smoothstep(0.5,1,i.clr.y);

                uv.y *= 1+fade*4;
                uv.y += fade*3;
                i.uv.y += fade*2;
                float squish =1+smoothstep(0,-1,i.uv.y)*.5; 

                uv *= 3-infltens*2;
                uv.y +=1-infltens*1; 
                uv *= squish;
                float bblshape = smoothstep(1, .2+.2*fadeIn+infl*.2, length(uv));
                float smoothBurst = smoothstep(0, 1, burst);
                float bblhole = smoothstep( .2+transp*.6+tension*.1+smoothBurst*.3,
                                           -.4+transp*.3+tension*.5+smoothBurst*.6,
                                           length(uv+fixed2(0, (tension*.2-burst*.6+fade*.5))))*transp;
                float bblburst = smoothstep(-.2, 0, length(i.uv-fixed2(0,.55))-burst*3);
                float bbl = max (smoothstep(1, .5, length(uv))*.75*(1-(fade+tension)*.5),bblshape-bblhole)*bblburst*fadeIn;
                bbl *= .75+i.uv.y*.25;

                return fixed4(.1+i.clr.w*.15,i.clr.w*.2,.1,bbl);

#endif
#if ring
                float grit = tex2D(_UniNoise, i.uv);
                fallOff = 1-(1-fallOff)*(1-fallOff);
                intensity -= grit*.005;
                fixed r = pulse(length(i.uv), 0.0+fallOff*.65,.25+fallOff*.1);
                r*=intensity;
                inverted = 1-inverted;
                return fixed4(.3*r,r*.2,inverted*i.flags.z*.5,r);
#endif
#if tear
                fixed depth = get_depth_sat(tex2D(_LevelTex,i.texCoord).x);
                depth = saturate(iLerp(-6,3,depth));
                float rippleTrail = tex2D(_RippleMaskSaved, i.scrPos).y;
                float t= intensity;

                float t1 = sineSmooth(saturate(t*1.8));
                float t2 = sineSmooth(saturate(t*4-1.5));
                float t3 = sineSmooth(saturate(t*3-1.5));

                float rain = _RAIN*(.9+fallOff*.3)+fallOff*111;
                float2 cuv = i.uv;
                //  if (cuv.x>0+sin(rain)) // this is a visualization of an actual portal size
                //  return fixed4(1,0,0,iLerp(.6,.3,length(cuv*float2(1.5,1))));
                fixed edgeFade = smoothstep(.0,.3,(1-abs(cuv.x))*(1-abs(cuv.y)*(1.2+sin(i.uv.x*10+rain*10)*.2)));
                cuv.y+=(sin(i.uv.x*4+rain)*.125
                       +sin(i.uv.x*3+rain*4.7)*.125)
                       *t2*saturate(iLerp(0.2,.5, 1-abs(cuv.x)));
                float ends = pulse(cuv.x,-2+sineSmooth(t2)*2,.9);
                fixed hOffset = tex2D(_NoiseTex,
                                      float2(cuv.x,0)*fixed2(1.2-ends,1.2)+
                                      fixed2(+rain*2.5*sign(cuv.x),+cuv.y*.01+rain*1.1))*2-1;
                hOffset*=(1-ends)*t3;
                cuv.y+=hOffset*.05;
                float t1ends = pulse(cuv.x,-2+t1*2,.9);

                float timeNoise = rain*0.75;
                fixed signY = sign(cuv.y);

                fixed noise= tex2D(_NoiseTex,cuv*fixed2(1.3,0.4)*1.3+fixed2(timeNoise*2.5*signY,0));
                fixed tinyNoise = tex2D(_NoiseTex,cuv*fixed2(1.3,0.4)*4.3+fixed2(timeNoise*2.8*signY,0));
                noise+= tex2D(_NoiseTex,cuv*fixed2(1.5,1)*.75+fixed2(0,+timeNoise*1.5*signY));
                noise+= tex2D(_NoiseTex,cuv*fixed2(.5,.25)-fixed2(timeNoise*signY,0))*3;
                noise= lerp(noise,2,smoothstep(0.3,.0,abs(cuv.y)));
                noise-=tinyNoise;

                float fluctTime = rain*0.9+noise*.05;
                float2 fluctEnds = cuv*2*fixed2(1,.7-ends*.3)*0.5;
                float fluctuations = sin(length(fluctEnds+fixed2(.5,0))*25-fluctTime*18)*.1
                    +sin(length(fluctEnds-fixed2(sin(fluctTime),cos(fluctTime))*.13)*31-fluctTime*30)*.1
                    +sin(length(fluctEnds-fixed2(.5,0))*20+fluctTime*20)*.1+.3;
                fluctuations *=pulse(length(cuv),0.0+t3*.57+(1-ends)*.1,.2+noise*.10);
                fixed strands = tex2D(_NoiseTex,float2(cuv.x*2+cuv.y*.4,abs(cuv.y*(.01+t1*.1))-rain*0.8));
                float r = saturate((noise-2)*.03);
                float rip = pulse(cuv.y,0,t1ends*t1*2)*.1-r;
                rippleTrail = saturate(smoothstep(0,0.1+rippleTrail,rippleTrail))*t1*3*(1-t*.5)*t1ends*rip*10;
                strands = pulse(strands,abs(cuv.y)*.5,.2+t3*2)+.1;
                float bigRip = pulse(cuv.y,0,(.02+noise*(.07+.35*t3)*3.3*t2*(1-abs(cuv.x)))*ends)*.4*strands;
                rip +=bigRip;
                rip -= fluctuations*.6*t3;
                rip += rippleTrail;
                rip *= depth;
                rip = saturate(rip);


                return fixed4(1-inverted,(1-inverted)*i.flags.z,(1-inverted)*i.flags.z*.5,rip*edgeFade);
#endif

                fixed tDepth = get_depth01(tex2D(_RippleLevelTex,i.texCoord).x);
                fixed depth_intensity = abs(i.clr.w*2-1);
                fixed n = tex2D(_NoiseTex,i.nuv)*.3;
                fixed n2 = tex2D(_NoiseTex,i.nuv2)*.8;
                fixed n3 = tex2D(_NoiseTex,i.nuv3)*.8;
                n = -n+n2+n3;
                fallOff+=n*fallOff;
                fixed depth_offset =lerp(tDepth,1-tDepth,step(i.clr.w,.5))*(depth_intensity+n3*depth_intensity); 
                fixed circle =length(i.uv)+depth_offset; 
                circle = iLerp(.99-fallOff,1,circle);
#if waves
                circle += sin(length(i.uv)*40+_RAIN*(sin((intensity+i.clr.z)*1111)*30))*.1*n;
                circle += annoyingRings(i.uv*2-1,.25,_RAIN*(sin((intensity+i.clr.z)*1111)*10))*.1*n;
#endif
                fixed2 p = smoothstep(1-fallOff,1,abs(i.uv));
                fixed square = lerp(max(p.x,p.y),length(p),(p.x*p.y)>0)+depth_offset;
                fixed dist = 1-(shape<.5?circle:square);
                fixed result = dist;
                result*=intensity;
                inverted = 1-inverted;
                return fixed4(inverted,inverted*i.flags.z,inverted*i.flags.z*.5,result);
			}
			ENDCG
		}
	}
}
