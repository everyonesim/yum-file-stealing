Shader "Futile/BlizzardMap"
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
			};
			// sampler2D _GrabTexture : register(s0);
			// sampler2D _PalTex;
			// float _light = 0;
			float4 _tileCorrection;

			sampler2D _MainTex;
			sampler2D _TileTex;
			float2 _TileTex_TexelSize;
			float2 _MainTex_TexelSize;
			float4 _windAngle;
			float4 _snowVector;
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
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			float2 getVector(float degAng)
			{
				degAng *= -0.0174532924;
				float2 vec =float2(0,100);
				return float2(cos(degAng) * vec.x - sin(degAng) * vec.y, sin(degAng) * vec.x + cos(degAng) * vec.y);
			}
			
			float drawShadow(float2 pt, float2 uv,float dist)
			{
				float shadow = 1;
				for (int i = 0;i<(1/max(_TileTex_TexelSize.x,_TileTex_TexelSize.y))*8;i++)
				{
				float2 norm = normalize(uv-pt);
				float2 nuv = uv-norm*float2(_TileTex_TexelSize.x,_TileTex_TexelSize.y)*i;
				float sh = abs(nuv.x-.5)>.5||abs(nuv.y-.5)>1?1.0:tex2D(_TileTex,nuv).x;
				shadow = min(shadow,sh);
				}
				return clamp(step(.5,shadow),0,1);
			}

			float encode (float target, fixed mask, int depth)
            {
                int sas = target*4294967295;
                if(mask>.5)
                {
                    sas |= 1<<depth;
                }
                target = float(sas)/4294967295;
                return target;
            }

            float decode (float byte, int depth)
            {
                float result = 0;
                int sas = byte*4294967295;
                if ((sas>>depth) & (1<<depth)!=0)
                {
                    result = 1;
                }
                return result;
            }

			float4 frag (v2f i) : SV_Target
			{

				if (_TileTex_TexelSize.x*_TileTex_TexelSize.y == 0)
				return fixed4(0,1,0,1);
				
				///////////////////////////////////////////////////////
				// sample the texture
				float2 textCoord = i.uv;
				// fixed col = tex2D(_TileTex, textCoord);

				float4 wind = float4(0,0,0,0);
				float wndP;
				for (int k = 0;k< 24;k++)
				{
					wndP = lerp(-.7,.7,float(k)/96)*120;
					wind.x = encode(wind.x,drawShadow(getVector(wndP),textCoord,0),k);
				}
				for (int j = 0;j< 24;j++)
				{
					wndP = lerp(-.7,.7,float(j+24)/96)*120;
					wind.y = encode(wind.y,drawShadow(getVector(wndP),textCoord,0),j);
				}
				for (int h = 0;h< 24;h++)
				{
					wndP = lerp(-.7,.7,float(h+48)/96)*120;
					wind.z = encode(wind.z,drawShadow(getVector(wndP),textCoord,0),h);
				}
				for (int c = 0;c< 24;c++)
				{
					wndP = lerp(-.7,.7,float(c+72)/96)*120;
					wind.w = encode(wind.w,drawShadow(getVector(wndP),textCoord,0),c);
				}

				return fixed4(wind.x,wind.y,wind.z,wind.w);	
			}
			ENDCG
		}
	}
}
