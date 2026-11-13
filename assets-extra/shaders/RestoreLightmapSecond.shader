Shader "Utility/RestoreLightmapSecond"
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
                float2 scrPos : TEXCOORD1;
                float2 uv : TEXCOORD0;
			};
            sampler2D _MainTex;
            float2 _MainTex_TexelSize;
            float4 _MainTex_ST;
            float4 _lightDirAndPixelSize;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos).xy;
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
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
                fixed blured = 0;
                fixed blured1 = 0;
                fixed blured2 = 0;
                fixed blured3 = 0;
                fixed blured4 = 0;
                fixed blured5 = 0;
                int mip =3;
                fixed cutoff = 1.0;
                fixed offset = 5;
                [unroll]
                    for (int k = 0;k<9;k++){
                        int off = (k-ceil(9/2));
                        blured += tex2Dlod( _MainTex,float4(i.uv- _MainTex_TexelSize*_lightDirAndPixelSize.xy*off,0,mip)).x;
                        blured += tex2Dlod( _MainTex,float4(i.uv+_MainTex_TexelSize*float2(0,1)*off*offset,0,mip)).x;
                        blured += tex2Dlod( _MainTex,float4(i.uv+_MainTex_TexelSize*float2(1,0)*off*offset,0,mip)).x;
                        blured += tex2Dlod( _MainTex,float4(i.scrPos+_MainTex_TexelSize*float2(1,1)*off*offset,0,mip)).x;
                        blured += tex2Dlod( _MainTex,float4(i.uv+_MainTex_TexelSize*float2(-1,1)*off*offset,0,mip)).x;
                    }
               blured = blured>cutoff;
                return blured;
			}
			ENDCG
         }
    }
}
