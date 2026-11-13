Shader "Futile/SlopedTerrainMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        ZWrite Off
        Cull Off

        Pass
        {
            BlendOp Max
            Blend One One
            ZClip False

            CGPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "TerrainCommon.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                noperspective float2 screenPos : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            // Adapted from SlopedTerrainSurface
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos (v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;

                o.pos.z = 0.0;
                //o.pos.w = (10.0 - (o.depth * 30.0 - 6.0) * -0.025) * 0.1;
                o.pos.w = 0.985 + o.worldPos.z * 0.075;
                o.pos.xy += (lerp(_spriteRect.xy, _spriteRect.zw, float2(0.5, 2.0 / 3.0)) * 2.0 - 1.0) * float2(1.0, -1.0) * (o.pos.w - 1.0);
                
                o.screenPos = ComputeScreenPos(o.pos / o.pos.w);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Compute lighting
                float2 levelUv = ScreenToLevelTex(i.screenPos);
                float sunlight = SampleSunlight(i.screenPos, i.worldPos.z * 30.0 - 1.0);
                if (i.worldPos.z > 0.0 && sunlight > 0.0)
                {
                    sunlight *= LevelShadows(levelUv, i.worldPos.z);
                }

                // Compute black goo mask
                float gooLevel = tex2D(_NoiseTex, float2(i.worldPos.x / 3000.0, 0.0)).r * 25.0 + TERRAIN_GOO_HEIGHT;
                float gooFactor = i.uv.y - gooLevel + 6.0 - tex2D(_NoiseTex, i.worldPos.xx / float2(150.0, 310.0) + float2(0.5, 0.5)).r * 14.0 > 0.0;
                sunlight *= 1 - gooFactor;

                return fixed4((2 - i.worldPos.z) / 3.0, sunlight, gooFactor, 1);
            }
            ENDCG
        }
    }
}
