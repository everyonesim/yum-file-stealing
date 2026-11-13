Shader "Futile/PlayerRippleTrail"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Lighting Off
        Cull Off 
        Pass {
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"

            sampler2D _NoiseTex;
            sampler2D _OrigLevelTex;
            float4 _spriteRect;
            sampler2D _PlayerCamoMaskSaved;
            float _RAIN;
            float _ForceRippleTrailSwirl;
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float2 uv : TEXCOORD0;
                float2 cuv : TEXCOORD2;
                float2 texCoord : TEXCOORD5;
				float4 clr : COLOR;
			};

            float2x2 rotate2d(float angle) {
                return float2x2(
                        cos(angle), -sin(angle),
                        sin(angle), cos(angle)
                        );
            }

            float get_depth(fixed level){
                level*=255;
                fixed sky_mask = step(255,level);
                level-=1;
                float r = fmod(level,30);
                return lerp(r,30,sky_mask);
            }

            float iLerp(float from, float to, float value){
                return (value-from)/(to-from);
            }

            float2 iLerp(float2 from, float2 to, float2 value){
                return float2(iLerp(from.x,to.x,value.x),iLerp(from.y,to.y,value.y));
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);
                o.clr = v.color;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
                o.uv = v.texcoord;
                o.cuv = o.uv*2-1;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
                fixed sDepth = get_depth(tex2D(_OrigLevelTex,i.texCoord).x);
                float noise = tex2D(_NoiseTex,mul(i.cuv,rotate2d(-_RAIN*8+length(i.cuv)*4))).x-.5;
                noise*=saturate(1-length(i.cuv));
                float2 offset = i.cuv.yx-i.cuv.yx*.90;
                float trailIntensity = tex2D(_PlayerCamoMaskSaved,i.scrPos-offset*noise).x;
                trailIntensity =max(trailIntensity,noise*.3*_ForceRippleTrailSwirl);
                return fixed4(0,1,1,1)*(trailIntensity*i.clr.x*(sDepth>5))>0.01;
			}
			ENDCG

            }
    }
}
