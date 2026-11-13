// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'


// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/GrappleSnake" //Unlit Transparent Vertex Colored Additive 
{
	Properties
	{
		_MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
	}

	Category
	{
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		ZWrite Off
		//Alphatest Greater 0
		Blend SrcAlpha OneMinusSrcAlpha
		Fog{ Color(0,0,0,0) }
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
			Pass
			{
				CGPROGRAM

				#pragma target 3.0
				#pragma vertex vert
				#pragma fragment frag
				#include "UnityCG.cginc"
				#include "_ShaderFix.cginc"

				sampler2D _MainTex;
				sampler2D _NoiseTex;
				sampler2D _PalTex;

				struct v2f {
					float4  pos : SV_POSITION;
					float2  uv : TEXCOORD0;
					float2 scrPos : TEXCOORD1;
					float4 clr : COLOR;
				};

				float4 _MainTex_ST;

				v2f vert(appdata_full v)
				{
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					o.scrPos = ComputeScreenPos(o.pos);
					o.clr = v.color;
					return o;
				}

				half map(half value, half min1, half max1, half min2, half max2) {
					return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
				}

				half4 frag(v2f i) : SV_Target
				{
					half x = i.uv.x;
					half bodyCoordinates = abs(x - 0.5) * 2.0;
					half noise = tex2D(_NoiseTex, half2(i.uv.y * 5.0, 0)).x;
					noise = abs(noise - 0.5) * 2.0;

					half hairyNoiseIntensity = 0.3;
					half hairyNoise = tex2D(_NoiseTex, half2(i.uv.y * 30.0, 0)).x;
					hairyNoise = (abs(hairyNoise - 0.5) * 2.0);
					hairyNoise = (hairyNoise * 2.0) - 1.0;
					noise += hairyNoise * hairyNoiseIntensity;

					noise = map(noise, -hairyNoiseIntensity, 1.0 + hairyNoiseIntensity, 0.65, 1.0);

					if (bodyCoordinates > noise) discard;

					half stripesuv = sqrt(i.uv.y) * 6.0;
					half stripesNoise = (tex2D(_NoiseTex, half2(0, stripesuv)).x * 2.0) - 1.0;
					half freq = 0.5;
					stripesNoise += ((tex2D(_NoiseTex, half2(i.uv.x * freq, i.uv.y * freq)).x * 2.0) - 1.0) * 0.2;

					half freq2 = 1;
					stripesNoise += ((tex2D(_NoiseTex, half2(i.uv.x * freq2, i.uv.y * freq2)).x * 2.0) - 1.0) * 0.2;

					stripesNoise *= -1.0;

					half vdarken = (0.8 - i.uv.y);
					stripesNoise -= vdarken * vdarken * vdarken;

					half4 color = half4(1.0, 1.0, 1.0, 1.0);
					half4 paletteBlack = tex2D(_PalTex, half2(2.5, 8.0 - 0.5) / half2(32.0, 8.0));

					if (stripesNoise < 0) color = paletteBlack;

					return color;
				}

				ENDCG
			}
		}
	}
}






















