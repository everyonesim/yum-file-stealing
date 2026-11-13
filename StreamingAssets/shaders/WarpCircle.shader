Shader "Futile/WarpCircle"
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
		GrabPass { "_WarpPointGrabPass" }
		Pass
		{ Name "WarpCircleBasic"
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
			#include "UnityCG.cginc"
			#include "_ShaderFix.cginc"
            #include "_Functions.cginc"
            #include "_RippleClip.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 cuv : TEXCOORD2;
				float2 texCoord : TEXCOORD3;
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
                float2 data[4] : COLOR1;
			};
			sampler2D _WarpPointGrabPass;
			sampler2D _PalTex;
			sampler2D _MainTex;


			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _UniNoise;
			sampler2D _LevelTex;
			sampler2D _WarpPointHoldFrame;

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
			float _warpPointTime;
            float2 _warpPointPosition;
            sampler2D _pAngle;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;

            float plot(float x, float y)
            {
                float p = abs(dot(float2(x,y),float2(1,-1)));
                return smoothstep(0.02,0.0,p);
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

            float pulsate(float frequency_multiplier, float amplitude_multiplier) {
                return 1.0 - sin(_RAIN * frequency_multiplier) * amplitude_multiplier;
            }

            float draw_stripe(float2 uv,float2 start, float length, float width){
                float a = step(start.x,uv.x);
                a *= step(uv.x,start.x+length);
                a *= step(abs(uv.y-start.y),width);
                return a;
            }


            float sinesmooth(float x){
                return 1-(cos(x*3.14159265)*.5+.5);
            }

            // float dark_edges(float2 uv,float amount){
            //     return smoothstep(2-amount*.25+.001,2-amount,length(uv*2-1));
            // }
            //
            // fixed2 unpack(fixed packed){
            //     int2 v = packed*255;
            //     return fixed2(v.x&15,v.y>>4)*0.0627450980;
            // }



            float annoyingRings(float2 uv, float scale, float t){
                uv*=4*scale;
                t*=2;
                float len = length(uv);
                float circle = length(uv+circularMotion(t+(len-fmod(len,.31415))*t)*.06);
                float rings = abs(sin(circle*10));
                rings = smoothstep(0.6,1.,rings);
                return rings;
            }

            float2 ring(float2 cuv, float noise,float wave_time){

                float warpTime = saturate(_warpPointTime);
                float touch =saturate(_warpPointTime+1);
                float new_world = 1-saturate(iLerp(.5,1,warpTime));
                float activeMask = abs(saturate(iLerp(.25,.75,warpTime))-.5)*2;
                float second_half = step(0.50001,warpTime);
                touch = lerp(touch,new_world,second_half);
                touch = sinesmooth(touch);

                cuv -= (noise*2-1)*.01;
                cuv *= 1+touch*.0125;

                float len = length(cuv);
                float t = _RAIN*4+wave_time*.5+touch*4;

                float rings = annoyingRings(cuv,1,_RAIN);
                rings += annoyingRings(cuv,.5+sin(t*.125)*.3,t+noise);
                rings += annoyingRings(cuv+float2(.02,0),1.2,t*-1.3-noise);
                rings += annoyingRings(cuv+float2(.0,.02),1.9,t*+.6);
                rings = clamp(rings,0,1+wave_time*.5);

                float rays = atan2(cuv.x+rings*.01,cuv.y-rings*.01);
                rays = sin(rays*2+t*.6+len*23);
                rays *= cos(rays*5+t*.9+len*35);
                rays = 1-abs(rays);
                rays = smoothstep(.0,0.9,rays);

                float bigR = len-.5;
                bigR = 1-abs(bigR);
                bigR = bigR*rings*.05+bigR-rays*0.02;

                float darkness = smoothstep(0.99-wave_time*.03,1.+touch*touch*.3,bigR);
                float glow = smoothstep(.90-wave_time*.05+touch*.05,1,bigR)*(.4-touch*.4 +wave_time*.1) ;

                return float2(darkness,glow)*activeMask;
            }


			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.cuv = o.uv*2-1;
				o.clr = v.color;
                o.clr.w = smoothstep(1,0,o.clr.w);
				o.scrPos = ComputeScreenPos(o.pos);
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
                float time = fmod(_RAIN,1.5);
                float flash_time = pulse(time,.02,.02,.3);
                float wave_time =  pulse(time,.03,.03,.6);
                wave_time *=o.clr.w ;
                float wave_progression =  smoothstep(-.63,.63,time);
                float active_phase_mask = saturate(smoothstep(0.45,0.5,abs(_warpPointTime-.5)));
                fixed2 scaled_uv = scale_from(o.scrPos,_warpPointPosition,.9);
                o.data[0] = float2(flash_time,wave_time);
                o.data[1] = float2(wave_progression,active_phase_mask);
                o.data[2] = scaled_uv;
                o.data[3] = o.uv-float2(_RAIN*.1,_RAIN*2);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                rippleClip(i.scrPos);
                fixed4 rippleColor = fixed4(.2,.25,1,1)*.75;
                fixed depth = get_depth_sat(tex2D(_LevelTex,i.texCoord).x);
                fixed foreground_mask = saturate(iLerp(1,5,depth));
                fixed dist = length(i.cuv);
                float flash_time = i.data[0].x;
                float wave_time = i.data[0].y;
                float wave_progression = i.data[1].x;
                float active_phase_mask = i.data[1].y;
                fixed vision_mask =(1-dist*1.5)*flash_time;
                float noise = tex2D(_NoiseTex,i.data[3]).x;
                vision_mask = saturate(vision_mask);
                vision_mask *= foreground_mask*active_phase_mask*i.clr.w;
                fixed2 barier_ring = ring(i.cuv,noise,wave_time)*foreground_mask;
                fixed ring_mask = pulse(dist,wave_progression*.9*foreground_mask,0.1)*wave_time; 
                ring_mask*=active_phase_mask;
                fixed4 grab = tex2D(_WarpPointGrabPass,lerp(i.scrPos.xy,i.data[2].xy,ring_mask+barier_ring.y*4));
                fixed4 vision = fixed4(0,0,0,1);//if we go with using texture of warp point destination
                return fixed4(lerp(
                                    lerp(grab,vision,vision_mask).xyz+barier_ring.y*rippleColor,
                                    fixed3(.02,.02,.02),
                                    barier_ring.x*.8),
                            1);
			}
			ENDCG
		}
    }
}
