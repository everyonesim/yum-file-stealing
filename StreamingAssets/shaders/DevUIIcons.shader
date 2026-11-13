Shader "Futile/DevUIicons" 
{

	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite Off
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
            #pragma multi_compile_local _ twin_arrow_vertical twin_arrow_horizontal
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
				float2 scrPos : TEXCOORD1;
                float4 clr : COLOR0;
			};
			sampler2D _MainTex;
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
                fixed shape = 0;
                i.uv = i.uv*2-1;
                i.uv = abs(i.uv);

                #if twin_arrow_horizontal
                    shape = step(i.uv.y,(1-i.uv.x));
                    shape *= step(.4,i.uv.x);
                    shape += step(i.uv.y,.15)*step(i.uv.x,.7);
                #elif twin_arrow_vertical
                    shape = step(i.uv.x,(1-i.uv.y));
                    shape *= step(.4,i.uv.y);
                    shape += step(i.uv.x,.15)*step(i.uv.y,.7);
                #endif

                return fixed4(i.clr.xyz,shape);
			}
            ENDCG
		}
		
    }
}
