Shader "Futile/LevelSnowShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend SrcAlpha OneMinusSrcAlpha 
		Fog { Color(0,0,0,0) }
		Lighting Off
		Cull Off //we can turn backface culling off because we know nothing will be facing backwards

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
			#pragma profileoption NumInstructionSlots=4096
			#pragma profileoption NumMathInstructionSlots=4096
			#pragma exclude_renderers OpenGL
#pragma multi_compile _ COMBINEDLEVEL 
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"

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
				float4 clr : COLOR;
			};
			#if defined(SHADER_API_PSSL)
			sampler2D _GrabTexture;
			#else
			sampler2D _GrabTexture : register(s0);
			#endif
			sampler2D _PalTex;
			float _light = 0;
			sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			sampler2D _OrigLevelTex;
			float2 _LevelTex_TexelSize;
			float4 _lightDirAndPixelSize;
			float2 _screenSize;
			float4 _spriteRect;
			float4 _EffectColor;
			float _WetTerrain;
			float _waterLevel;
			float _RAIN;
			float _cloudsSpeed;
			float _fogAmount;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;
			sampler2D _SnowSources;
			float2 _SnowSources_TexelSize;

			

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			float GetDepth (float a)
			{
				a = clamp(a,0,1);
				if (a==1.0) return 255;
				a=round(a*255);
				float shadows = (step(a,90)*-1+1)*90;
				return fmod(a-shadows-1, 30);
			}

			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}

			float GetShadows (float a)
			{
				// if (a==1.0) return 1;
				a*=255;
				return (step(round(a),90)*-1+1);
			}
			float cubicPulse( float c, float w, float x )
			{
				x = abs(x - c);
				if( x>w ) return 0.0;
				x /= w;
				return 1.0 - x*x*(3.0-2.0*x);
			}
			float easeInExpo(float t) {
				return (t == 0.0) ? 0.0 : pow(2.0, 10.0 * (t - 1.0));
			}
			float easeOutExpo(float t) {
			return (t == 1.0) ? 1.0 : -pow(2.0, -10.0 * t) + 1.0;
			}
			float easeOutCubic(float t) {
				return (t = t - 1.0) * t * t + 1.0;
			}
			float impulse( float k, float x )
			{
				const float h = k*x;
				return h*exp(1.0-h);
			}
			float easeOutQuad(float t) {
				return -1.0 * t * (t - 2.0);
			}
			float easeInQuad(float t) {
				return t * t;
			}
			float easeInOutExpo(float t) {
				if (t == 0.0 || t == 1.0) {
					return t;
				}
				if ((t *= 2.0) < 1.0) {
					return 0.5 * pow(2.0, 10.0 * (t - 1.0));
				} else {
					return 0.5 * (-pow(2.0, -10.0 * (t - 1.0)) + 2.0);
				}
			}
			fixed4 frag(v2f i) : SV_Target
			{
				uint iter = 20;
				uint invIter = 10;
				float ratio = _LevelTex_TexelSize.y/_LevelTex_TexelSize.x;
				float ratio2 = _LevelTex_TexelSize.x/_LevelTex_TexelSize.y;
				
				/////////////////////   TEXTURE COORDINATE////////////////////
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;
				///////////////////////////////////////////////////////////////

				/////////////////////////////////////////
				textCoord = i.uv;
				float input = 1;
				// float input = i.clr.w*dist;
				// float input = fmod(_Time.x*.2,1);
				float input2 = 1;
				float input3 = 1;
				////////// SNOW HEATMAP //////////////
				float snowIntensity = 1;
				float snowNoise = 1;
				float circle = 1;
				float noiseX =tex2D(_NoiseTex2,float2(textCoord.x,textCoord.y)*1).x;
				float noise0 =tex2D(_NoiseTex,float2(textCoord.x,textCoord.y)*2).x+noiseX*.3;
				for(uint o = 0; o<20;o++)
				{
					uint hor = o%7;
					uint hor2 = (o+20)%7;
					uint hor3 = ((uint)(o/4)+40)%7;
					uint ver = o/7;
					uint ver2 = (o+20)/7;
					uint ver3 = ((uint)(o/4)+40)/7;
					uint count = o%4;
					fixed4 snow = tex2D(_SnowSources,float2(_SnowSources_TexelSize.x*.5+_SnowSources_TexelSize.x*hor,_SnowSources_TexelSize.y*.5+_SnowSources_TexelSize.y*ver));
				    fixed4 snow2 = tex2D(_SnowSources,float2(_SnowSources_TexelSize.x*.5+_SnowSources_TexelSize.x*hor2,_SnowSources_TexelSize.y*.5+_SnowSources_TexelSize.y*ver2));
				    int snow3 = (tex2D(_SnowSources,float2(_SnowSources_TexelSize.x*.5+_SnowSources_TexelSize.x*hor3,_SnowSources_TexelSize.y*.5+_SnowSources_TexelSize.y*ver3))[count])*5+.4;
					
					float2 coord = (float2(DecodeFloatRG(snow.xy),DecodeFloatRG(snow.zw))-.3)*3.33333;
					float rad = DecodeFloatRG(snow2.xy)*(4);
					float2 snowcoord = textCoord/rad;
					coord = coord/rad;
									// square
									circle = smoothstep(.5,.4,abs((snowcoord.x*ratio-coord.x*ratio)));
									circle = -clamp(circle*smoothstep(.5,.4,abs((snowcoord.y-coord.y))),0,1)+1;
									if (snow3 >= 1&&snow3<4)
									{	
										// Radial
										circle = clamp(easeOutCubic	(length(float2(snowcoord.x*ratio-coord.x*ratio,snowcoord.y-coord.y))),0,1);
									
									}

									if (snow3 == 2)
									{
									// Stripe
										circle = clamp(circle + smoothstep(_LevelTex_TexelSize.y*(iter+invIter)*.1,_LevelTex_TexelSize.y*(iter+invIter),abs(textCoord.y-coord.y*rad)),0,1);
										
									}
									if (snow3 == 3)
									{
										// Column
										circle = clamp(circle + smoothstep(_LevelTex_TexelSize.x*(iter+invIter)*.1,_LevelTex_TexelSize.x*(iter+invIter),abs(textCoord.x-coord.x*rad)),0,1);
									}									
									if(snow3 == 4)		
									{
									snowIntensity = clamp(snowIntensity+ -lerp(1-snow2.z,1,circle)+1,0,1);
									snowNoise = clamp(snowNoise+ -lerp(1-snow2.w,1,circle)+1,0,1);
									}
									else{
									snowIntensity *= clamp(lerp(1-snow2.z,1,circle),0,1);
									snowNoise *= clamp(lerp(1-snow2.w,1,circle),0,1);
									}
					



				}
				input = -snowIntensity+1;
				input2 = -snowNoise+1;

				////////////////////////////////////////
				//////////////////////////////////     CREATURE MASK
				half mask = 100;
				half4 grabColor = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));

				if( grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
				mask = 5;
				///////////////////////////////////////////////////////
				// sample the texture
				float2 distUV=float2(textCoord.x,textCoord.y);
#if COMBINEDLEVEL // this end every following tag check is to make snow renderer ignore leveltexcombiner; To be removed otherwise, but needs more work for better integration.
				fixed4 color = tex2D(_OrigLevelTex, distUV);
#else 
				fixed4 color = tex2D(_LevelTex, distUV);
#endif
				float col = GetDepth(color.x);
				float thicOffset = 2+trunc((invIter-2)*clamp(input*1.5*noise0*.7,0,1));
				for(uint b = 0;b<invIter;b++)
				{
					if (b<thicOffset){
#if COMBINEDLEVEL
						col = max(col,GetDepth(tex2D(_OrigLevelTex, float2(distUV.x,distUV.y+_LevelTex_TexelSize.y*b)).x));
#else 
						col = max(col,GetDepth(tex2D(_LevelTex, float2(distUV.x,distUV.y+_LevelTex_TexelSize.y*b)).x));
#endif
					}

				}
				float col2 = 0;
				float col3 = col;
				float col4 = col;
				float col5 = col;
				float noise =tex2D(_NoiseTex,float2(distUV.x,distUV.y+col*.03)*4).x;
				float noise1 =tex2D(_NoiseTex,float2(distUV.x,distUV.y)*5).x;
				float noisemix = noise1-lerp(.25,.3,noise);
				float shadows = GetShadows(color);
				float height = clamp(lerp(input,input-noisemix-.15*(1-input),(.5-input*.5)+input2)*iter,0,iter);
				float snowMask = 1;
				float tex2 = 1;
				float tex3 = 1;
				float tsg = 0;
				float sg = 0;
				float tex = 0;
				for (uint c = 0;c<iter;c++)
				{
					if (c<height){
#if COMBINEDLEVEL
					float tex = tex2D(_OrigLevelTex, float2(distUV.x, distUV.y-_LevelTex_TexelSize.y*c)).x;
#else 
					float tex = tex2D(_LevelTex, float2(distUV.x, distUV.y-_LevelTex_TexelSize.y*c)).x;
#endif
					col2 = GetDepth(tex);
					/////////////////////EXPERIMENTAL SHIT
#if COMBINEDLEVEL
					tex2 = tex2D(_OrigLevelTex, float2(distUV.x-_LevelTex_TexelSize.x*trunc(c*.35), distUV.y-_LevelTex_TexelSize.y*c)).x;
					tex3 = tex2D(_OrigLevelTex, float2(distUV.x+_LevelTex_TexelSize.x*trunc(c*.35), distUV.y-_LevelTex_TexelSize.y*c)).x;
#else 
					tex2 = tex2D(_LevelTex, float2(distUV.x-_LevelTex_TexelSize.x*trunc(c*.35), distUV.y-_LevelTex_TexelSize.y*c)).x;
					tex3 = tex2D(_LevelTex, float2(distUV.x+_LevelTex_TexelSize.x*trunc(c*.35), distUV.y-_LevelTex_TexelSize.y*c)).x;
#endif
					col4 = min(col4,GetDepth(tex2));
					col5 = min(col5,GetDepth(tex3));
					col2 = max(col5,col2);
					col2 = max(col4,col2);
					////////////////////////END
					shadows = max(shadows,GetShadows(tex));
					col3 = min(col3,col2);
					sg=max(sg,(-step(tsg-col3,0.001)+1)*c);
					tsg=col3;
					}
				}
				col3 = trunc(col3);
				col = trunc(col);
				half shadowGradient = clamp(trunc((sg/height)*3)/3*0.3529,0,1);
				// half shadowGradient = clamp((trunc((sg/height)*3)-1)/765*30,0,1);
				// half shadowGradient = clamp(trunc(sg/(height*.3))*.4,0,1);
				// half shadowGradient = 0;
				if(col==col3) snowMask = 0;
				// if(col3>mask) snowMask = 0;
				// return (float4)shadowGradient+float4(0,0,0,1);
				return float4(clamp((col3+1)/255 + shadows*90/255+shadowGradient,0,1),snowMask,0,0)+float4(0,0,0,1);
			}
			ENDCG
		}
	}
}
