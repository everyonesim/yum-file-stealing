Shader "Futile/BoxWorm"
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
            #include "_TerrainMask.cginc"
            #pragma multi_compile_local _ Body Box OpenBox Larva LarvaFood LarvaHolder FireSpriteWing FireSpriteBody

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
                float time : TEXCOORD2;
                float2 texCoord : TEXCOORD3;
			};
			sampler2D _MainTex;
            sampler2D _PalTex;
            sampler2D _NoiseTex;
            sampler2D _UniNoise;
            sampler2D _LevelTex;
			float4 _spriteRect;
			float4 _MainTex_ST;
			uniform float4 _boxWormColor;
            float _RAIN;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos).xy;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
				o.clr = v.color;
#if FireSpriteWing || FireSpriteBody
                o.time = (DecodeFloatRG(o.clr.xy)+_RAIN)*PI*2+o.clr.a;
#else
                o.time = _RAIN;
#endif
				return o;
			}

            float angled(float pos, float tip){
                tip = clamp(tip,0.0001,.9999);
                return lerp(pos/tip,(-pos+1)/(1-tip), step(tip,pos));
            }

            fixed Square(float2 uv, float size){
                return step(abs(uv.x),size)*step(abs(uv.y),size);
            }

			fixed4 frag (v2f i) : SV_Target
            {
                rippleClip(i.scrPos);
                fixed3 color = i.clr.xyz;
                fixed3 light = tex2D(_PalTex,float2(20/32.0, 5/8.0) );
                fixed3 cyan = _boxWormColor.xyz;
                fixed3 dimCyan = color+cyan*.1;
                fixed3 shadow = max(color*.3,.01);
                fixed3 highlight = color+light*0.2;
                fixed retraction = i.clr.w;
                fixed unRetraction = (1-retraction);
                fixed contour = 1;
#if Body //copypaste from vectorcircle.shader
                half centerDist = clamp(distance(i.uv.xy, half2(0.5, 0.5))*2, 0, 1);

                if(centerDist < 1 - i.clr.w || centerDist == 1.0)
                return half4(0,0,0,0);


                return half4(i.clr.xyz, 1);
#elif LarvaHolder
                
                fixed fastRetraction = saturate(retraction*1.5);
                fixed fastUnRetraction = 1-fastRetraction;
                float2 squishedUV = i.uv*2-1;
                squishedUV.y *= 1.5;
                fixed cyanCircle = step(length(squishedUV-fixed2(0,.7)),.6);
                squishedUV.y += .5*saturate(unRetraction*2-1);
                fixed outerCircle = step(length(squishedUV),1-fastRetraction*.4);
                fixed cyanRim = step(length(squishedUV-float2(0,.2)*fastUnRetraction),1-fastRetraction*.24);
                fixed innerTube = step(length(float2(squishedUV.x,squishedUV.y-retraction*.5)),.7+fastRetraction*.4);
                fixed bottomRingCircle =step(length(float2(squishedUV.x*(1+retraction*.4),squishedUV.y+.8-fastRetraction*.5)),1+fastRetraction*.4);;
                fixed bottomRingCircle2 =step(length(float2(squishedUV.x*(1+retraction*.4),squishedUV.y+.4-fastRetraction*.5)),1+fastRetraction*.4);;
                innerTube*=bottomRingCircle;
                fixed square = step(abs(squishedUV.x),.9)*step(-squishedUV.y,0)*step(squishedUV.y,1.4);
                contour = saturate(outerCircle+cyanRim);
                color += color*max(bottomRingCircle,bottomRingCircle2)*(.09);
                color -= color*innerTube*(.07+i.uv.y*.6);
                fixed l = max(.5,max(max(color.x,color.y),color.z));
                color = lerp(color,lerp(color*.5,color+cyan*l,(saturate(retraction*2-1)+.01)),cyanCircle*innerTube);
                color = lerp(color,dimCyan,saturate(cyanRim-outerCircle));

                return fixed4(color,contour);
#elif Larva
                color =  light+tex2D(_PalTex,float2(0.5/32.0, 7.5/8.0) )*.3f;
                fixed3 fleshy = fixed3(1,0.3,0.4);
                fixed3 larvaMeat = max(color*fleshy,fleshy*.4);

                fixed fastRetraction = saturate(retraction*1.5);
                fixed fastUnRetraction = 1-fastRetraction;
                fixed pull = i.clr.x*fastUnRetraction;
                fixed variation = fmod(i.clr.z*123,.11)/.11;
                float2 lUV = i.uv*2-1;
                lUV.y*=1.5;
                fixed yOffset = lUV.y-1.3-fastRetraction*3.5+1*pull;
                fixed circleLen = length(float2(lUV.x,lUV.y-.6-fastRetraction*3.5+1*pull));
                fixed circlePulse=saturate(sin(variation+_RAIN*(10+variation*2))-.9);
                fixed circle = step(circleLen,.6+circlePulse);
                fixed dot = step(length(float2(lUV.x,lUV.y+circlePulse*2-.4-fastRetraction*3.5+1*pull)),.15);
                fixed root = step(abs(lUV.x+sin(yOffset*4+_RAIN*(100+variation*10))*lUV.y*.24),.5)*step(abs(lUV.y-1.3-fastRetraction*3.5+1*pull),.7);
                lUV.y*=1.5;
                lUV.y += .5*saturate(unRetraction*2-1);
                lUV.y-=.35;

                fixed mask =step(length(float2(lUV.x*(1+retraction*.4),max(lUV.y,0)-.4-fastRetraction*.5)),1+fastRetraction*.4);
                contour = circle+root;
                contour*=mask;
                mask = saturate(mask);
                fixed3 result =larvaMeat; 
                 result =lerp(result, lerp(cyan*min(.4,i.clr.y),cyan+light*.2,.6-circleLen*.4),circle); 
                 result =lerp(result,result*.8,dot); 

                 return fixed4(result,contour);
#elif LarvaFood
                 color =  light+tex2D(_PalTex,float2(0.5/32.0, 7.5/8.0) )*.3f;
                 fixed3 fleshy = fixed3(1,0.3,0.4);
                 float biteTime = i.clr.x*3;
                 i.uv.y-=biteTime*.08;
                 float2 cuv = i.uv*2-1;
                 fixed3 larvaMeat = max(color*fleshy,fleshy*.4);
                 fixed speed =i.clr.y;
                 fixed random = i.clr.z;
                 cuv.y -=0.7;
                 cuv.y *=3;
                 float dent = smoothstep(1,0,abs(cuv.x));
                 float wave = sin(cuv.y*(3-sin(_RAIN*20+sin(_RAIN*24)))-_RAIN*24+dent*1.6*speed+random*111);
                 wave += sin(cuv.y-_RAIN*17+dent*1.6*speed+random*111);
                 float2 dcuv = cuv;
                 fixed noise = tex2D(_NoiseTex,cuv*.14+fixed2(sin(_RAIN*15)*.04,sin(_RAIN*14)*.04)    ).x;
                 fixed bites = tex2D(_NoiseTex,cuv*.1+random).x*.3+i.uv.y- .3+biteTime*.23;
                 fixed deadCrooked = sin((i.uv.y)*PI*(4+(1-speed)*2))*.15*(1-speed);
                 dcuv.x+=wave*.15*speed+deadCrooked;
                 fixed circleLen = length(float2(cuv.x,cuv.y));
                 fixed dot = step(length(float2(cuv.x,cuv.y-.4)),.2);
                 fixed circle = step(circleLen,.70+saturate(sin(random+_RAIN*(15+random*2))-.9)*speed);
                 fixed bitemark = step(0.90,bites);
                 bites = step(bites,1);
                 float tl = .3+i.uv.y*.3-smoothstep(0.5,0.0,i.uv.y)*(.35+(1-speed)*.8);
                 fixed smoothTail = smoothstep(tl+.4,tl-.6,abs(dcuv.x));
                 fixed tail = step(.4,smoothTail)*step(cuv.y,.3);
                 fixed vLines = sin((cuv.x+noise*1.4)*PI*3.5); 
                 contour =circle+tail; 
                 contour *=bites;
                 fixed3 col = lerp((light+cyan*.4)*.5,max(color*fleshy,fleshy*.4),speed);
                 col =lerp(col,col*0.8,smoothstep(1,0.5,smoothTail)); 
                 col = lerp(col,light+cyan*.2,vLines*2*saturate(.9-i.uv.y)*speed);
                 col =lerp(col, lerp(cyan,(cyan+light*.8)*.5,smoothstep(0,.8,circleLen))*(.5+speed*.5),circle); 
                 col =lerp(col,col*.8,dot); 
                 col =lerp(col,cyan*.8+light*.2,bitemark); 
                 return fixed4(col,contour);

#elif Box
                float2 centeredUv = i.uv*2-1;
                centeredUv.y*=1.5;
                centeredUv.y+=+.5;
                fixed len = step(length(fixed2(centeredUv.x,saturate(centeredUv.y-.5))),.99999);
                fixed len2 = smoothstep(1.2,.8,length(fixed2(centeredUv.x,centeredUv.y*.7-1.3)));
                fixed shaft = step(abs(centeredUv.x),.5)*len*len2;
                float2 topCoord=centeredUv;
                topCoord.y*=1.5;
                topCoord.y+=.5;
                float time = i.clr.w;
                float circleTime = time*PI;
                float2x2 rotation = rotate2d(-circleTime);
                topCoord = mul(topCoord,rotation);
                topCoord = abs(topCoord);
                topCoord*=1.4;
                fixed square = step(topCoord.x,1)*step(topCoord.y,1);
                fixed p1 = sin((time+1)*PI+PI*1.25);
                fixed p2 = sin((time+0.5)*PI+PI*1.25);
                fixed p3 = sin((time+0)*PI+PI*1.25);
                fixed p4 = sin((time-0.5)*PI+PI*1.25);
                fixed plane1 = (p2<p1)*step(centeredUv.x,p1)*step(p2,centeredUv.x);
                fixed plane2 = (p3<p2)*step(centeredUv.x,p2)*step(p3,centeredUv.x);
                fixed plane3 = (p4<p3)*step(centeredUv.x,p3)*step(p4,centeredUv.x);
                fixed l1 = saturate(iLerp(p1,p2,centeredUv.x));
                fixed l2 = saturate(iLerp(p2,p3,centeredUv.x));
                fixed l3 = saturate(iLerp(p3,p4,centeredUv.x));
                fixed h1 = lerp (p4,p1,l1);
                fixed h2 = lerp (p1,p2,l2);
                fixed h3 = lerp (p2,p3,l3);
                float2 coord = centeredUv.y*1.5+.5;
                plane1 *= step(h1,coord);
                plane2 *= step(h2,coord);
                plane3 *= step(h3,coord);
                plane1 *= step(coord,h1+1.8);
                plane2 *= step(coord,h2+1.8);
                plane3 *= step(coord,h3+1.8);

                fixed steamPort = length(centeredUv*float2(2,3)+fixed2(0,1));
                steamPort = step(steamPort,1);
                float sppl = length(centeredUv*float2(2,3)+fixed2(0,0.6));
                fixed steamPortPlane = step(sppl,1);
                steamPortPlane*=steamPort;
                steamPortPlane -= step(sppl,.3);

                float2 eyeHoleCoord = centeredUv;
                circleTime = (time*1.05-.025+.5)*PI;
                float sct=sin(circleTime);
                float cct=cos(circleTime)*.5;
                float2 eyeCoord = eyeHoleCoord + fixed2(sct,cct)*.5;
                eyeCoord.y-=.333;
                eyeHoleCoord+= fixed2(sct,cct)*.7;
                eyeHoleCoord.y-=.333;
                rotation = rotate2d(-circleTime);
                eyeHoleCoord = mul(eyeHoleCoord,rotation);
                eyeHoleCoord.y *=1.2;
                eyeCoord = mul(eyeCoord,rotation);
                eyeCoord.y *=1.5;
                float eyeSquish = sin((time)*PI);
                eyeHoleCoord.y *=1.2/eyeSquish;
                eyeCoord.y *=1.2/eyeSquish;
                fixed eyeHole = length(eyeHoleCoord);
                eyeHole = step(eyeHole,.55);
                eyeHole*=plane2;
                fixed eye = length(eyeCoord);
                eye = step(eye,.45);
                eye*=eyeHole;

                fixed mask = (square+plane1+plane2+plane3)*len+shaft+len*len2+eyeHole;
                mask = saturate(mask);
                fixed3 shaftCol = color*.8*smoothstep(1.6,.4,i.uv.y);
                fixed3 sides = color+light*0.4;
                fixed3 forward = color*0.7;
                fixed3 p1col = lerp(sides,forward,sin((time+.5)*PI));
                fixed3 p2col = lerp(sides,forward,sin(time*PI));
                fixed3 p3col = lerp(sides,forward,sin((time-.5)*PI));

                fixed3 result = shadow;
                result = lerp(result,shaftCol,shaft);
                result = lerp(result,p1col,plane1);
                result = lerp(result,p2col,plane2);
                result = lerp(result,p3col,plane3);
                result = lerp(result,highlight,square);
                result = lerp(result,p2col*.8,eyeHole);
                result = lerp(result,cyan,eye);
                result = lerp(result,forward,steamPort);
                result = lerp(result,highlight,steamPortPlane);

                return fixed4(result,mask);
#elif OpenBox
                contour = 0;
                i.uv*=.6f;
                i.uv+=.2f;
                // return 1;

                fixed3 headCol =  tex2D(_PalTex,float2(2.5/32.0, 7.5/8.0) )+tex2D(_PalTex,float2(0.5/32.0, 7.5/8.0) )*.3f;
                 dimCyan = headCol+cyan*.1;
                 shadow = max(headCol*.3,.01);
                 highlight = headCol+light*0.2;
                 color = headCol;

                float time = saturate(i.clr.w);
                // float time = i.clr.w;
                // time = fmod(_Time.y*.5,1);
                float circleTime = pow(time,2)*PI;

                float2 cuv = i.uv*2-1;
                cuv*=2;
                cuv.y +=.1;
                cuv.x*=1.3;
                cuv.y*=1.30;
                float2 holeUV = cuv*2;
                fixed len = step(length(fixed2(holeUV.x,saturate(holeUV.y+.3))),.99999);
                fixed len2 = smoothstep(1.3,.6,length(fixed2(holeUV.x,holeUV.y*.7-0.7)));
                float len3 = length(holeUV+fixed2(0,.3));
                fixed shaftTop = step(len3,.5);
                fixed shaftHole = step(len3,.4);
                fixed shaftLight = shaftHole*smoothstep(0,.4+i.clr.x*6,i.uv.y)*1.8*step(.0001,i.clr.x);
                fixed holeShadow = len*len2;
                fixed shaft = step(abs(holeUV.x),.5)*step(.11,holeUV.y+.3)*2;
                shaft *= len;
                fixed boxClose = saturate(iLerp(.85,1,time));
                boxClose*=boxClose;
                float2x2 rotation = rotate2d(-(circleTime*2)+.10);
                fixed circle = length(cuv*fixed2(1,1-boxClose*.35));
                cuv.y-=iLerp(0.4,1.2,circle)*(0.4-boxClose*1.4)*step(-1.34,cuv.y);
                cuv.y+= iLerp(.4,0.8,i.uv.y)*.5;
                fixed2 puv = mul(cuv,rotation);
                fixed planeOffset = .8-boxClose*.2;
                fixed planeSize = .35+boxClose*.03;
                fixed panelL = Square(puv+fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose),planeSize);
                fixed circleL = step(length(puv+fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose)),.25);
                fixed panelR = Square(puv-fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose),planeSize);
                fixed circleR = step(length(puv-fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose)),.25);
                fixed panelD = Square(puv*fixed2(1,1+.7*boxClose)-fixed2(0,planeOffset),planeSize+.1*boxClose);
                fixed panelU = Square(puv+fixed2(0,planeOffset),planeSize);
                cuv = mul(cuv-fixed2(0,.1),rotation);
                planeSize-=.02;
                fixed shadowL = Square(cuv+fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose),planeSize);
                fixed shadowR = Square(cuv-fixed2(planeOffset-0.5*boxClose,-puv.x*1.0*boxClose),planeSize);
                fixed shadowD = Square(cuv*fixed2(1,1+.7*boxClose)-fixed2(0,planeOffset),planeSize+.1*boxClose);
                fixed shadowU = Square(cuv+fixed2(0,planeOffset),planeSize);

                fixed3 result = color*.6;
                result = lerp(result, color +color*(.3-(-1.1+i.uv.y*3)), shaft);
                result = lerp(result, color+light*(1-i.uv.y-.2)*.3, saturate(panelL+panelR+panelU+panelD));
                result = lerp(result, result*.83, saturate(circleL+circleR));
                result = lerp(result, highlight,shaftTop);
                result = lerp(result, shadow,shaftHole);
                result = lerp(result, cyan*light, shaftLight);
                contour += panelL+panelR+panelD+panelU+shadowL+shadowR+shadowD+shadowU+shaft+shaftTop+len2*len;
                contour = saturate(contour);

                return fixed4(result,contour);
#elif FireSpriteWing
                float t =i.time; 
                float speed = saturate(iLerp(.4,1,i.clr.z));
                float unfold = saturate(iLerp(0,.2,i.clr.z));
                float random = i.clr.w;


                fixed depth = tex2D(_LevelTex, i.texCoord).x;
                depth = AddTerrain(depth, i.texCoord, _spriteRect);
                depth = get_depth(depth);
                depth = saturate(iLerp(0,5,depth));

                float2 wingCoord =i.uv*2-1; 
                float glow = smoothstep(2,-0.4,length(wingCoord*fixed2(1.3,0.5)))*(1-i.uv.y)*1.5;
                float foilCoord = i.uv.y+length(wingCoord)*.6;
                fixed3 foil = fixed4(sin(foilCoord*8+t*1)*.5+.5,sin(foilCoord*9+t*2)*.5+.5,sin(foilCoord*10+t*3)*.5+.5,1);
                fixed noise = tex2D(_NoiseTex,wingCoord+fixed2(0,_RAIN+random)).x;
                fixed4 uniNoise = tex2D(_UniNoise,wingCoord*fixed2(.226,.125)+fixed2(random,_RAIN*.2));
                fixed4 skyNoise = tex2D(_UniNoise,i.texCoord*fixed2(1,0.5)*8 +fixed2(random,_RAIN*.085));
                fixed edgeFade = smoothstep(.0,.3,(1-abs(wingCoord.x))*(1-abs(wingCoord.y)));
                float dent = smoothstep(1,0,abs(wingCoord.x));
                float wave = sin(wingCoord.y*(2+8*speed)-t*2+dent*1.6*speed+random*111);
                float split = pulse(i.uv.y,0.6+unfold,.75);
                fixed specks = pulse(uniNoise.x,sin(_RAIN*2)*.5+.5,.1);
                fixed skySpecks = pulse(skyNoise.y,sin(_RAIN*1.3)*.5+.5,.1);
                fixed speedGlow = pulse(wingCoord.x,0-wave*.4,saturate(.85-i.uv.y*.4))*.4*speed;   
                glow*=split;
                wingCoord.x+=wave*i.uv.y*(0.5+.8*speed)*(1-split);
                split*=.5;
                split = (2-split)*split;

                float wng = pulse(wingCoord.x,0+split+noise*.2*split,.05+.15*split+speed*.2 )
                           +pulse(wingCoord.x,0-split-noise*.2*split,.05+.15*split+speed*.2 );
                           wng*=.8+unfold*.2;
                float wng2 = pulse(wingCoord.y-glow*4+.7,0.0-split-noise*.6*split,.05+.20*split+speed*.2 )
                            +pulse(wingCoord.y-glow*4,0-split-noise*.6*split,.05+.20*split+speed*.2 );
               wng2*=smoothstep(0.2,.6,glow)*.5;
               contour = ((glow*.8+wng+wng2+specks*.3*split+skySpecks*glow*.3+speedGlow)*edgeFade);
               contour *=depth;
               fixed3 col = max(cyan*.5+light*.5,cyan*.8);
               col = lerp(col,col*.8+foil*1.2,specks*.4*split+skySpecks*glow*.4);
               col = lerp(col,col*.9+foil,glow);
               col = lerp(col,foil,wng2);
               col = lerp(col,col*.9+foil*.3,speed);


                return fixed4(col,contour);

#elif FireSpriteBody
                float t =i.time; 
                float speed = saturate(iLerp(.4,1,i.clr.z));
                float unfold = saturate(iLerp(0,.2,i.clr.z));
                float2 cuv = i.uv*2-1;
                cuv *= 2-speed;
                float angle = atan2(cuv.x,cuv.y);

                fixed depth = tex2D(_LevelTex, i.texCoord).x;
                depth = AddTerrain(depth, i.texCoord, _spriteRect);
                depth = get_depth(depth);
                depth = saturate(iLerp(0,5,depth));

                float dent = smoothstep(1,0,abs(cuv.x));
                float wave = sin(cuv.y*(2+8*speed)+t*3+dent*1.6*speed);
                float len = length(cuv+fixed2(wave*speed*.25,speed*.25));
                float spiral = pulse(sin(len*8+angle*.5+t+_RAIN),.0,1);
                float glow = smoothstep(2-1*speed,0,len)-smoothstep(1-.5*speed,0,len);
                fixed circle = smoothstep(1,.93-speed,len);
                fixed ring = pulse(length(cuv+fixed2(0,.4)),.5+(sin(_RAIN*10)+sin(_RAIN*17.77+i.uv.y*4))*.1,.2);
                fixed edgeFade = smoothstep(.0,.2,(1-abs(cuv.x))*(1-abs(cuv.y)));
                fixed w = pulse(cuv.x*2+wave*2,0,2.)*circle*speed;
                fixed  core = step(len,.4);
                float foilCoord = i.uv.y*(.25+speed*2)+length(cuv*.5)*.6*(1-unfold);
                fixed3 foil = fixed4(sin(foilCoord*8+t*1)*.5+.5,sin(foilCoord*9+t*2)*.5+.5,sin(foilCoord*10+t*3)*.5+.5,1);

                contour = core*(1-unfold)+circle*saturate(.25-speed)+ring*(.25+speed*.25)+glow;
                contour*=depth;
                fixed3 col = max(cyan*.5+light*.5,cyan*.8);
                col = lerp(col,light*.1,core);
                col = lerp(col,cyan,dent*edgeFade);
                col = lerp(col,col*0.8+foil*.2,spiral);
                col = lerp(col,col*1.3,ring);
                col = lerp(col,col*.5+foil*.5,glow*speed);
                col = lerp(col,col+foil,glow);
                return fixed4(col,contour);;

#endif

                return fixed4(i.clr.xyz,i.clr.w);
			}
            ENDCG
		}
    }
}
