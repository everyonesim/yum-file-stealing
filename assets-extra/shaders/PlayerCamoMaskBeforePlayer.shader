Shader "Futile/PlayerCamoMaskBeforePlayer"
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
        GrabPass {"_PlayerCamoMaskBeforePlayer"}
        pass    
        {
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
			#include "_Functions.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float2 scrPos : TEXCOORD1;
                float4 clr : COLOR0;
			};
			sampler2D _MainTex;
            sampler2D _GameplayRippleMask;
			float4 _MainTex_ST;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos).xy;
				o.clr = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                fixed sprite = tex2D(_MainTex,i.uv).w;
                return fixed4(i.clr.xyz,sprite*i.clr.w);
			}
            ENDCG
		}
    }
}
