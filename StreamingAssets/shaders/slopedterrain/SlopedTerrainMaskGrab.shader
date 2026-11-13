Shader "Futile/SlopedTerrainMaskGrab"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        ZWrite Off
        Cull Off

        GrabPass { "_SlopedTerrainMask" }

        Pass
        {
            Name "Clear"

            CGPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 vert (float4 vertex : POSITION) : SV_POSITION
            {
                return UnityObjectToClipPos(vertex);
            }

            fixed4 frag () : SV_Target
            {
                return fixed4(0,0,0,1);
            }
            ENDCG
        }
    }
}
