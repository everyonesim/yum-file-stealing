Shader "Futile/DustFlowRenderer"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		 Tags { "RenderType"="Opaque" }
		ZWrite Off
		//Alphatest Greater 0
		Fog { Color(0,0,0,0) }
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
			#pragma exclude_renderers OpenGL
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"


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
                float2 data[8] : TEXCOORD2;

			};
			// sampler2D _GrabTexture : register(s0);
			// sampler2D _PalTex;
			// float _light = 0;
			sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			float2 _LevelTex_TexelSize;
			sampler2D _UniNoise;

			// float4 _lightDirAndPixelSize;
			float2 _screenSize;
			float4 _spriteRect;
			// float4 _EffectColor;
			// float _WetTerrain;
			// float _waterLevel;
			float _RAIN;
			// float _cloudsSpeed;
			// float _fogAmount;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;
			float _firstPass;
			float _topBottom;
			float _step;
			 float2 quadifyUV(float2 uv)
            {
                if(_MainTex_TexelSize.x>_MainTex_TexelSize.y)
                {
                    return float2(uv.x*(_MainTex_TexelSize.y/_MainTex_TexelSize.x),uv.y);
                }else{
                    return float2(uv.x,uv.y*(_MainTex_TexelSize.x/_MainTex_TexelSize.y));
                }
            }
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				float2 off = _MainTex_TexelSize;
                float2 percent = off*40;
				if(_firstPass>.75)
                {
					float2 uv = o.uv*(1+percent)-percent*.5;
               		// o.uv = uv-off*.5;
               		o.uv = uv;
				}
                 o.data[0]=o.uv+float2(0,off.y);
                o.data[1]=o.uv-float2(0,off.y);
                o.data[2]=o.uv+float2(off.x,0);
                o.data[3]=o.uv-float2(off.x,0);
                o.data[4]=o.uv-float2(off.x,off.y);
                o.data[5]=o.uv+float2(off.x,off.y);
                o.data[6]=o.uv-float2(-off.x,off.y);
                o.data[7]=o.uv+float2(-off.x,off.y);
				return o;
			}
				float step2(float2 a, float2 b)
            {
                return max(step(a.x,b.x),step(a.y,b.y));
            }
			float Slice(float pos, float width, float x){x = smoothstep(1.-width,1.,1.-abs((x-pos)));return x;}

			float drawShadow(float2 pt, float2 uv,float dist)
			{
				float shadow = 1;
                // dist = 0.04;
				dist*=128;
                // dist*=dist;
				float2 norm = normalize(uv-pt);
				float2 nuv = uv-norm*float2(_MainTex_TexelSize.x,_MainTex_TexelSize.y)*dist*2;
				// float sh = abs(nuv.x-.5)>.5||abs(nuv.y-.5)>1?1.0:tex2D(_MainTex,nuv).x;
				float sh = abs(nuv.x-.5)>.5||abs(nuv.y-.5)>1?1.0:tex2D(_MainTex,nuv).y;
				shadow = min(shadow,sh);
				// shadow = sh;
				
				return clamp(shadow,0,1);
			}
			float2 Quantize(in float2 coord, in float2 res, int updoown)
			{
				if (updoown =0)
				{
				coord = ((floor((coord)*res)+0.5)/res);
				}
				else
				{
				coord = ((ceil((coord)*res)+0.5)/res);
				}
			return coord;
			}
			fixed4 frag (v2f i) : SV_Target
			{
				///////////////////////////////////////////////////////
				float4 dCoord = 0;
                float4 tex = tex2D(_MainTex, i.uv);
				if(_firstPass<.25)
                {
					float sas = 0;
					sas = max(sas,tex2D(_MainTex, i.data[0]).x);
					sas = max(sas,tex2D(_MainTex, i.data[1]).x);
					sas = max(sas,tex2D(_MainTex, i.data[2]).x);
					sas = max(sas,tex2D(_MainTex, i.data[3]).x);
					sas = max(sas,tex2D(_MainTex, i.data[4]).x);
					sas = max(sas,tex2D(_MainTex, i.data[5]).x);
					sas = max(sas,tex2D(_MainTex, i.data[6]).x);
					sas = max(sas,tex2D(_MainTex, i.data[7]).x);
               		tex = float4(sas,tex.y,tex.z,tex.w);;
					return tex;
				}
				
				float windMap = tex.y;
				 if(_firstPass>0.5)
                {
                    windMap = 1;
                }
				 if(tex.y>0)
				{
                    tex.y = 1;
                }
				
				dCoord += tex2D(_MainTex,i.data[0]);
                dCoord += tex2D(_MainTex,i.data[1]);
                dCoord += tex2D(_MainTex,i.data[2]);
                dCoord += tex2D(_MainTex,i.data[3]);
                dCoord += tex2D(_MainTex,i.data[4]);
                dCoord += tex2D(_MainTex,i.data[5]);
                dCoord += tex2D(_MainTex,i.data[6]);
                dCoord += tex2D(_MainTex,i.data[7]);



                float u = tex.x;
                float v = tex.z;
				float coof = .1;
				 if(dCoord.x*coof*tex.y>0)
                {
                    if(u<1)
                    {
                        u+=0.00392156862745;
                    }
                }
                // if((tex2.z+tex3.z+tex4.z+tex5.z)*.25>0)
                if(dCoord.z*coof>0)
                {
                    if(v<1)
                    {
                        v+=0.003921568627451;
                    }
                }
                    float shadow = 0;
               float2 wndP = 0;
               int sas = 20;
               for (int k = 0;k<sas;k++)
				{
					wndP = lerp(float2(15,-15),float2(15,15),k/float(sas));
					// wndP = float2(100,-160);
                    shadow += drawShadow(wndP,i.uv,_step);
				}
                
                shadow = clamp(smoothstep(0,.5,shadow/float(sas)),0,1);
                shadow = min(shadow,windMap-.03);

                tex = float4(u*tex.y,(shadow+.03)*tex.y,v,tex.w);
				 if(_firstPass>.5)
                {
				}
                if(_firstPass>.5)
                {
					float sos = 0;
					sos = tex2D(_MainTex, i.uv).x;
					sos = max(sos,tex2D(_MainTex, i.data[2]).x);
                    tex = tex2D(_MainTex, i.uv);
					float4 specks = tex2D(_UniNoise,quadifyUV(i.uv)*0.3);
					// float noise = max(step(1-_MainTex_TexelSize.y*10,lerp((1-i.uv.y),i.uv.y,_topBottom)),step(1-_MainTex_TexelSize.x*10,i.uv.x))*tex.x*Slice(.9,.1,specks.x+specks.y);
					float2 dirtex = float2(0,0);
					if (_topBottom<.1)
					{
					dirtex.y=_MainTex_TexelSize.y;
					dirtex.x= i.uv.y;
					}
					else if (_topBottom<.2)
					{
					dirtex.y=_MainTex_TexelSize.x;
					dirtex.x = i.uv.x;
					}
					else if (_topBottom<.3)
					{
					dirtex.y=_MainTex_TexelSize.y;
					dirtex.x = 1-i.uv.y;
					}else if (_topBottom<.4)
					{
					dirtex.y=_MainTex_TexelSize.x;
					dirtex.x = 1-i.uv.x;
					}else if (_topBottom<.5)
					{
					dirtex.y=_MainTex_TexelSize.x;
					dirtex.x = abs(i.uv.x*2-1);
					}
					else
					{
					dirtex.y=_MainTex_TexelSize.y;
					dirtex.x = abs(i.uv.y*2-1);
					}
					// float noise = step(1-dirtex.y*4,dirtex.x)*tex.x;
					float noise = step(1-dirtex.y*10,dirtex.x)*tex.x*Slice(.9,.1,specks.x+specks.y);
                    // float border = step2(1-_MainTex_TexelSize.xy*10,abs(i.uv*2-1));
                    // tex = float4(tex.x*border,sos,1-tex.x,1);
                    tex = float4(tex.x,sos,1-tex.x,1);
					tex.x=noise;
                }
				if(_firstPass>.75)
				{
                    tex = tex2D(_MainTex, i.uv);
				}
				return tex;
			}
			ENDCG
		}
	}
}
