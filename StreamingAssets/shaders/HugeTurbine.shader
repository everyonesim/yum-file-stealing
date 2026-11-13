// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: Added clamps to the output to avoid unwanted transparency 	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/HugeTurbine" //Unlit Transparent Vertex Colored Additive 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
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

		SubShader   
		{
			GrabPass
			{
			}

			Pass
			{
				//SetTexture [_MainTex] 
				//{
				//	Combine texture * primary
				//}
				
				
				
				CGPROGRAM

				#pragma target 3.0
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				#include "_ShaderFix.cginc"
				#include "_RippleClip.cginc"

				//#pragma profileoption NumTemps=64
				//#pragma profileoption NumInstructionSlots=2048

				//float4 _Color;
				sampler2D _MainTex;
				sampler2D _LevelTex;
				//sampler2D _NoiseTex;
				sampler2D _PalTex;
				uniform float _fogAmount;
				//uniform float _waterPosition;

				#if defined(SHADER_API_PSSL)
				sampler2D _GrabTexture;
				#else
				sampler2D _GrabTexture : register(s0);
				#endif

				uniform float _RAIN;

				uniform float4 _spriteRect;
				uniform float2 _screenSize;


				struct v2f {
					float4 pos : SV_POSITION;
				    float2 uv : TEXCOORD0;
					float2 scrPos : TEXCOORD1;
					float4 clr : COLOR; // red = sprite rotation, alpha = depth
				};

				float4 _MainTex_ST;

				v2f vert (appdata_full v)
				{
					v2f o;
					o.pos = UnityObjectToClipPos (v.vertex);
					o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
					o.scrPos = ComputeScreenPos(o.pos);
					o.clr = v.color;
					return o;
				}

				float depthToDepthInLayers(float depth) {
					return (1.0 - depth) * 30;
				}

				float levelDepth(float2 position) {
					half4 terrainCol = tex2D(_LevelTex, position);
					half terrainDepth = ((int)round(terrainCol.x * 255) % 30) / 30.0;
					if (terrainCol.x == 1.0 && terrainCol.y == 1.0 && terrainCol.z == 1.0) { terrainDepth = 100; }

					return terrainDepth;
				}

				float levelDepthInLayers(float2 position) {
					return depthToDepthInLayers(levelDepth(position));
				}

				// returns whether a pixel is in shadow
				bool raymarchShadows(float3 initialPos, float2 lightDirection) {
					// ensures we do one march per pixel, so there's no shadow gaps :P
					float depthSteps = max(lightDirection.x * _screenSize.x, lightDirection.y * _screenSize.y);
					float stepSize = 1.0 / depthSteps;
					for (int iteration = 0; iteration < 100; iteration++) {
						float3 currentPos = initialPos + (float3(lightDirection.x, lightDirection.y, 1.0) * iteration * stepSize);
						float depth = levelDepthInLayers(currentPos.xy);

						// assume all pixels are 3 pixels thick...
						if (depth < currentPos.z && currentPos.z - depth < 2) {
							return true;
						}
						if (currentPos.z <= 0) {
							return false;
						}
					}

					return false;
				}

				half4 frag (v2f i) : SV_Target
				{
                    rippleClip(i.scrPos);
					half4 texcol = tex2D(_MainTex, float2(i.uv.x, i.uv.y));
					half depth = min((1.0 - texcol.r)*(5.0 / 30.0) + i.clr.a, 1.0);

					float2 levelPosition = float2(floor(i.scrPos.x*_screenSize.x) / _screenSize.x, floor(i.scrPos.y*_screenSize.y) / _screenSize.y);
					levelPosition.x -= _spriteRect.x;
					levelPosition.y -= _spriteRect.y;
					levelPosition.x /= _spriteRect.z - _spriteRect.x;
					levelPosition.y /= _spriteRect.w - _spriteRect.y;

					half4 terrainCol = tex2D(_LevelTex, levelPosition);
					half terrainDepth = ((int)round(terrainCol.x * 255) % 30) / 30.0;
					if (terrainCol.x == 1.0 && terrainCol.y == 1.0 && terrainCol.z == 1.0) { terrainDepth = 100; }

					if (terrainDepth < depth) discard;


					// self-shadowing
					float2 shadowUVOffset = float2(-0.005, 0.015);
					float spriteAngle = (i.clr.r) * 2.0f * 3.141592f;
					shadowUVOffset = float2(
						shadowUVOffset.x * cos(spriteAngle) - shadowUVOffset.y * sin(spriteAngle),
						shadowUVOffset.x * sin(spriteAngle) + shadowUVOffset.y * cos(spriteAngle)); // rotate the UV offset

					half4 texcol2 = tex2D(_MainTex, float2(i.uv.x, i.uv.y) + shadowUVOffset);
					half depth2 = min((1.0 - texcol2.r)*(5.0 / 30.0) + i.clr.a, 1.0);

					bool inShadow = depth2 < depth;

					// terrain shadowing
					if (!inShadow) {
						float shadowLength = 3.0; // in pixels
						inShadow = raymarchShadows(float3(levelPosition.x, levelPosition.y, depthToDepthInLayers(depth)), float2(-shadowLength / _screenSize.x, shadowLength / _screenSize.y));
					}

					float paletteOffset = 3.0;
					if (inShadow) paletteOffset = 0.0;

					half4 returnCol = tex2D(_PalTex, half2(lerp(0.5, 29.5, depth) / 32.0, lerp(paletteOffset + 0.5, paletteOffset + 2.5, texcol.z) / 8.0));
					returnCol = lerp(returnCol, tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0)), depth*_fogAmount);

					return float4(returnCol.r, returnCol.g, returnCol.b, texcol.a);
				}

				ENDCG
				
				
				
			}
		} 
	}
}
