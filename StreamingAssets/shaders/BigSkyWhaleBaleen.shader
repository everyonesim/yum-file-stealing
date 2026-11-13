Shader "Futile/BigSkyWhaleBaleen"
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
                    
                    float t = i.uv.y * abs(i.uv.y);
                    float side = i.uv.x * 2 - 1;
                    float tipDist = abs(side);

                    float t2 = t + sin(tipDist * 2) * 0.03 * sign(i.uv.y);
                    float toothPattern = saturate(tex2D(_NoiseTex, float2(t2 + 0.2, t2 * 50.0)).r * 2 - 0.5);
                    float darkness = toothPattern * pow(tipDist, 0.7);
                    darkness = lerp(darkness, 1, tipDist);
                    darkness = round(darkness * 5.0) / 5.0;
                    if ((tex2D(_NoiseTex, float2(t, t * 60.0)).r - 0.5) * 2 + 0.3 > tipDist * (3 + 5 * (side > 0)))
                        discard;

                    half3 light = half3(0.75, 0.72, 0.63);
                    half3 dark = half3(0.51, 0.48, 0.40);
                    half3 fog = tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0));
                    half fogAmount = 1 - tex2D(_PalTex, float2(9.5 / 32.0, 7.5 / 8.0)).r;
                    half3 black = tex2D(_PalTex, float2(2.5 / 32.0, 7.5 / 8.0));

                    half3 color = lerp(light, dark, darkness);

                    float lip = tex2D(_NoiseTex, float2(t, t * 2.0)).r * 0.1 + 0.75 - toothPattern * 0.03;
                    color = lerp(color, 0.1, saturate((tipDist - lip) * 80.0) * 0.7);
                    color = lerp(color, fog, saturate(0.5 - 0.5 * sin(i.uv.y * 3.14159265359)) * fogAmount);

                    return half4(color, 1);
                }
                ENDCG
            }
        }
    }
}
