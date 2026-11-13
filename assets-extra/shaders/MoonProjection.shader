Shader "Futile/MoonProjection"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend OneMinusDstColor One
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
			#pragma exclude_renderers OpenGL



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
				float2 data[7] : TEXCOORD2;
			};
			#if defined(SHADER_API_PSSL)
			sampler2D _GrabTexture;
			#else
			sampler2D _GrabTexture : register(s0);
			#endif
			// sampler2D _PalTex;
			// float _light = 0;
			sampler2D _MainTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			sampler2D _LevelTex;
			float2 _LevelTex_TexelSize;
			// float4 _lightDirAndPixelSize;
			float2 _screenSize;
			float4 _spriteRect;
			// float4 _EffectColor;
			// float _WetTerrain;
			// float _waterLevel;
			float _RAIN;
			// float _cloudsSpeed;
			// float _fogAmount;
			sampler2D _NoiseTex;
			sampler2D _NoiseTex2;
			//float4 _Color;
			uniform float _waterPosition;
			uniform float4 _lightDirAndPixelSize;


			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);

				float2 textCoord = float2(floor(o.scrPos.x*_screenSize.x)/_screenSize.x, floor(o.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;



				o.data[0]=o.uv*float2(1.3,2.3)+float2(0,_RAIN*2.7);
				o.data[1]=o.uv*float2(1.8,2)+float2(0,-_RAIN*3);
				o.data[2]=o.uv*float2(0,6)+float2(0,_RAIN);
				o.data[3]=o.uv.xy*float2(0,4)-float2(0,_RAIN);
				o.data[4]=o.uv.xy*.01+float2(0,_RAIN);
				o.data[5]= textCoord;
				o.data[6]= float2(o.scrPos.x, o.scrPos.y);
				return o;
			}
			float easeExpoOut(float t) {
    			return (t == 1.0) ? 1.0 : (-pow(2.0, -10.0 * t) + 1.0);
			}
			float easeExpoIn(float t) {
				return (t == 0.0) ? 0.0 : pow(2.0, 10.0 * (t - 1.0));
			}
			float pulse(float pos, float width, float x){x = smoothstep(1.-width,1.,1.-abs((x-pos)));return x;}
			fixed4 frag (v2f i) : SV_Target
			{


				
				///////////////////////////////////////////////////////
				// sample the texture
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;
				textCoord.y += .01;

				// half4 grabColor = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
				half4 grabColor = tex2D(_GrabTexture, i.data[6]);
				if( grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) return half4(0,0,0,0);		
				// half4 texcol = tex2D(_LevelTex, textCoord);
				half4 texcol = tex2D(_LevelTex, i.data[5]);
				int red = fmod(round(texcol.x * 255)-1, 30.0);
								half depth = red/30.0;
				half2 displace = depth*.05;
				if(red < 6) return half4(0,0,0,0);
				half smallNoise1 = tex2D(_NoiseTex2,i.data[0]).x;
				half smallNoise2 = tex2D(_NoiseTex2,i.data[1]).y;
				
				// half noise = tex2D(_NoiseTex,i.uv.xy*float2(0,6)+float2(0,_RAIN) + half2(displace.x, -displace.y)).x*2-1;
				half noise = tex2D(_NoiseTex,i.data[2]).x*2-1;
				// noise += tex2D(_NoiseTex,i.uv.xy*float2(0,4)-float2(0,_RAIN) + half2(displace.x, -displace.y)).x*2-1;
				noise += tex2D(_NoiseTex,i.data[3]).x*2-1;
				// half whiteoutNoise = tex2D(_NoiseTex,i.uv.xy*.01+float2(0,_RAIN) + half2(displace.x, -displace.y)).x*2-1;
				half whiteoutNoise = tex2D(_NoiseTex,i.data[4]).x*2-1;
				half mask = easeExpoOut(pulse(.5,.25,textCoord.x+noise*.01))*easeExpoOut(pulse(.5,.46,textCoord.y));
				half whiteoutmask = easeExpoOut(pulse(.5,.2,textCoord.x+noise*.01))*easeExpoOut(pulse(.5,.24,textCoord.y));
				half noisemask = clamp(smoothstep(1.2,0.4,pulse(.5,.4,(textCoord.x))*pulse(.5,.8,(textCoord.y))),0,1);
				mask = smoothstep(0,1,mask);
				float rim = pulse(.7,.5,mask);
				smallNoise1 = (smallNoise1+smallNoise2)*.5;
				mask -= (smallNoise1*noisemask);

				// half2 displace = -_lightDirAndPixelSize.xy;
				// displace.x *= _lightDirAndPixelSize.z * depth;
				// displace.y *= _lightDirAndPixelSize.w * depth;
				half4 clr = tex2D(_MainTex,i.uv.xy + half2(displace.x+whiteoutNoise*.005*pulse(.5,.4,textCoord.y), -displace.y));
				half mono = max(max(clr.x,clr.y),clr.z);
			clr=lerp(clr,mono,whiteoutNoise*0.8*whiteoutmask)*clr.w*(easeExpoOut(mask)*.5+easeExpoIn(rim));
				return clr;
			}
			ENDCG
		}
	}
}
