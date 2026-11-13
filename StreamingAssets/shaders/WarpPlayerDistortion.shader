Shader "Futile/WarpPlayerDistortion"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend SrcAlpha OneMinusSrcAlpha 
		Fog { Color(0,0,0,0) }
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
                float4 scrPos : TEXCOORD1;
				float2 uv_rain : TEXCOORD2;
				float4 pos : SV_POSITION;
				float4 clr : COLOR;
			};
			sampler2D _PalTex;
			sampler2D _MainTex;

			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _UniNoise;
			sampler2D _LevelTex;
			sampler2D _WarpPointHoldFrame;
            sampler2D _PlayerCamoMaskSaved;

			float2 _LevelTex_TexelSize;
			// float4 _lightDirAndPixelSize;
			float2 _screenSize;
			float4 _spriteRect;
			// float4 _EffectColor;
			// float _WetTerrain;
			float _waterLevel;
			float _RAIN;
			// float _cloudsSpeed;
			float _fogAmount;
			float _playerWarpPointTime;
            float2 _warpPointPosition;
            float2 _FollowCreatureScreenPos;
            sampler2D _pAngle;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;

            float plot(float x, float y)
            {
                float p = abs(dot(float2(x,y),float2(1,-1)));
                return smoothstep(0.02,0.0,p);
            }

            float2x2 rotate2d(float angle) {
                return float2x2(
                        cos(angle), -sin(angle),
                        sin(angle), cos(angle)
                        );
            }

            float2 rotate_around(float2 uv, float2 p, float angle) {
                float ratio = _screenSize.x/_screenSize.y;
                uv -= p;
                uv.x = uv.x*ratio;
                uv = mul(uv,rotate2d(angle));
                uv.x = uv.x/ratio;
                return uv += p;
            }

            float2 scale_from(float2 uv, float2 p, float scale) {
                uv -= p;
                uv *= scale;
                return uv += p;
            }

            float2 scale_from(float2 uv, float2 p, float2 scale) {
                uv -= p;
                uv *= scale;
                return uv += p;
            }

            float pulsate(float frequency_multiplier, float amplitude_multiplier) {
                return 1.0 - sin(_RAIN * frequency_multiplier) * amplitude_multiplier;
            }

            float sinesmooth(float x){
                return 1-(cos(x*3.14159265)*.5+.5);
            }

            float mod(float x, float y){ //GLSL-like modulo function
                return x-y*floor(x/y);
            }

            float iLerp(float from, float to, float value){
                return (value-from)/(to-from);
            }

            fixed2 ring_motion(float v )
            {
                return fixed2(sin(v),cos(v));
            }

            fixed hard_range(float value, float from, float to){
                return step(from,value)*step(value,to);
            }

            fixed not_zero(float3 a){
                return saturate(step(0.00001,a.x)+step(0.00001,a.y)+step(0.00001,a.z));
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
                o.uv_rain = o.uv+_RAIN;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                //input parameters:
                fixed noodle_intensity=i.clr.w; // unused for now

                if (_playerWarpPointTime<=0 || _playerWarpPointTime > .5) discard;
                fixed originalMask = not_zero(tex2D(_PlayerCamoMaskSaved,i.scrPos).xyz);

                float warpTime = _playerWarpPointTime;
                float swirl_intensity = saturate(iLerp(.5,0.01,abs(max(warpTime,0)-.5)));
                float2 fcsp = _FollowCreatureScreenPos;

                float dist = distance(fcsp,scale_from(i.scrPos.xy,fcsp,fixed2(1,0.5555))) ;
                dist = saturate(dist);
                float easeDist = dist*(-dist+2);
                i.scrPos.xy =rotate_around(i.scrPos.xy,fcsp,easeDist*30*swirl_intensity-smoothstep(0,1,swirl_intensity)*30);

                float otherCreaturesMaskTime = saturate(smoothstep(0,.5,warpTime))*(_playerWarpPointTime<=.5);
                float noise = tex2D(_NoiseTex, i.scrPos.xy+float2(_RAIN,0)).x;
                noise = dist+noise*.25;
                fixed removeCreatures = step(noise,.40*otherCreaturesMaskTime);

                float2 spag_uv = i.scrPos;
                float vanish = saturate(smoothstep(.9,1,swirl_intensity));
                float widening = (spag_uv.x-fcsp.x)*(.01+vanish*5)+fcsp.x;
                spag_uv.y = iLerp(fcsp.y-.09,1,spag_uv.y);
                spag_uv.y -=(swirl_intensity*(2.82+vanish*2));
                spag_uv.y = lerp(fcsp.y-.02-swirl_intensity*.01,fcsp.y+.01+swirl_intensity*.005,spag_uv.y);
                swirl_intensity = saturate(iLerp(.3,1,swirl_intensity));
                i.scrPos.x = lerp(i.scrPos.x, widening,swirl_intensity);
                i.scrPos.y = lerp(i.scrPos.y,spag_uv.y,swirl_intensity);

                fixed4 spg = tex2D(_PlayerCamoMaskSaved,i.scrPos);

                fixed finalMask = max (not_zero(spg.xyz),originalMask);
                finalMask = max(finalMask,removeCreatures);

                return fixed4(spg.xyz,finalMask);
			}
			ENDCG
		}
	}
}
