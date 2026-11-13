Shader "Futile/DustWaveLevelLow"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="AlphaTest" "IgnoreProjector"="False" "RenderType"="TransparentCutout"}
		ZWrite On
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
                float2 data[10] : TEXCOORD2;
				

			};
			#if defined(SHADER_API_PSSL)
			sampler2D _GrabTexture;
			#else
			sampler2D _GrabTexture : register(s0);
			#endif
			// sampler2D _PalTex;
			// float _light = 0;
			float4 _tileCorrection;
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
			sampler2D _CloudsTex;
			// float _cloudsSpeed;
			// float _fogAmount;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;
			sampler2D _DustFlowTex;
			float2 _DustFlowTex_TexelSize;
			float GetDepth2 (float a)
			{
				if (a>0.3529411764705882) return 255;
				a=a*254;
				return fmod(a, 30);
			}
			 float2 quadifyUV(float2 uv)
            {
                if(_DustFlowTex_TexelSize.x>_DustFlowTex_TexelSize.y)
                {
                    return float2(uv.x*(_DustFlowTex_TexelSize.y/_DustFlowTex_TexelSize.x),uv.y);
                }else{
                    return float2(uv.x,uv.y*(_DustFlowTex_TexelSize.x/_DustFlowTex_TexelSize.y));
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
				float t = _RAIN;
				float2 textCoord = float2(floor(o.scrPos.x*_screenSize.x)/_screenSize.x, floor(o.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;

				fixed2 tileCorrection = fixed2(_tileCorrection.z,_tileCorrection.w);

				o.data[0]=fixed2(t,t*.3)*.4;
                o.data[1]=fixed2(.123,-t*.2+.311);
                o.data[2]=fixed2(t*1.8,-0.1);
                o.data[3]=textCoord;
                o.data[4]=half2(o.scrPos.x, o.scrPos.y);
                o.data[5]=o.data[3]*2+fixed2(-t*.05+.5*.1,t*.1)+tileCorrection;
                o.data[6]=o.data[3]*2+fixed2(+t*1.5+.5*.1,t*.1)+tileCorrection;
                o.data[7]=o.data[3]*3*fixed2(.571,.891-.5*.1)+o.data[1]+tileCorrection;
				o.data[8]=o.data[3]*3*fixed2(.371,.891-.5*.1)+o.data[2]+tileCorrection;
				o.data[9]=o.data[3]*fixed2(_tileCorrection.x,_tileCorrection.y)+fixed2(_tileCorrection.z,_tileCorrection.w);
				return o;
			}
			float EaseInExpo(float t) {return (t == 0.0) ? 0.0 : pow(2.0, 10.0 * (t - 1.0));}
			float EaseOutQuad(float t) {return -1.0 * t * (t - 2.0);}
			float EaseInQuad(float t) {return t * t;}
			float EaseInCubic(float t) {return t * t * t;}
			fixed4 frag (v2f i) : SV_Target
			{


				
				///////////////////////////////////////////////////////
				// sample the texture
				float t = _RAIN;
                float2 uv= quadifyUV(i.uv);
				fixed4 levelTex = tex2D(_LevelTex,i.data[3]);
				float sky = 0;
                if(levelTex.x*255>90)
				{
				sky = .1;
                levelTex.x-=0.3529411764705882;
				}
				fixed depth = GetDepth2(levelTex.x);
				half4 grabTexCol = tex2D(_GrabTexture, i.data[4]);
                if (depth<1) return 0;
				if(levelTex.x>0.3529411764705882) depth=255;
				if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0) depth = 7;
				depth*=.03;


				fixed3 flow = tex2D(_DustFlowTex,i.data[9]).xyz;
				fixed2 dustFlow = flow.xz;
				fixed noise1 = tex2D(_NoiseTex,fixed2(dustFlow.x,dustFlow.y)*fixed2(2,4)+i.data[0]).x;
				fixed mask2 = smoothstep(i.clr.x+.02,i.clr.x+.02+.5*.3,dustFlow.x+smoothstep(0.9,1,dustFlow.y)*.1);
				fixed mask3 = smoothstep(i.clr.x,i.clr.x+.1,dustFlow.x+smoothstep(0.9,1,dustFlow.y)*.1);
				mask3 = clamp(mask3,0,1)*.2;
				fixed2 tileCorrection = fixed2(_tileCorrection.z,_tileCorrection.w);
				fixed noise3 = tex2D(_CloudsTex,i.data[5]).x;
				fixed windNoise1 = tex2D(_CloudsTex,i.data[6]).x;
				fixed noise4 = tex2D(_CloudsTex,i.data[7]).x;
				fixed windNoise2 = tex2D(_CloudsTex,i.data[8]).x;
				fixed noisemix = smoothstep(.5,1.5,lerp(noise3+noise4,windNoise1+windNoise2,(flow.y+sky)*(1-i.clr.x)));
				
				fixed4 result = smoothstep(-.5,2,noisemix+.5)*fixed4(.44,.36,.37,1);
				fixed4 result2 = fixed4(0.176,0.144,0.148,1)+.5*fixed4(0.132,0.108,0.111,1);
				fixed mask = smoothstep(0,1-noisemix.x*.8,depth+mask2*.4)*step(i.clr.x+(1-result.x)*.1,dustFlow.x+smoothstep(0.9,1,dustFlow.y)*.1);
				result = lerp(result2,fixed4(result.xyz,1),mask);
				return fixed4(result.xyz,mask2*depth);	
				// return fixed4(result,depth*smoothstep(0+i.clr.x,.1+i.clr.x,dustFlow.x));	
				// return fixed4(depth,depth,depth,1);
			}
			ENDCG
		}
	}
}
