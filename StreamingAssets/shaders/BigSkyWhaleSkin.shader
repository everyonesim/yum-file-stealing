Shader "Futile/BigSkyWhaleSkin"
{
    Properties
    {
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
    }

    Category
    {
        Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        SubShader
        {
            Pass
            {
                CGPROGRAM
                #pragma target 3.0
                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"
                #include "_ShaderFix.cginc"
                #include "_RippleClip.cginc"
                #define PI 3.14159265359

                sampler2D _MainTex;
                sampler2D _NoiseTex;
                sampler2D _PalTex;

                struct v2f {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float2 scrPos : TEXCOORD1;
                    float4 clr : COLOR;
                };

                float4 _MainTex_ST;

                v2f vert(appdata_full v)
                {
                    v2f o;
                    o.pos = UnityObjectToClipPos(v.vertex);
                    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                    o.scrPos = ComputeScreenPos(o.pos);
                    o.clr = v.color;
                    return o;
                }

                half4 frag(v2f i) : SV_Target
                {
                    rippleClip(i.scrPos);

                    float yNoiseScale = 1 - i.uv.x * 0.95;
                    float noiseA = tex2D(_NoiseTex, float2(i.uv.x * 10, (i.uv.y - 0.5) * 20 * yNoiseScale)).r;
                    float noiseB = tex2D(_NoiseTex, float2((i.uv.y - 0.5) * 15 * yNoiseScale, i.uv.x * 9)).r;
                    float side = abs(i.uv.y) - 0.25 + pow(1 - i.uv.x, 50) * 0.2;
                    side += tex2D(_NoiseTex, i.uv.x * float2(2, 1)).r * 0.05 - 0.025;
                    side += pow(max(i.uv.x * 2 - 1, 0), 2);
                    float seam = pow(1 - pow(1 - min(abs(side) * 5.0, 1), 2), 0.4);

                    float temp = 0.5 - cos(i.uv.y * PI) * 0.5;
                    float lipDist = i.uv.x * 4.0 - temp * temp;
                    clip(lipDist);

                    float noise = max(noiseA, noiseB);
                    float sunlight = saturate(-cos(i.uv.y * 3.14159) + 0.4);
                    sunlight = max(sunlight, 1 - 10 * lipDist * (1 - temp * 0.8));
                    noise *= tex2D(_NoiseTex, i.uv * 0.5).r;
                    noise = lerp(0.5, noise, sqrt(min(10 * lipDist * (1 - temp * 0.5), 1)));

                    float topPattern = saturate(noise * (sunlight * 0.7 + 0.3));
                    topPattern *= seam * 0.5 + 0.5;
                    topPattern = smoothstep(0.02, 0.5, topPattern);
                    if (i.uv.x > 0.7) topPattern *= 1 - (i.uv.x - 0.7) / 0.3;
                    topPattern = pow(round(sqrt(topPattern) * 5) / 5, 2);

                    float bottomPattern = saturate(noise * pow(i.uv.y / 0.35, 0.6) + i.uv.y * 1.5);
                    bottomPattern *= seam * 0.8 + 0.2;
                    bottomPattern = pow(round(sqrt(bottomPattern) * 10) / 10, 2);

                    half4 fog = tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0));
                    half fogAmount = 1 - tex2D(_PalTex, float2(9.5 / 32.0, 7.5 / 8.0)).r;
                    
                    half4 skin = lerp(
                        lerp(half4(0.1,0.1,0.1,1), half4(0.2,0.2,0.2,1), topPattern),
                        lerp(half4(0.5/1.5,0.4/1.5,0.3/1.5,1), half4(0.6,0.5,0.3,1), bottomPattern),
                        saturate(side * -600.0)
                    );

                    float radFac = 1 - pow(i.uv.x, 3);
                    skin = lerp(skin, fog, saturate(0.5 - 0.5 * sin(i.uv.y * PI) * radFac) * fogAmount);
                    return skin;
                }
                ENDCG
            }
        }
    }
}
