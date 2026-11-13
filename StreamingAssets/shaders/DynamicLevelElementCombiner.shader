Shader "Futile/DynamicLevelElementCombiner"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		// Blend SrcAlpha OneMinusSrcAlpha 
		//Alphatest Greater 0
		Blend Off
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

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float2 uv2 : TEXCOORD1;
				float4 clr : COLOR;
                float2 lightDir : texcoord2;
			};
			sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			float2 _screenSize;
			float4 _spriteRect;
            float4 _lightDirAndPixelSize;
			float _RAIN;
            sampler2D _DynamicLevelElements;
			sampler2D _CameraDepthTexture;
            float2 _DynamicLevelElements_TexelSize;

            float2 scale_from(float2 uv, float2 p, float scale) {
                uv -= p;
                uv *= scale;
                return uv += p;
            }

            float get_depth(fixed level){
                level*=255;
                fixed sky_mask = step(255,level);
                level-=1;
                float r = fmod(level,30);
                return lerp(r/30,1,sky_mask);
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.uv2 = lerp(_spriteRect.xy,_spriteRect.zw,o.uv);
                o.lightDir = float2(-_lightDirAndPixelSize.x*_lightDirAndPixelSize.z,_lightDirAndPixelSize.y*_lightDirAndPixelSize.w); 
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                i.uv2 -= fmod(i.uv2,_DynamicLevelElements_TexelSize)+_DynamicLevelElements_TexelSize*.5;
                fixed4 source = tex2D(_LevelTex,i.uv);
                fixed4 destination = tex2D(_DynamicLevelElements,i.uv2);
                fixed sourceDepth = get_depth(source.x);
                fixed shadow = 0;
                if (source.x>0.3529411765 &&source.x!=1) {
                    float2 pos = 0;
                    float caster = 0;
                    //rotate light vector near top or left edge of the screen to be parallel to said edge, to avoid casting shadows from outside of the texture
                    float2 lightDir = i.lightDir*saturate(float2(i.uv2.x,1-i.uv2.y)*10);
                    [unroll]// cast shadows onto level
                    for (int j = 0;j<2;j++){
                        pos = i.uv2+lightDir*sourceDepth*(4+4*j);
                        caster = tex2D(_CameraDepthTexture, pos);
                        if (caster > (j/3) && (1-caster.x) < sourceDepth){
                            shadow = 1;
                        }
                    }
                    if (shadow ==1 ){
                        source.x-=0.3529411765;
                    }
                }

                //cast shadows from the level (very hacky, but it's probably enough)
                if (destination.x>0.3529411765 && destination.x!=1) {
                    fixed destDepth = get_depth(destination.x);
                    float2 pos = i.uv+i.lightDir*max(destDepth*30-5,0);
                    float4 caster = tex2D(_LevelTex, pos);
                    if ((caster.x > 0 && get_depth(caster.x)+.001 < destDepth )){
                            destination.x-=0.3529411765;
                    }
                }
                if (destination.x==0) return source;
                return fixed4((get_depth(destination.x)>get_depth(source.x))?source.xyz:destination.xyz,1);
			}
            ENDCG
		}
    }
}
