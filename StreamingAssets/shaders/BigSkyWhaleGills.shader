Shader "Futile/BigSkyWhaleGills"
{
	Properties
	{
		_MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
	}

	Category
	{
		Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off

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
				#include "_RippleClip.cginc"

				sampler2D _MainTex;
				sampler2D _NoiseTex;
				sampler2D _PalTex;

				struct v2f {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
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

				half4 frag(v2f i) : SV_Target
				{
					rippleClip(i.scrPos);

					float rightWave = 1.0 - 0.7 * abs(sin(i.uv.y * 150.0));
					float leftWave = 0.5 * abs(sin(i.uv.y * 150.0)) - 0.1;
					float darkness = max(
						pow(max(0, i.uv.x - rightWave), 0.7),
						pow(max(0, leftWave - i.uv.x), 0.7)
					);

					if (i.uv.x > 1 - abs(sin(i.uv.y * 150.0)) * 0.1
						|| abs(i.uv.y - 0.5) > 0.4 + sqrt(i.uv.x - i.uv.x * i.uv.x) * 0.05)
					{
						discard;
					}

					half3 red = half3(0.25, 0.18, 0.17);
					half3 black = half3(0.09, 0.06, 0.07);
					half3 color = lerp(red, black, darkness);
					color.r += darkness * (1 - darkness) * 0.05;
					return half4(color,1);
				}
				ENDCG
			}
		}
	}
}
