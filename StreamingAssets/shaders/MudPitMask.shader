Shader "Futile/MudPitMask"
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
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float depth : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos (v.vertex);
                o.depth = v.uv.y;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4((2 - i.depth) / 3.0, 0, 0, 1);
            }
            ENDCG
        }
    }
}
