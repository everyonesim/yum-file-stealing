Shader "Futile/CellDist"
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
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
		GrabPass { }
		Pass
		{
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
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
			// sampler2D _PalTex;
			// float _light = 0;
			sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			float2 _LevelTex_TexelSize;
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
			sampler2D _UniNoise;

			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			float3 rgb2hsv(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
				float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}
			//                                                                      HSV  2  RGB
			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}

			float pulse(float pos, float width, float x){x = smoothstep(1.-width,1.,1.-abs((x-pos)));return x;}
			float3 cell(float2 st, float t, float res,  float2 offset, float color)
			{
			st = (st*res);
			float2 fr = frac(st)-offset;
			float2 fl = floor(st)+offset;
			float2 random = float2(tex2D(_UniNoise,(fl*0.0333)).xz);
			// float random2 = tex2D(_UniNoise,(fl*2.333)+t*.01).y;
			// random2*=color;
			random = float2(sin((random.x*2-1)*t),cos((random.y*2-1)*t))/3.24159;
			// random = float2(sin(random.x*t+random2),cos(random.y*t-+random2))/3.24159;
			return float3(distance(random,fr),random);
			}

			float3 CellNoise(float2 uv,float t, float4 input)
			{
				t=(t)*10*input.w+77.5;
				uv = uv*2.-1.;
				float dist = clamp(1.-distance(uv,float2(0,0)),0.,1.)*input.x;
				// dist = pulse(0.5,0.5,dist);
				float cells = 1.;
				float2 randoms = float2(0.,0);
				// float cells = cell(st,t,5.,vec2(0.));
				for(int j = -1; j<2;j++)
				for(int k = -1; k<2;k++)
				{
					// if(k!=0||j!=0)
					// {
						float3 temp = cell(uv-normalize(uv),t,26.0*input.y,float2(j,k),input.w);
						if (cells>temp.x)
						{
							cells = temp.x;
							randoms = temp.yz;
						}
						else
						{
							cells = cells;
						}
						
						// cells = min(cells,cell(st,t,6.0,vec2(j,k)));
					// }
				}
				return float3((1.-cells)*7.*pulse(0.4+randoms.y*.5,0.4+randoms.x*.5,dist)*dist,normalize(randoms.xy+cells*.05)*dist*.1);
			}



			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv*2-1;
				float2 textCoord =abs(float2(i.scrPos.x,i.scrPos.y));
				float dist = pulse(0.6,.4,length(uv));
				float3 cl = CellNoise(i.uv,_RAIN*3,i.clr)*dist;
				float2 dist2 = cl.yz*12*dist*i.clr.z;				
				float3 color = tex2D(_GrabTexture,textCoord+cl.yz).xyz;
				color = float4(hsv2rgb(rgb2hsv(color.xyz)+float3(dist2.x,dist2.y,0)),1.);

				return float4(color+color*cl.y*4,1);
			}
			ENDCG
		}
	}
}
