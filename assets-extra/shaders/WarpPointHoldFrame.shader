Shader "Futile/WarpPointHoldFrame"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// Tags {"Queue"="Opaque" "IgnoreProjector"="False" "RenderType"="Opaque"}
		ZWrite Off
		//Alphatest Greater 0
		Blend  Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
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
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
			};
			sampler2D _WarpPointGrabPass;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
                return fixed4(tex2D(_WarpPointGrabPass,i.scrPos).xyz,1);
			}
			ENDCG
		}
	}
}
