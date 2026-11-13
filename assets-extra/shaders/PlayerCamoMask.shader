Shader "Futile/PlayerCamoMask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        ZWrite Off
        Lighting Off
        Cull Off 
        GrabPass {"_PlayerCamoMask"}
        Pass {
            Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
			#include "_Functions.cginc"

            sampler2D _NoiseTex;
            sampler2D _PlayerCamoMask;
            sampler2D _PlayerCamoMaskBeforePlayer;
            float _RAIN;
			float _playerWarpPointTime;
            uniform float2 _screenSize;
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
                float2 noiseUV : TEXCOORD3;
				float4 clr : COLOR;
                float2 distort : TEXCOORD4;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.scrPos = ComputeScreenPos(o.pos);
                o.clr = v.color;
                o.uv = v.texcoord;
                o.cuv = o.uv*2-1;
                // fixed2 offset = fixed2(0.,.15);
                fixed2 offset = fixed2(0.,-.75);
                o.cuv-=offset;
                o.distort = o.cuv*.3-mul(o.cuv*.3,rotate2d(.06));
                // o.cuv *= 1+o.clr.x*0.75;
                o.noiseUV = o.cuv-mul(o.cuv,rotate2d(_RAIN*1+.5-distance(smoothstep(0,1,o.clr.x),.5)));
                o.noiseUV = o.cuv+_RAIN*1-o.noiseUV;
                // o.noiseUV -= fixed2(0,.4);
                o.noiseUV *= 0.75;
				return o;
			}

            fixed diff(fixed3 a, fixed3 b){
                return saturate(step(0.0039215686,abs(a-b)));
            }

            float2 QuantizeToPixels(float2 coord){
                float2 pixel = 1/_screenSize;
                return coord - fmod(coord, pixel) + pixel * .5;
            }

			fixed4 frag (v2f i) : SV_Target
			{
                fixed hide=i.clr.x;
                hide *= 1-saturate(iLerp(-1,0,_playerWarpPointTime))*(_playerWarpPointTime<=.5);
                fixed angle = atan2(i.cuv.x,i.cuv.y);
                fixed noise = tex2D(_NoiseTex,i.noiseUV).x;
                fixed distortIntensity=sin(abs(.5-length(i.cuv)+noise*.5)*10+angle*3-_RAIN*20)+length(i.cuv)*.1;
                float2 distCoord = i.scrPos+i.distort*distortIntensity*4*hide;
                distCoord = QuantizeToPixels(distCoord);
                fixed3 playerDist = tex2D(_PlayerCamoMask,distCoord).xyz;
                fixed3 playerDistBeforePlayer = tex2D(_PlayerCamoMaskBeforePlayer,distCoord).xyz;
                playerDistBeforePlayer *= playerDistBeforePlayer>0.0039215686;
                fixed mask = diff(playerDistBeforePlayer,playerDist);
                playerDist *= mask;
                distortIntensity*=.5+(1.-pow(length(i.cuv),2));
                distortIntensity*=mask;
                fixed3 player = tex2D(_PlayerCamoMask,i.scrPos).xyz;
                fixed3 stuffBeforePlayer = tex2D(_PlayerCamoMaskBeforePlayer,i.scrPos).xyz;
                stuffBeforePlayer *= stuffBeforePlayer>0.0039215686;
                player *= diff(stuffBeforePlayer,player);
                fixed distMask = abs(distortIntensity)>hide*(1.6);
                fixed3 result = (0).xxx;
                result+=playerDist;
                result*=(hide<1);
                result = lerp(stuffBeforePlayer,result,distMask);
                return fixed4(result,(i.clr.x>0));
			}
			ENDCG

            }
    }
}
