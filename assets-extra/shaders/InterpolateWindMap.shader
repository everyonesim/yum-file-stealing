Shader "Futile/InterpolateWindMap"
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
		Blend Off
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
				float2 textCoord[4] : TEXCOORD2;
			};
			// sampler2D _GrabTexture : register(s0);
			// sampler2D _PalTex;
			// float _light = 0;
			float4 _tileCorrection;

			sampler2D _MainTex;
			sampler2D _WindTex;
			float2 _WindTex_TexelSize;
			sampler2D _TileTex;
			float2 _TileTex_TexelSize;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			float2 _LevelTex_TexelSize;
			// float4 _lightDirAndPixelSize;
			float2 _screenSize;
			float4 _spriteRect;
			float _waterLevel;
			float _windAngle;
			float _windStrength;
			// float4 _EffectColor;
			// float _WetTerrain;
			// float _waterLevel;
			float _RAIN;
			// float _cloudsSpeed;
			// float _fogAmount;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				o.textCoord[0] = float2(floor(o.scrPos.x*_screenSize.x)/_screenSize.x, floor(o.scrPos.y*_screenSize.y)/_screenSize.y);
				o.textCoord[0].x -= _spriteRect.x;
				o.textCoord[0].y -= _spriteRect.y;

				o.textCoord[0].x /= _spriteRect.z - _spriteRect.x;
				o.textCoord[0].y /= _spriteRect.w - _spriteRect.y;
				o.textCoord[0] = o.textCoord[0]*float2(_tileCorrection.x,_tileCorrection.y)+float2(_tileCorrection.z,_tileCorrection.w)+_WindTex_TexelSize*.5;
				o.textCoord[1] =o.textCoord[0]-float2(_WindTex_TexelSize.x,0);
				o.textCoord[2] =o.textCoord[0]-float2(0,_WindTex_TexelSize.y);
				o.textCoord[3] =o.textCoord[0]-float2(_WindTex_TexelSize.x,_WindTex_TexelSize.y);
				

				return o;
			}
			float decode (float4 byte, int depth)
            {
				
				int channel = floor((float)depth / 24);
				float b = (channel == 0)?byte.x:(channel == 1)?byte.y:(channel == 2)?byte.z:byte.w;
				depth = (int)fmod((float)depth, 24);
                float result = 0;
                int sas = b*4294967295;
                // if ((sas>>depth) & (1<<depth)!=0)
                // {
                //     result = 1;
                // }
				result = ((sas >> depth & 1) !=0)? 1:result;
                return result;
            }


			float4 frag (v2f i) : SV_Target
			{
				fixed4 result = 0;
				float2 pixel = i.textCoord[0]*(1/_WindTex_TexelSize);
				pixel = frac(pixel);
				float sangle = clamp(((_windAngle*.25*_windStrength*.5 + 0.2) * 240),0,95)-.5;
				float wangle = clamp(((_windAngle*.25 + 0.2) * 240),0,95)-.5;
				float sanglefrac = frac(sangle);
				float wanglefrac = frac(wangle);
				float4 col = tex2D(_WindTex, i.uv);
				float tiles = tex2D(_TileTex,i.uv);
				fixed smask = 0;
				fixed smask1 = 0;
				float witer = 45;
				float siter = 11;
				fixed asmask[11];
				fixed wmask = 0;
				fixed wmask1 = 0;
				fixed awmask[45];
				[unroll]
				for(int s = 0; s<siter; s++)
				{
					int sangle2 = clamp((sangle-(siter-1)*.5+s),0,95);
					asmask[s]=decode(col,sangle2);
				}
				[unroll]
				for (int k = 0; k <witer;k++)
				{
					int wangle2 = clamp((wangle-(witer-1)*.5+k),0,95);
					awmask[k]=decode(col,wangle2);
				}
				[unroll]
				for (int d = 1; d <(siter-1);d++)
				{
					smask+=asmask[d];
				}
				[unroll]
				for (int j = 1; j <(witer-1);j++)
				{
					wmask+=awmask[j];
				}
				smask1=smask;
				smask1+=asmask[(siter-1)];
				smask+=asmask[0];
				smask = lerp(smask,smask1,sanglefrac);
				// smask = smoothstep(0,20,smask);
				smask /= (siter-1);
				wmask1=wmask;
				wmask1+=awmask[(witer-1)];
				wmask+=awmask[0];
				wmask = lerp(wmask,wmask1,wanglefrac);
				// wmask = smoothstep(0,20,wmask);
				wmask /= (witer-1);
				// float x1 = lerp(smaskU, smask, pixel.x);
				// float x2 = lerp(smaskUR, smaskR, pixel.x);
				// smask = lerp(x2,x1,pixel.y);
				return fixed4(tiles.x,smask,wmask,0);


			}
			ENDCG
		}
	}
}
