Shader "Futile/RippleGrab"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Blend One One
        ZWrite Off
        Lighting Off
        Cull Off 
         Pass {
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
// #pragma enable_d3d11_debug_symbols
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"

            sampler2D _RippleMaskSaved;
            sampler2D _NoiseTex;
            float _RAIN;
            float _ForceRippleTrailSwirl;

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 scrPos : TEXCOORD1;
                float4 clr : COLOR0;
                float2 nuv : TEXCOORD2;
                float2 texUV : TEXCOORD3;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos).xy;
                o.clr = v.color;
                o.nuv = o.scrPos*fixed2(6,4)-fixed2(0,_RAIN);
                if (o.clr.x != 0)
                    o.clr.x = 1.005-0.005/(o.clr.x+.025);
                o.texUV = o.scrPos*fixed2(100,150)+_RAIN*50;
                _RAIN=_RAIN*1;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
                if (i.clr.x == 0)discard;
                fixed4 texlow = tex2Dlod(_RippleMaskSaved,fixed4(i.scrPos,0,3));
                if (texlow.y==0) discard;
                fixed4 tex = tex2Dlod(_RippleMaskSaved,fixed4(i.scrPos+fixed2(cos(i.texUV.x)*.0008,sin(i.texUV.y)*.0008)*saturate(.8-texlow.y),0,0));
                i.clr.x = lerp(i.clr.x,1.002,_ForceRippleTrailSwirl);
                fixed noise = tex2D(_NoiseTex,i.nuv).x*2-1;
                return  fixed4(0,(tex.y-saturate(noise)*.01)*i.clr.x-.0008,0,0);
			}
			ENDCG
         }
        GrabPass {"_RippleMask"}
        Pass {
            Name "Clear"
            Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
                return fixed4(0,0,0,1);
			}
			ENDCG
            }
    }
}
