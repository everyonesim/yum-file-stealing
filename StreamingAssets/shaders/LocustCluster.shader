Shader "Futile/LocustCluster"
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
            #include "_RippleClip.cginc"

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
                float2 scrPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _PalTex;
            float _fogAmount;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                o.scrPos = ComputeScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                rippleClip(i.scrPos);
                half4 fogColor = tex2D(_PalTex, float2(1.5/32.0, 7.5/8.0));
                half4 skyColor = tex2D(_PalTex, float2(0.5/32.0, 7.5/8));
                half4 bgColor = lerp(skyColor, fogColor, _fogAmount);
                half4 blackColor = tex2D(_PalTex, float2(0.5 / 32.0, 0.5 / 8.0));

                half4 bodyColor = lerp(blackColor, bgColor, saturate(i.color.b));
                half4 wingColor = lerp(blackColor, bgColor, saturate(i.color.b * 0.2f + 0.8f));

                float4 data = tex2D(_MainTex, i.uv);
                if (data.a <= 0.0) discard;

                if (any(data.gb > 0.0))
                {
                    float2 wingUv = float2(1.0 - data.g, data.b * 2.0 - 1.0);
                    wingUv = wingUv * i.color.r + float2(wingUv.y, -wingUv.x) * i.color.g;
                    if (abs(wingUv.y) < wingUv.x * 0.3) return wingColor;
                }

                return data.r > 0.5 ? bodyColor : half4(0,0,0,0);
            }
            ENDCG
        }
    }
}
