Shader "Utility/RestoreLightmapFirst"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Blend Off
        ZWrite Off
        Lighting Off
        Cull Off 
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
                float2 scrPos : TEXCOORD0;
			};
            sampler2D _OrigLevelTex;
            sampler2D _Lightmap;
            float2 _OrigLevelTex_TexelSize;
            float4 _MainTex_ST;
            float4 _lightDirAndPixelSize;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos).xy;
				return o;
			}

            float get_depth(fixed level){
                level*=255;
                fixed sky_mask = step(255,level);
                level-=1;
                float r = fmod(level,30);
                return lerp(r,30,sky_mask);
            }

			fixed frag (v2f i) : SV_Target
			{
                float pixels = 0.0;
                float2 uv = i.scrPos;
                bool hit = false;
                [unroll]
                for (int j = 0;j<31;j++){
                    float2 pos = uv + _OrigLevelTex_TexelSize * _lightDirAndPixelSize.xy*fixed2(1,-1)*1.0*(j);
                    float t = tex2D(_OrigLevelTex, pos).x;
                    float d = round(get_depth(t));
                    if (d == j){
                        if(t.x>0.3529411765)
                            pixels = 1.0;
                    }
                }
                return pixels;
            }
            ENDCG
         }
    }
}
