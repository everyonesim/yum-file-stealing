Shader "Futile/OESphereTop"
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
		Blend One OneMinusSrcAlpha 
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
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}
			float GetDepth(float a) {
				if (a == 1.0) return 255;
				a = round(a * 255);
				float shadows = (step(a, 90) * -1 + 1) * 90;
				return fmod(a - shadows - 1, 30);
			}
			float lightness(float4 t) {
				// return (t.x + t.y + t.z) * .333;
				
				return max(max(t.x,t.y),t.z);
			}
			float ShEaseInCubic(float t) {
				return t * t * t;
			}
			float ShEaseOutQuad(float t) {
					return -1.0 * t * (t - 2.0);
				}
			fixed4 frag (v2f i) : SV_Target
			{
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;

				float2 scrTex = i.scrPos.xy/i.scrPos.w;
				scrTex = float2(scrTex.x,1-scrTex.y);	
				fixed4 spherecolor1 = fixed4(1, .52, .25, 1);
				fixed4 spherecolor2 = fixed4(.5, 0, 1, 1);
				int depth = 30 * i.clr.w;
				fixed levelDepth = GetDepth(tex2D(_LevelTex, textCoord).x);
				fixed depthMask = 1 - step(levelDepth, depth);
				fixed4 color1 = fixed4(1, .52, .25, 1);
				float2 uv = i.uv * 2 - 1;
				float basecircle = length(uv);
				float falloff = ShEaseInCubic(smoothstep(1, .02, basecircle) * 2 - 1) - .1;
				float circle = ShEaseInCubic(smoothstep(0.08, 0.35, basecircle) - smoothstep(0.3470, 0.351, basecircle));
				float rim = ShEaseInCubic(smoothstep(0.25, 0.35, basecircle) - smoothstep(0.3470, 0.351, basecircle)) * .6;
				float2 distCoord = scrTex - normalize(uv * float2(.5, 1)) * float2(-falloff, falloff);
				distCoord.y = 1 - distCoord.y;


				// REPEATING THE TE$XTURECOORDINATE DOES NOT SOLVE THE PROBLEM
				// distCoord = float2((distCoord.x+_spriteRect.x)/(_spriteRect.z+_spriteRect.x),(distCoord.y+_spriteRect.y)/(_spriteRect.w+_spriteRect.y));
				// distCoord = float2(fmod(distCoord.x+2,1),distCoord.y);
				// distCoord = float2((distCoord.x*(_spriteRect.z+_spriteRect.x))-_spriteRect.x,(distCoord.y*(_spriteRect.w+_spriteRect.y))-_spriteRect.y);
				// REPEATING THE TE$XTURECOORDINATE DOES NOT SOLVE THE PROBLEM


				fixed4 col = tex2D(_GrabTexture, distCoord) * smoothstep(0, .2, circle);
				// return col;

				// try (distcoord.x+_spriteRect.x)/(_spriteRect.z+_spriteRect.x);
				// try fmod(distcoord.x,1);
				// try (distcoord.x*(_spriteRect.z+_spriteRect.x))-_spriteRect.x;
				// fixed4 col2 = tex2D(_GrabTexture, fixed2(textCoord.x,1-textCoord.y));
				// return col2;
				// return fixed4((col * lightness(col) * circle + rim * color1) * depthMask);
				// return fixed4((col * ShEaseOutQuad(lightness(col))* (1-lightness(col2)) * circle ) * depthMask);
				fixed4 result  = fixed4((col * ShEaseOutQuad(lightness(col))* circle ) * depthMask);
				return fixed4(result.xyz*result.w,result.w);
			}
			ENDCG
		}
	}
}
