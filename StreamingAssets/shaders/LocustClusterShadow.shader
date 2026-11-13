Shader "Futile/LocustClusterShadow"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Lighting Off
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            sampler2D _MainTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half4 shadowColor = half4(1.0/255.0, 0.0, 0.0, 1.0);
                float4 data = tex2D(_MainTex, i.uv);
                if (data.a <= 0.0) discard;

                if (any(data.rg > 0.0))
                {
                    float2 wingUv = float2(1.0 - data.g, data.b * 2.0 - 1.0);
                    wingUv = wingUv * i.color.r + float2(wingUv.y, -wingUv.x) * i.color.g;
                    if (abs(wingUv.y) < wingUv.x * 0.3) return shadowColor;
                }

                if (data.r <= 0.5) discard;
                return shadowColor;
            }
            ENDCG
        }
    }
}
