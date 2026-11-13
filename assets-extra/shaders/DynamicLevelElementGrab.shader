Shader "Futile/DynamicLevelElementGrab"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Lighting Off
        Cull Off 
        GrabPass {"_DynamicLevelElements"}
        Pass {
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

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
                return fixed4(0,0,0,1);
			}
			ENDCG
            }
    }
}
