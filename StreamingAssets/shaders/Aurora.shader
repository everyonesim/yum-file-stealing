Shader "Futile/Aurora"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		// Blend SrcAlpha OneMinusSrcAlpha
        Blend One One
		ZWrite Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
		Pass
		{
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
            #pragma multi_compile_local _ foreground
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
            #include "_Functions.cginc"
			#include "_RippleClip.cginc"
			#include "_TerrainMask.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float2 scrPos : TEXCOORD1;
                float4 clr : COLOR0;
				float2 texCoord : TEXCOORD2;
			};
#if defined(SHADER_API_PSSL)
            sampler2D _GrabTexture;
#else
            sampler2D _GrabTexture : register(s0);
#endif
			sampler2D _MainTex;
			sampler2D _LevelTex;
			sampler2D _NoiseTex;
			sampler2D _UniNoise;
			sampler2D _NoiseTex2;
			float4 _MainTex_ST;
			float4 _spriteRect;
            float _RAIN;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos).xy;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
				o.clr = v.color;
                o.uv *= float2(1+10*o.clr.x,1);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                fixed sky = 1;
                fixed creatures = 1;
#if !foreground
                sky = TerrainAndLevelDepth(_LevelTex, i.texCoord, _spriteRect) >= 30.0;
                creatures = step(tex2D(_GrabTexture,i.scrPos).x,0.0001);
#endif
                float2 t = float2(_RAIN*.75,0);
                float2 t1 = float2(-_RAIN*.1,_RAIN*.75);
                float n = tex2D(_NoiseTex,i.uv*float2(1,.1)*2+t).x;
                float n2 = tex2D(_NoiseTex,i.uv*float2(1.2,.3)*1.3-t*1.2).x;
                float n1 = tex2D(_NoiseTex,i.uv*float2(2,.02)*2+t1*.5).x;
                n = n*n2;
                float shape = pulse(i.uv.y,.2+n1*.2,.2,.5+n1*.2);
                float shape2 = pulse(i.uv.y,.3+n*.2,.3);
                float edgeMask = smoothstep(0.15,.5,i.clr.w); 
                float result = ((shape+shape2*.25)*edgeMask*.35*creatures).xxx*sky*1.2;
                float value = result-pulse(n1,.5,.1)*.01-n*.01;
                fixed3 color = fixed3(i.clr.y+n*.13-n1*.15,.95+n1*.1,value);
                color = hsv2rgb(color); 
                fixed4 outColor = fixed4(color*i.clr.z,value);
                smoothTransRippleClipAdditive(outColor, i.scrPos);
                return outColor;
			}
            ENDCG
		}
    }
}
