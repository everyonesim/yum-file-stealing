Shader "Futile/CamoMeter"
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
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #define PI 3.14159265359

            // Linked to corresponding values in CamoMater.cs
            static const float spriteWidth = 340.0;
            static const float spriteHeight = 80.0;
            static const float spriteAnchorX = spriteHeight / 2.0 / spriteWidth;

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
            sampler2D _NoiseTex;
            sampler2D _CloudsTex;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            half4 SmokeGradient (float amount)
            {
                half3 gold = half3(0.529, 0.365, 0.184) * 2.0;
                half3 white = half3(1.0, 1.0, 1.0);
                return half4(lerp(gold, white, pow(amount, 0.5) * 0.5 + 0.5), amount);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 color = tex2D(_MainTex, i.uv);
                float empty = 1.0 - i.color.r;
                float lock = i.color.g;
                float smokeAnim = i.color.b / 10.0;
                color.a *= i.color.a;

                // Recenter UVs on karma meter
                float2 uv = (i.uv - float2(spriteAnchorX, 0.5)) * float2(spriteWidth / spriteHeight, 1.0);
                float uMax = (1.0 - spriteAnchorX) * spriteWidth / spriteHeight;
                float fracAlongBar = (uv.x / uMax - 0.07) / (1 - 0.07);

                float yCutoff = saturate(1.5 - (fracAlongBar + empty * 0.5) * 1.1) * 0.8;
                yCutoff *= smoothstep(-0.6, 0.4, uv.x);

                float theta = (uv.x + 2.0 * uv.y * uv.y) * 7.0 - 9.0 * smokeAnim;
                float2 noiseCoord;
                noiseCoord.x = uv.x - 0.8 * sqrt(1 - 4.0 * uv.y * uv.y) - smokeAnim; // Horizontal distortion
                noiseCoord.y = uv.y + 0.15 * sin(theta) * (1.0 - fracAlongBar * 0.8);  // Vertical sinusoidal motion
                noiseCoord += normalize(uv) * sin(length(uv) * 10.0) * 0.025;        // Ripple lensing effect

                float noise = tex2D(_CloudsTex, noiseCoord * 0.2 - smokeAnim * float2(0.2, 0)).r * 0.5
                            + tex2D(_CloudsTex, noiseCoord * 0.5 + 0.5 - smokeAnim * float2(0.4, 0)).r * 0.5;
                noise -= pow(abs(lerp(uv.y, noiseCoord.y, 0.4) * 2.0) / yCutoff, 3.0); // Fade towards edges
                noise -= pow(max(0, (fracAlongBar + empty * 0.9 - 1.0) / 0.3 + 1.0), 3.0);   // Fade at end
                noise -= pow(saturate(2.0 - 6.0 * length(uv)), 1.5);                   // Fade around karma
                noise *= smoothstep(-0.2, 0.6, uv.x + 0.3 - pow(abs(uv.y), 2.0));      // Change color range
                noise = max(0, noise);
                noise = smoothstep(0.2, 0.9, pow(noise, 0.7)) * 0.75;
                color *= SmokeGradient(noise);
                
                if (lock > 0.0) {
                    half usableFracLeft = 1.0 - lock - empty;
                    half lockFac = saturate((fracAlongBar - usableFracLeft + (0.5 - noise) * 0.1) * 15.0 + 0.5);
                    half3 purple = half3(0.373, 0.11, 0.831);
                    color.rgb = lerp(color.rgb, purple, lockFac);
                }

                return color;
            }
            ENDCG
        }
    }
}
