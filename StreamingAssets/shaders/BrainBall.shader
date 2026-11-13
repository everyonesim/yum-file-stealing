Shader "Futile/BrainBall"
{
    Properties
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Lighting Off
        Cull Off

        SubShader
        {
            CGINCLUDE
            #include "UnityCG.cginc"
            #include "_ShaderFix.cginc"
            #include "_RippleClip.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _PalTex;
            uniform float _fogAmount;

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 scrPos : TEXCOORD1;
                float4 clr : COLOR;
            };

            v2f vert (appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos (v.vertex);
                o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos);
                o.clr = v.color;
                return o;
            }

            half4 terrainColor (float depth, float paletteIndex)
            {
                return lerp(
                    tex2D(_PalTex, float2((depth + 0.5) / 32.0, (paletteIndex + 0.5) / 8.0)),
                    tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0)),
                    _fogAmount * (depth / 30.0)
                );
            }

            void getInfo(v2f i, out float dist, out float depth, out float noise)
            {
                rippleClip(i.scrPos);

                float2 dir = i.uv * 2 - 1;
                dist = length(dir);
                dir /= dist;

                noise = tex2D(_MainTex, i.uv * i.clr.g * 0.25 + i.clr.g * float2(123.4, 34.5) + dir * pow(dist, 2.5) * 0.15).r;
                depth = (1 - sqrt(1 - dist * dist)) + pow(1 - saturate(noise * 1.1 - 0.1), 4.0) * 0.3;
            }
            ENDCG


            // First pass
            // Fill area with pure white to prepare for the min operation
            Pass
            {
                CGPROGRAM
                #pragma target 3.0
                #pragma vertex vert
                #pragma fragment frag

                half4 frag (v2f i) : SV_Target
                {
                    float dist, depth, noise;
                    getInfo(i, dist, depth, noise);
                    if (dist > 1 || depth >= 1) discard;

                    return half4(1,1,1,1);
                }
                ENDCG
            }

            // Draw each circle, keeping the min value to emulate a depth buffer
            // This only works if the palette gets darker with depth
            Pass
            {
                Blend One One
                BlendOp Min

                CGPROGRAM
                #pragma target 3.0
                #pragma vertex vert
                #pragma fragment frag

                sampler2D _LevelTex;
                sampler2D _NoiseTex;
                uniform float _RAIN;
                uniform float4 _spriteRect;
                uniform float2 _screenSize;
                uniform float4 _lightDirAndPixelSize;

                half4 frag (v2f i) : SV_Target
                {
                    float dist, depth, noise;
                    getInfo(i, dist, depth, noise);
                    if (dist > 1 || depth >= 1) discard;

                    depth = depth * 7.0 + i.clr.r * 4.0;

                    return terrainColor(depth, 1);
                }
                ENDCG
            }
        }
    }
}