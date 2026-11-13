Shader "Futile/Warp"
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
		{
			CGPROGRAM
			#pragma target 4.0
			#pragma vertex vert
			#pragma fragment frag		
            #pragma multi_compile_local _ no_ring
            #pragma multi_compile_local _ through_dark
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
				float4 scrPos : TEXCOORD1;
                float2 cuv : TEXCOORD2;
                float4 data[6] : TEXCOORD3;
				float4 clr : COLOR;
                float2 fall1 : COLOR1;
                float2 fall2 : COLOR2;
			};
			sampler2D _WarpPointGrabPass;
			sampler2D _PalTex;
			sampler2D _MainTex;

			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _WarpPointHoldFrame;

			float2 _LevelTex_TexelSize;
			float2 _screenSize;
			float4 _spriteRect;
			float _RAIN;
			float _warpPointTime;
            float2 _warpPointPosition;
            float2 _warpPointOldPosition;
            float _warpPointAcceleration;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;

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

            float dark_edges(float2 uv,float amount){
                return smoothstep(2-amount*.25+.001,2-amount,length(uv*2-1));
            }

            fixed2 unpack(fixed packedd){ // packed is probably a keyword on PS4
                int2 v = packedd*255;
                return fixed2(v.x&15,v.y>>4)*0.0627450980;
            }

            float annoyingRings(float2 uv, float scale, float t){
                float ratio = _screenSize.x/_screenSize.y;
                uv.x *= ratio;//unhardcode this later
                uv*=scale*4;
                t*=2;
                float len = length(uv);
                float circle = length(uv+circularMotion(t+(len-fmod(len,.31415))*t)*.06);
                float rings = abs(sin(circle*10));
                rings = smoothstep(0.6,1.,rings);
                return rings;
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.cuv = o.uv*2-1;
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);
                fixed2 ab = unpack(o.clr.x);
                fixed2 cd = unpack(o.clr.y);
                fixed2 ef = unpack(o.clr.z);
                fixed2 gh = unpack(o.clr.w);
                //Controlable parameters:
                fixed vignette =ab.y;
                // intensity of vignette effect, 0 = default, 1 = very dark
                fixed darkness =ab.x;
                // intensity of darkness inside the circle and during the transition, 0 = no darkness, 1 = very dark, .4 = default
                fixed spiral_gap =cd.y;
                // how much darkness is in the spiral, 0 = no darkness, 1 = very wide darkness, .5 =default
                fixed swirl_intensity = cd.x;
                // 0=no swirl, 1=too much  swirl, .3 = default
                fixed lensing_intensity = ef.y;
                // 0=no lensing, 1=too much, .5 = default
                fixed noise_intensity = ef.x;
                // 0= no transitional noise distortion at all, 1= way too much noise distortion, .25 = default
                fixed number_of_spirals = .25;
                // 0 = no spirals, 1 = 3 spirals, .25 = default;
                fixed spiral_twist = gh.y;
                // 0 = no twist, 1 = lots of twist, .25 = default
                fixed agitation_speed = gh.x;
                //0 = _RAIN stops, 1 = _RAIN is 4 times as fast, .25 = default

                spiral_gap = lerp(-.3,.25,spiral_gap);//-.3 causes the effect to cut off
                swirl_intensity *=3;
                lensing_intensity *=2;
                noise_intensity *=4;
                number_of_spirals = trunc(number_of_spirals*4);
                spiral_twist *= 120;

                // various progress timers
                float touch = saturate(_warpPointTime+1);//cancelable phase
                float smooth_touch = sinesmooth(touch);
                float warpTime = saturate(_warpPointTime);//active phase                            0.0->.25->0.5->.75->1.0
                float transition = 1-abs(warpTime-.5)*2;//main intensity                            0.0->0.5->1.0->0.5->0.0
                float smooth_transition = sinesmooth(transition);
                float first_swirl = 1-saturate(abs(iLerp(.25,.5,warpTime)));//                      0.0->1.0->0.0->0.0->0.0
                float smooth_first_swirl = sinesmooth(first_swirl);
                float stabilization = saturate(iLerp(.5,1,transition));//                           0.0->0.0->1.0->0.0->0.0
                float smooth_stabilization = sinesmooth(stabilization);
                float bell_transition = smoothstep(0,1,saturate(transition-.5));
                float deactivation = 1-saturate(abs(iLerp(.75,1,warpTime)));// final deactivation   0.0->0.0->0.0->1.0->0.0
                if (warpTime>.75)
                deactivation = smoothstep(0,1,deactivation);
                float smooth_deactivation = sinesmooth(deactivation);
                float new_world = saturate(iLerp(.5,1,warpTime));//fade to new room                 0.0->0.0->0.0->0.5->1.0
                float smooth_new_world = sinesmooth(new_world);
                float second_half = step(0.50001,warpTime);

                float RAIN = _RAIN*agitation_speed*4;
                fixed init_radius = .105; //hadcoded radius hand picked to match
                float radius = init_radius;
                radius +=transition*(1-second_half)+smooth_transition*second_half;

                fixed2 fall_noise_uv1=rotate_around(o.scrPos*1.5,float2(.75,0.75),RAIN*1);
                fixed2 fall_noise_uv2=(o.scrPos*.5-.25)*(2+pulsate(3,.125))+float2(1,RAIN*.25);

                o.data[0] = fixed4(vignette,darkness,spiral_gap,swirl_intensity);
                o.data[1] = fixed4(lensing_intensity,noise_intensity,spiral_twist,agitation_speed);
                o.data[2] = fixed4(RAIN,number_of_spirals,radius,second_half);
                o.data[3] = float4(warpTime,smooth_touch,smooth_first_swirl,smooth_stabilization);
                o.data[4] = float4(transition,smooth_transition,bell_transition,deactivation);
                o.data[5] = float4(smooth_new_world,1,1,1);
                o.fall1 = fall_noise_uv1;
                o.fall2 = fall_noise_uv2;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {

                const float PI = 3.14159265;
                const fixed init_radius = .105; //hadcoded radius hand picked to match
                fixed4 rippleColor = fixed4(.25,.25,1,1);
                float RAIN = i.data[2].x;

                //Controlable parameters:
                fixed vignette = i.data[0].x;
                fixed darkness = i.data[0].y;
                fixed spiral_gap = i.data[0].z;
                fixed swirl_intensity = i.data[0].w;
                fixed lensing_intensity = i.data[1].x;
                fixed noise_intensity = i.data[1].y;
                fixed number_of_spirals = i.data[2].y;
                fixed spiral_twist = i.data[1].z;
                fixed agitation_speed = i.data[1].w;

                float dist = length(i.cuv);
                float angle_rad = atan2(i.cuv.x,i.cuv.y);
                float angle = angle_rad * (0.318310);
                float2 polar_uv = float2(angle,dist);

                // various progress timings
                float warpTime = i.data[3].x;
                float smooth_touch = i.data[3].y;
                float smooth_first_swirl = i.data[3].z;
                float smooth_stabilization = i.data[3].w;
                float transition = i.data[4].x;
                float smooth_transition = i.data[4].y;
                float bell_transition = i.data[4].z;
                float smooth_deactivation = i.data[4].w;
                float smooth_new_world = i.data[5].x;
                float second_half = i.data[2].w;
                float first_half = 1-i.data[2].w;

                
                fixed radius = i.data[2].z;

                float spiral = dist*spiral_twist-RAIN*6+angle_rad*-(second_half*2-1)*number_of_spirals;
                spiral = sin(spiral)*.5+.5;
                spiral *= 1-dist;

                float ratio = _screenSize.x/_screenSize.y;

                fixed circle = saturate(smoothstep(radius+.1*smooth_first_swirl,radius-.01,dist));
                fixed ring = 1-abs(dist-radius);
                fixed static_ring = 1-abs(dist-init_radius);
                fixed lensing_mask = circle*2-1;
#if no_ring
                lensing_mask *= smooth_stabilization;
#endif
                float twist_intensity =0.5+smooth_first_swirl*1;
                float fall_intensity = bell_transition*.5;
                float first_swirl_intensity = smooth_first_swirl+smooth_deactivation;
                lensing_mask*=smooth_touch;
                lensing_mask*=(1-smooth_stabilization)*first_half;
                lensing_mask *=lerp( smoothstep(.99-smooth_touch*.19*twist_intensity,1,ring), smoothstep(.99-smooth_touch*.09*twist_intensity,1,ring), circle);

                float swirling_noise1 = tex2Dlod(_NoiseTex,float4((polar_uv*float2(-1,10-dist*9)+float2(-RAIN*.5*(second_half*2-1),-angle+RAIN*.45*(second_half*2-1))),0,0));
                float swirling_noise2 = tex2Dlod(_NoiseTex,float4(polar_uv*float2(1,-2.8)+float2(RAIN*.25*(second_half*2-1),0),0,0));
                float swirl = swirling_noise1+swirling_noise2;
                swirl += spiral*1.5*(smooth_first_swirl+smooth_new_world);
                float swirl_avg = swirl*.5;
                 swirl_avg*=pulse(dist,.02,.02,8.3);
                swirl=1-swirl;

                float falling_noise1 = tex2D(_NoiseTex,i.fall1);
                float falling_noise2 = tex2D(_NoiseTex,i.fall2);
                float fall = falling_noise1+falling_noise2;
                float fall_avg = fall*.5;
                fall = 1-fall;

                i.scrPos.xy += normalize(i.cuv)*.15*pulse(warpTime,0.1,.1,.2)*pulse(dist,.3,.1,.7)*pulse(dist,.3,.1,.7);
                i.scrPos.xy = mirror(i.scrPos.xy,_screenSize);

                float2 swirl_uv = rotate_around(i.scrPos,_warpPointPosition,first_swirl_intensity*swirl*-(second_half*2-1));
                swirl_uv = scale_from(swirl_uv,_warpPointPosition,1-ring*fall*.5*smooth_first_swirl)-i.scrPos;
                float2 lensed_uv = rotate_around(i.scrPos,_warpPointPosition,lensing_mask*twist_intensity*lerp(swirl,1,smooth_first_swirl));
                lensed_uv = scale_from(lensed_uv,_warpPointPosition,1-ring*lensing_mask*twist_intensity*fall*.5)-i.scrPos;
                float2 fall_uv = scale_from(i.scrPos,normalize(float2(falling_noise2,falling_noise1)),1+fall*fall_intensity)-i.scrPos;
                float2 composite_uv= swirl_uv*swirl_intensity+lensed_uv*lensing_intensity+fall_uv*noise_intensity;

                // Accelerating rings
                float2 ringPos = lerp(_warpPointPosition,_warpPointOldPosition,second_half);
                ringPos = lerp(ringPos,_warpPointPosition,smooth_new_world);
                float len = distance(i.scrPos.xy*ratio , ringPos*ratio)*.5;
                fixed rings = annoyingRings(i.scrPos - ringPos,len*0.55+.4-_warpPointAcceleration*.5+smooth_new_world,_RAIN*.55+_warpPointAcceleration*1-smooth_new_world);
                rings += annoyingRings(i.scrPos - ringPos+circularMotion(_RAIN)*.01,len*0.25+1.05-_warpPointAcceleration*.5+smooth_new_world,_RAIN*0.75+_warpPointAcceleration*0.775-smooth_new_world);
                rings *=len;
                float2 ringsOffset = scale_from(i.scrPos*ratio,ringPos*ratio,1-rings*.1*smoothstep(2,1,_warpPointAcceleration)) - i.scrPos*ratio;
                ringsOffset *= _warpPointAcceleration*2*(1-smooth_new_world);
                
                fixed3 realscreen = tex2D(_WarpPointGrabPass, composite_uv+i.scrPos+ringsOffset*first_half).xyz;
#if through_dark
                fixed3 holdframe = 0;
                spiral_gap = 1;
#else
                fixed3 holdframe = tex2D(_WarpPointHoldFrame, composite_uv+i.scrPos+ringsOffset*second_half).xyz; 
#endif
                fixed warp_mask= lerp((1.-fall_avg*.5),swirl_avg,clamp(ring+.7,0.0,1.0));
                fixed negative = smoothstep(warp_mask-spiral_gap,warp_mask+.1-spiral_gap,(warpTime-.50)*3.5);
                fixed world_mask = smoothstep(warp_mask,warp_mask+.05,(warpTime-.55)*3.2);

                fixed3  composed_result = saturate(lerp(realscreen,holdframe,second_half) - negative);
                composed_result = lerp(composed_result,realscreen,world_mask);
                composed_result *= dark_edges(i.scrPos,smooth_transition*(3*vignette)*(1-negative));

#if no_ring
                swirl *= smooth_stabilization;
                ring *= smooth_stabilization;
                darkness *= smooth_stabilization;
#endif
                //darkening inside the circle
                composed_result *= 1-smoothstep(0.2+transition*2,transition*2,dist+(swirl+fall)*.1)*(darkness*.9-bell_transition*.4*(1-darkness))*smooth_touch*(1-negative)*(1-rippleColor*.4); 

                //bright circle
                composed_result *= 1+smoothstep(0.99,1,ring+composite_uv.x-composite_uv.y)*.4*smooth_touch*first_half*rippleColor; 

                return float4(composed_result,1);

                //DRAW TIMING DEBUG vvvvvvvvvvvvvvv
                // fixed debug = 0;
                // fixed start = .5;
                // fixed length = .25;
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03),length*smooth_touch,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*2),length*warpTime,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*4),length*smooth_first_swirl,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*6),length*smooth_stabilization,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*8),length*bell_transition,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*10),length*smooth_deactivation,.01);
                // debug += draw_stripe(i.scrPos,float2(.25,start-.03*12),length*smooth_new_world,.01);
                // fixed mask = draw_stripe(i.scrPos,float2(.245,start-.03*5),length+.01,.17);
                // composed_result-=mask*.25;
                // composed_result+=debug;
                // return float4(composed_result,1);
                //DRAW TIMING DEBUG ^^^^^^^^^^^^
			}
			ENDCG
		}
	}
}
