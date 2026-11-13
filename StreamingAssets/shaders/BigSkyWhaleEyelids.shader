Shader "Futile/BigSkyWhaleEyelids"
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

                    float cosU = 0.5 - 0.5 * cos(i.uv.x * PI * 2.0);
                    float side = i.uv.y - 0.5;
                    float noise = tex2D(_NoiseTex, i.uv);

                    // Distance from center line to end of eyelid
                    float lid = pow(cosU, 0.7) * 0.35 + pow(cosU, 0.1) * 0.1 - noise * 0.05;
                    if (side > lid || side < -lid)
                        discard;

                    // Distance from center line to start of eyelid
                    float top = max((i.uv.x - 0.25) * (0.75 - i.uv.x) * 2, -lid);
                    float bot = min(top * -1.5, lid);
                    if (side < top && side > bot)
                        discard;

                    float frac = side > 0 ? (side - top) / (lid - top) : (side - bot) / (-lid - bot);

                    half4 fog = tex2D(_PalTex, float2(1.5 / 32.0, 7.5 / 8.0));
                    half fogAmount = 1 - tex2D(_PalTex, float2(9.5 / 32.0, 7.5 / 8.0)).r;
                    half4 black = tex2D(_PalTex, float2(2.5 / 32.0, 7.5 / 8.0));
                    
                    float lightness = pow(2.0 * sqrt(frac - frac * frac), 4) * sqrt(cosU);
                    lightness *= noise;
                    lightness = saturate(lightness * 1.2 + side - (1 - i.uv.x) * 0.25 + 0.15);
                    lightness = round(lightness * 4) / 4.0;

                    half4 skin = lerp(half4(0.1,0.1,0.1,1), half4(0.2,0.2,0.2,1), lightness);
                    skin = lerp(black, skin, saturate(abs(i.clr.y) + 0.5));
                    skin = lerp(skin, fog, saturate(0.5 - 0.5 * sin(i.clr.y * PI)) * fogAmount);
                    return skin;
                }
                ENDCG
            }
        }
    }
}
