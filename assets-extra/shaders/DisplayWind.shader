Shader "Futile/DisplayWind"
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
			// sampler2D _GrabTexture : register(s0);
			// sampler2D _PalTex;
			// float _light = 0;
			float4 _tileCorrection;

			sampler2D _MainTex;
			sampler2D _WindTexRendered;
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


			fixed4 frag (v2f i) : SV_Target
			{


				
				///////////////////////////////////////////////////////
				// sample the texture
				float _input = i.clr.w*2-1;
				float _input2 = 1;
				float _input3 = 0;
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;
				// textCoord*=1+float2(0.02,0.04);
				// fixed watermask = smoothstep(_waterLevel,_waterLevel-.1,textCoord.y);
				textCoord = textCoord*float2(_tileCorrection.x,_tileCorrection.y)+float2(_tileCorrection.z,_tileCorrection.w);
				fixed edgemask = clamp(smoothstep(.40,.6,abs(textCoord - .5)),0,1);
				fixed4 col = tex2D(_WindTexRendered, textCoord);
				return 	smoothstep(.1,.9,col.x);	

			}
			ENDCG
		}
	}
}
