Shader "Futile/DynamicLevelElement"
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
            uniform float2 _screenOffset;
			sampler2D _RippleLevelTex;
			sampler2D _OrigLevelTex;
            sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float2 _screenSize;
			float4 _spriteRect;

            void offset_depth(inout fixed level, fixed offset){
                if (level == 0||level == 1)return;
                offset = clamp(offset,-1,1)*30;
                level*=255;
                fixed depth = fmod(level,30);
                level-=depth;
                depth = clamp(depth+offset,1,30);
                level = (level+depth)/255;
                return;
            }

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
                fixed offset = i.clr.y*2-1;
                fixed4 levelCol = tex2D(_MainTex,i.texCoord);
                offset_depth(levelCol.x,offset);
                fixed depth = get_depth01(levelCol.x);
                outputDepth =  1-depth;
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
            sampler2D _Lightmap;
            float2 _CameraDepthTexture_TexelSize;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;

            void offset_depth(inout fixed level, fixed offset){
                if (level == 0||level == 1)return;
                offset = clamp(offset,-1,1)*30;
                level*=255;
                fixed depth = fmod(level,30);
                level-=depth;
                depth = clamp(depth+offset,1,30);
                level = (level+depth)/255;
                return;
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos);
				o.clr = v.color;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
                float2 ldir = normalize(_lightDirAndPixelSize.xy)*2;
                o.lightDir = ldir*float2(-_CameraDepthTexture_TexelSize.x,_CameraDepthTexture_TexelSize.y); 
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                fixed offset = i.clr.y*2-1;
                fixed4 elementCol = tex2D(_MainTex, i.uv);
                offset_depth(elementCol.x, offset);
            	fixed elementDepth = get_depth01(elementCol.x);
            	fixed levelDepth = ClipByDepth(1 - elementDepth, i.scrPos);
            	
                fixed shadow = 0;
                float2 lightDir = ParallelNearEdges(i.lightDir,i.scrPos);
                SelfShadow(shadow,lightDir,levelDepth, i.scrPos,_CameraDepthTexture, 10);   
                shadow = max(shadow, 1 - SampleSunlight(i.scrPos,(1 - levelDepth) * 30 - 6)) > 0;

                if (elementCol.x<0.3529411765&&elementCol.x!=0) {//strip original shadows
                    elementCol.x+=0.3529411765;
                }

                elementCol.x-=0.3529411765*shadow;
                return fixed4(elementCol.xyz,1);
			}
			ENDCG
		}
	}
}
