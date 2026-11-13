Shader "Futile/BlackSpot"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "TerrainCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 dists : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 dists : COLOR;
                float2 scrPos : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.dists = v.dists;
                o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float dist = min(min(i.dists.x, i.dists.y), min(i.dists.z, i.dists.w));

                clip(dist - tex2D(_NoiseTex, i.uv).r);

                return LevelPalette(0.5 / 32.0, 0.5 / 8.0, GetRippleParams(i.scrPos));
            }
            ENDCG
        }
    }
}
