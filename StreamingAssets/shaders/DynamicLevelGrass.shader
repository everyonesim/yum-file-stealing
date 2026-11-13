Shader "Futile/DynamicLevelGrass"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags { "queue" = "Geometry"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite On
		//Alphatest Greater 0
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
            Tags { "LightMode"="ShadowCaster"}
            ZWrite On
            CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
			#include "_DynamicLevelElementFunctions.cginc"
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
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
                float2 texCoord : texcoord2;
			};
			float _RAIN;
            uniform float2 _screenOffset;
            sampler2D _NoiseTex;
			sampler2D _RippleLevelTex;
			sampler2D _OrigLevelTex;
            sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float2 _screenSize;
			float4 _spriteRect;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos);
				o.clr = v.color;
                o.texCoord = o.uv;
				return o;
			}

			void frag (v2f i, out float outputDepth : SV_Depth)
            {
                outputDepth = i.clr.x;
			}
			ENDCG
    }
		Pass
		{
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
			#include "_DynamicLevelElementFunctions.cginc"
            #include "_Functions.cginc"
            #include "SlopedTerrain/TerrainCommon.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
                float2 texCoord : texcoord2;
                float2 lightDir : texcoord3;
			};
            uniform float2 _screenOffset;
			sampler2D _RippleLevelTex;
			sampler2D _OrigLevelTex;
			sampler2D _Float;
            sampler2D _MainTex;
            sampler2D _UniNoise;
            float2 _CameraDepthTexture_TexelSize;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;


			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos);
				o.clr = v.color;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy)*10;
                float2 ldir = _lightDirAndPixelSize.xy;
                o.lightDir = ldir*float2(-_CameraDepthTexture_TexelSize.x,_CameraDepthTexture_TexelSize.y); 
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                float flat = i.clr.x;
                fixed d = ClipByDepth(flat, i.scrPos);
                fixed depth = clamp(saturate(1.0-flat)*30,2,30);
                fixed shadow = 0;
                fixed noise = tex2D(_UniNoise,i.texCoord);
                if ((1-i.clr.z)-noise*.4*max(smoothstep(.8,.9,i.clr.x),smoothstep(.8,.7,i.clr.x)*.8) <= 0) discard;

                //rotate light vector near top or left edge of the screen to be parallel to that edge, to avoid casting shadows from outside of the texture
                float2 lightDir = ParallelNearEdges(i.lightDir,i.scrPos);

                // SelfShadow(shadow,lightDir,d,i.scrPos,_CameraDepthTexture, 10);   //no self-shadows for now, helps the grass feel more airy
                shadow = max(shadow,1-SampleSunlight(i.scrPos,(1-d)*30-6))>0;
                fixed4 levelCol = 
                         fixed4(
                               pack_red(saturate(1-shadow),//light
                                        depth,
                                        1),
                               0, 0, 1);

                levelCol.z = i.clr.y;
                return fixed4(levelCol.xyz,1);
			}
			ENDCG
		}
	}
}
