Shader "Futile/SavePlayerCamoMask"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
        _Offset ("Offset" ,vector) = (0.0,0.0,0.0,0.0)
	}
	SubShader
	{
		// Tags {"Queue"="Opaque" "IgnoreProjector"="False" "RenderType"="Opaque"}
		ZWrite Off
		//Alphatest Greater 0
		Blend  Off
		Lighting Off
		Cull Off 
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
			sampler2D _PlayerCamoMask;
			sampler2D _PlayerCamoMaskBeforePlayer;
            float4 _Offset;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos)+_Offset*fixed4(.735,-.91,1,1);
				return o;
			}

            fixed diff(fixed3 a, fixed3 b){
                return saturate(step(0.0039215686,abs(a-b)));
            }

			fixed4 frag (v2f i) : SV_Target
			{
                if (i.scrPos.x<=0 || i.scrPos.x >=1 || i.scrPos.y <= 0 || i.scrPos.y >= 1)
                    return 0;
                fixed4 player = tex2D(_PlayerCamoMask,i.scrPos);
                fixed4 stuffBefore = tex2D(_PlayerCamoMaskBeforePlayer,i.scrPos);
                fixed mask = diff(player,stuffBefore);
                return player*mask;
			}
			ENDCG
		}
	}
}
