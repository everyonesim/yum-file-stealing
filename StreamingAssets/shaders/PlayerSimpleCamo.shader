Shader "Futile/PlayerSimpleCamo"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
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
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
			#include "_Functions.cginc"

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
                float2 texCoord1 : TEXCOORD3;
                float2 texCoord2 : TEXCOORD4;
			};
			sampler2D _MainTex;
            sampler2D _NoiseTex;
			float4 _MainTex_ST;
            float4 _spriteRect;
            float _RAIN;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos).xy;
                o.texCoord1 = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
                o.texCoord2 = (o.texCoord1+float2(0.5+_RAIN*.001,_RAIN*-.0225))*fixed2(10,30);
                o.texCoord1 = (o.texCoord1+float2(-_RAIN*.002,_RAIN*.0125))*fixed2(10,40);
				o.clr = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                float noise = (tex2D(_NoiseTex,i.texCoord1).x+tex2D(_NoiseTex,i.texCoord2).x)*.5;
                return tex2D(_MainTex, i.uv) * fixed4(i.clr.xyz,step(noise,i.clr.w));
			}
            ENDCG
		}
    }
}
