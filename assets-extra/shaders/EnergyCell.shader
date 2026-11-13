Shader "Futile/EnergyCell"
{
	Properties
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		_Sos ("Input", Range(0,1)) = 0

	}
	SubShader
	{
		Blend SrcAlpha OneMinusSrcAlpha
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
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
			#pragma profileoption NumInstructionSlots=4096
			#pragma profileoption NumMathInstructionSlots=4096

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4  pos : SV_POSITION;
				float2  uv : TEXCOORD0;
				float4 scrPos : TEXCOORD1;
				float rot : TEXCOORD2;
				float2x2 rotMat : TEXCOORD3;
				float4 clr : COLOR;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			sampler2D _PalTex;
			sampler2D _NoiseTex;
			float _SpriteRot;
			float _Sos;
			float2 _screenSize;
			float4 _spriteRect;
			float4 _EnergyCellCoreCol;


			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				o.scrPos = ComputeScreenPos(o.pos);
				o.clr = v.color;
				o.rot = DecodeFloatRG(o.clr.xy)*3.14159*2;
				// o.rot = o.clr.z*3.14159*2; unpac
				// o.rot = ((atan2(UNITY_MATRIX_T_MV[2][0],UNITY_MATRIX_T_MV[0][0])/3.14159)*5+.5)*3.14159*.2+.31415;
				o.rotMat = float2x2(
					cos(o.rot),-sin(o.rot),
					sin(o.rot),cos(o.rot)
				);
				return o;
			}
			float inver(float col){
			col = col*-1+1;
			return col;
			}
			float getDepth(float level){
				level = round(level*255);
				float sky = inver(step(level,254))*31;
				float shadows = inver(step(level,90))*90;
				float flat = level-shadows;
				float depth = (int(flat-1) % 30)+sky;
			return depth;
			}

			float2x2 rot(float a)
			{
				return float2x2 (
					cos(a), -sin(a),
					sin(a), cos(a)
				);
			}
			float2x2 scale(float2 s)
			{
				return float2x2(
					s.x,0,
					0,s.y
				);
			}
			float cubicPulse( float c, float w, float x )
			{
				x = abs(x - c);
				if( x>w ) return 0.0;
				x /= w;
				return 1.0 - x*x*(3.0-2.0*x);
			}
			float gain(float x, float k) 
			{
				float a = 0.5*pow(2.0*((x<0.5)?x:1.0-x), k);
				return (x<0.5)?a:1.0-a;
			}

			fixed4 part(float angle, fixed2 uv, fixed yOff, fixed tOff,fixed4 col,fixed4 coreCol, fixed4 cCol, fixed4 shellLight,fixed inp, int reverse = 1)
			{
				fixed rev = 1-(1+reverse)*.5;
				float angle2 =angle-1.2+3.14159*rev;
				fixed circle = length(uv);
				float bottomCompensate = sin(-angle2+4)*.5+.5;
				float leftCompensate = (cos(-angle2+3)*.5+.5)*2+cos(-angle2+1)*.5+.5;
				circle = smoothstep(1.5,.4,circle);
				fixed input = inp;
				fixed t = _Time.y*.2+tOff;
				fixed pipi = 6.28318;
				fixed backnforth = 1+cos(frac(t-.5)*pipi)*2;
				fixed backnforth2 = 1+cos(frac(t*2-.5)*pipi)*1.5;
				float2 shOff = float2(sin(1-angle2)-bottomCompensate*.4,cos(1-angle2)-leftCompensate*.5*input)*.9;
				col+=cCol*input*(-backnforth+3.14159)*.3*circle	;
				col *=.5*input*.1+.7;
				uv *= reverse;
				uv = uv+fixed2(0,-yOff);
				uv = uv*5+fixed2(sin(frac(t)*pipi)*4*input,cos(frac(t)*pipi)*input*.1);
				fixed2 shading = uv+shOff;
				shading = mul(shading,scale(.7-bottomCompensate*.3));
				// fixed2 shading = mul(uv+fixed2(.2+.3*input-.2+.5*reverse,-.2-.1*reverse),rot(-.5));
				// shading = mul(shading,scale(1-cos(frac(t-.6)*pipi)*.3*input-(sin(-angle2+2.75)*.5+.5)*.5-.1*reverse));

				// shading = (-shading+1)*.5*-reverse+.5+.5*reverse;
				
				shading = length(shading);
				
				shading = step(shading,0.5)*lerp(1,(backnforth*.3+.2),input);
				// shading = step(shading,0.5);
				uv = mul(uv,scale(1-cos(frac(t-.5)*pipi)*.3*input));
				uv = mul(uv,rot(sin(frac(t)*pipi)*1+(.25*input)));
				fixed outline = step(.1,smoothstep(1,0,clamp(length(uv),0,1))-smoothstep(.6+backnforth2*.01,0,uv.y));
				outline *=input;
				uv = step(.06,smoothstep(1,0,clamp(length(uv),0,1))-smoothstep(.6+backnforth2*.1,0,uv.y));
				uv *= clamp((backnforth+.5)*.1+.8,0,1);
				// col +=fixed4(shading.xy*.2,shading.x*.2,0)-fixed4(outline,outline,outline,0)+.2;
				col =lerp(col,shellLight,shading.x)+cCol*(1-fixed4(outline,outline,outline,0))*input*.5;

	
				return col*fixed4(uv.x,uv.x,uv.x,step(.1,uv.x)*abs(backnforth*(.9-(input*.4))*reverse));
				// return circle;
			}

			fixed4 shield(float2 uv, float _Input)
			{
				uv = float2(sin(uv.x*2),sin(uv.y*2));
				fixed circle = smoothstep(.1,.9,length(uv));
				// circle -= clamp(circle,0,1);
				uv = float2(cubicPulse(_Input,.5+circle,dot(uv,uv)*.5),atan2(uv.x,uv.y));
				int fac =20;
				uv*=fac;
				fixed2 i = floor(uv);
				fixed2 f = frac(uv);
				fixed2 q = i/fac;
				// return cubicPulse(.5,.5,f.x*f.y*2-1);
				return lerp(clamp(float4(dot(dot(sin(q*1+_Time.y),cos(q*(7+_SinTime.y)-_Time.y*.5)),dot(sin(q*(2+_SinTime.x)-_Time.y*.66),cos(q*3-_Time.y*.4))),0,0,1),0,circle),0,cubicPulse(.5,.5,f.x))*circle*.6+circle*.4;
			}

			fixed4 blob(fixed2 iUV, fixed2 uv, fixed2 scrPos, fixed4 coreCol)
			{
				fixed4 col1 = coreCol;
				uv = uv;
				float nose = tex2D(_NoiseTex,scrPos+float2(_SinTime.x,_CosTime.x));
				float nois = tex2D(_NoiseTex,uv+float2(0,-_Time.x));
				float noise = tex2D(_NoiseTex,uv+nose+float2(nois*.3,-_Time.x));
				uv = float2(sin(uv.x+_Time.x),cos	(uv.y+_Time.y*.5));
				float noise2 = tex2D(_NoiseTex,uv+noise*.3);
				noise = tex2D(_NoiseTex,float2(uv.y,noise*.3));
				float noise3 = cubicPulse(noise*.3,noise2*.3,max(max(sin(_Time.y),sin(_Time.w+.25)),sin(_Time.w+.75))*.1+length(iUV*2-1))*1-length(iUV*2-1);
				noise = tex2D(_NoiseTex,float2(uv.y,noise3))*1-step(noise3,-.01);
				return (col1*noise*.1+noise3*noise2+nose-float4(0,0,0,-1)-length(iUV*2-1))-.3+smoothstep(.2,noise3*.05,length(iUV*2-1));
			}

			fixed4 molten(fixed2 uv, float2x2 rotMat)
			{
				uv = mul(uv,rot(-_Time.z));
				fixed2 rotuv = mul(uv,rotMat);
				float2 uvdis = rotuv;
				fixed noise = tex2D(_NoiseTex, rotuv*.1+_Time.x*.2);
				float waves = (_SinTime.x*-.5+_SinTime.y*.3+_SinTime.z*.7)*noise;
				uvdis = float2(length(uvdis*5),atan2(uvdis.x,uvdis.y)*.5);
				fixed noise2 = tex2D(_NoiseTex,uvdis+waves-_Time.y);
				noise2 = noise2-(cubicPulse(length(rotuv),0.4,.8));
				return step(noise2,-.6)*.7+smoothstep(-.3,-1,noise2)*2*lerp(float4(2,.9,0,1),float4(2,.5,0,1),waves*noise2);
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;
				float Depth = 1-step(getDepth(tex2D(_LevelTex,textCoord).x),4);
				float bigInput = DecodeFloatRG(i.clr.zw);
				float _Input = smoothstep(0,.5,bigInput);
				float _Input2 = smoothstep(.5,1,bigInput);
				fixed angle = i.rot;
				fixed2 scrPos = i.scrPos.xy/i.scrPos.w;
				// fixed4 shellCol = fixed4(.3,.1,.1,1);
				fixed4 fireCol = float4(1,.8,0,1);
				fixed colSwitch = smoothstep(0,.5,_Input2);
				fixed4 shellCol = lerp(tex2D(_PalTex, float2(3.5/32, 3.5/16)),fireCol,colSwitch);
				shellCol+= step(1-Luminance(shellCol),1)*.05;

				fixed4 shellLight = lerp(tex2D(_PalTex, float2(13.5/32, 3.5/16)),fireCol,colSwitch);
				shellLight+= step(1-Luminance(shellLight),1)*.1;
				// fixed4 shellLight = fixed4(0,0,0,1);
				fixed inp = gain(_Input,1.5);
				fixed Off = -.01+inp*0.57;
				fixed2 uv = i.uv*2-1;
				fixed noise = tex2D(_NoiseTex,mul(uv,rot(+_Time.z)));
				fixed2 rotuv = mul(uv,i.rotMat);
				fixed4 upper = 0;
				fixed4 lights = 0;
				fixed4 core = _EnergyCellCoreCol;
				fixed circle = smoothstep((1-inp)*.9,.5+(1-inp)*.42,1-length(uv));
				fixed4 core2 = core;
				core *=circle;
				int n = 8;
				fixed tDiv = 1/fixed(n);
				for(int k = 0; k<n; k++)
				{
					// upper-=part(uv,Off,k*tDiv,shellCol,core)*10;
					// upper = clamp(upper,0,1);
					// upper+=part(uv,Off,k*tDiv,shellCol,core);
					fixed4 temp = part(angle,uv,Off,k*tDiv,shellCol,core,core2,shellLight,inp-smoothstep(0.5,1,_Input2));
					upper=lerp(temp,upper,step(temp.w,upper.w));
				}
				for(int s = 0; s<n; s++)
				{
					// upper-=part(uv,Off,s*tDiv+.19,shellCol,core,-1);
					// upper = clamp(upper,0,1);
					// upper+=part(uv,Off,s*tDiv+.19,shellCol,core,-1);
					fixed4 temp = part(angle,uv,Off,s*tDiv+.19,shellCol,core,core2,shellLight,inp-smoothstep(0.5,1,_Input2),-1);
					upper=lerp(temp,upper,step(temp.w,upper.w));
				}
				fixed fix =  1-cubicPulse(atan2(rotuv.y,rotuv.x),.3,-1.573)*.8;
				fixed nrg = lerp(lerp(shield(-rotuv,_Input),shield(rotuv,_Input),fix),0,smoothstep(.5,1.1,upper.w*(1-_Input2)));
				// fixed nrg = lerp(shield(rotuv)*(1-cubicPulse(atan2(rotuv.y,rotuv.x),.5,-1.573)*.1),0,smoothstep(.5,1.1,upper.w));
				fixed4 energyBlob = lerp(blob(i.uv,rotuv,scrPos,core),0,smoothstep(.5,1.1,upper.w*(1-_Input2)));
				upper = fixed4(upper.xyz,step(.01,abs(upper.x+upper.y+upper.z)*.3));
				// return lerp(core,upper,step(.00001,upper))+lerp(upper,core,step(.00001,upper))*.5*inp;		
				// return		upper+nrg*core+lerp(energyBlob,1+energyBlob,nrg*core)*core;
				float meltSwitch = smoothstep(.3,1,_Input2);	
				return		(lerp(upper,molten(uv, i.rotMat),step(noise,meltSwitch))+nrg*core+lerp(energyBlob,1+energyBlob,nrg)*core)*Depth;
				// return cubicPulse(mul(i.uv*2-1,i.rotMat).x,.5,.5);
			}
			ENDCG
		}
	}
}
