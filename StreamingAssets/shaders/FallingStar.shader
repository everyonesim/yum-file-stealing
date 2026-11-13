Shader "Futile/FallingStar"
{
    Properties 
    {
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
    }
    
    Category 
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
		Blend SrcAlpha One 
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
                #include "_Functions.cginc"
                #include "_RippleClip.cginc"
                #include "_TerrainMask.cginc"
                //#pragma profileoption NumTemps=64
                //#pragma profileoption NumInstructionSlots=2048

                sampler2D _MainTex;
                float4 _MainTex_ST;
                sampler2D _LevelTex;
                sampler2D _NoiseTex;
                sampler2D _NoiseTex2;
                sampler2D _CloudsTex;
                sampler2D _PalTex;
                uniform float _fogAmount;
                uniform half4 _AboveCloudsAtmosphereColor;
                uniform half4 _MultiplyColor;

                #if defined(SHADER_API_PSSL)
                sampler2D _GrabTexture;
                #else
                sampler2D _GrabTexture : register(s0);
                #endif

                uniform float4 _spriteRect;
                uniform float2 _screenSize;

                struct v2f
                {
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

                half4 frag (v2f i) : SV_Target
                {
                    float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
                    
                    textCoord.xy -= _spriteRect.xy;
                    textCoord.xy /= _spriteRect.zw - _spriteRect.xy;
                    
	                BackgroundClipVanilla(_LevelTex, _GrabTexture, textCoord, i.scrPos);

                    half4 starColor = half4(0.2, 1, 0.2, 1);
                    half4 textureColor = tex2D(_MainTex, i.uv);

                    float starGlow = textureColor.r;
                    float star = textureColor.g;
                    //star = star > 0.9 ? 1 : 0;
                    half4 finalColor = starColor * starGlow;
                    finalColor += star * 0.2 * half4(1, 0, 1, 1);
                    float fogginess = (1 - i.clr.a);
                    finalColor *= fogginess * fogginess;
                    finalColor += star * 0.1;

                    float fadeDown = 1 - i.clr.b;
                    fadeDown = clamp(fadeDown * 5, 0, 1);
                    finalColor *= fadeDown;

                    finalColor *= i.clr.g;
                    finalColor += star * 0.1;

                    smoothRippleClipAdditive(finalColor, i.scrPos);
                    return finalColor;
                }
                ENDCG
            }
        } 
    }
}
