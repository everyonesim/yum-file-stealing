Shader "Futile/LightningBolt"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}

	}
	SubShader
	{
		Blend One One
		Tags {"Queue"="Transparent" "RenderType"="Transparent"}
		ZWrite Off
		Fog { Color(0,0,0,0) }
		Lighting Off
		Cull Off //we can turn backface culling off because we know nothing will be facing backwards
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
			#include "_RippleClip.cginc"


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
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _NoiseTex;
			sampler2D _LevelTex;
			float2 _screenSize;
			float4 _spriteRect;
			float4 _EffectColor;
			float _RAIN;
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.clr = v.color;
				o.scrPos = ComputeScreenPos(o.pos);

				return o;
			}
			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
			}
			float inver(float col){
			col = col*-1+1;
			return col;
			}
			float getDepth(float level){
				level = round(level*255);
				float sky = inver(step(level,254))*31;
				float shadows = inver(step(level,90))*90;
				float flat = level-shadows;
				float depth = (int(flat-1) % 30)+sky;
			return depth;
			}
			float cubicPulse( float c, float w, float x )
			{
				x = abs(x - c);
				if( x>w ) return 0.0;
				x /= w;
				return 1.0 - x*x*(3.0-2.0*x);
			}
			fixed4 frag (v2f i) : SV_Target
			{
				// _RAIN*=2;
                rippleClip(i.scrPos);
				float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;
				float Depth = 1-step(getDepth(tex2D(_LevelTex,textCoord).x),4);

				float _Input = i.clr.x;
				float _Input2 = i.clr.y;
				float _Input3 = i.clr.z;
				float4 color = float4(hsv2rgb(float3(_Input3,1,1)),1);
				float2 uv = i.uv*2-1;
				float2 scrPos = (i.scrPos.xy/i.scrPos.w)+i.clr.w;
				scrPos = float2(scrPos.x*1.75+_RAIN*2,scrPos.y+frac(_RAIN*.4));
				float noise = tex2D(_NoiseTex, scrPos);
								float bigNoise = noise;
				noise = noise*2-1;
				noise -= (tex2D(_NoiseTex, scrPos+float2(sin(noise+_RAIN),cos(noise+_RAIN*2)))*2-1)*.3;
				float fallOff = smoothstep(1,0,abs(uv.y));
				float fadeOut = 1-smoothstep(0,.1,fallOff);
				float fadeOut2 = smoothstep(0,.6,fallOff);
				float thunderShaft =1-abs(uv.x+noise*bigNoise*fallOff+noise*fallOff*.3)-clamp(fadeOut,0,1);
				float thunderShaft2 =1-abs(uv.x+noise*bigNoise*fallOff*fallOff*.3)-clamp(fadeOut,0,1);
				// fallOff = lerp(smoothstep(_Input*2,0,fallOff),smoothstep(1-_Input*2,1,fallOff),_Input);
				// fallOff = smoothstep(1-_Input*2,1,fallOff);
				float middle = smoothstep(1-_Input*2,1,fallOff);
				float outwards = smoothstep(1-_Input*2,1,_Input*4-fallOff);
				float start = smoothstep(1-_Input*2,1,_Input-fallOff+2.4*_Input-clamp(uv.y,0,1)*5);
				float end = smoothstep(1-_Input*2,1,_Input-fallOff+2.4*_Input+clamp(uv.y,-1,0)*5);
				float one = lerp(start,end,clamp(smoothstep(0,.33,_Input2),0,1));
				float two = lerp(outwards,middle,clamp(smoothstep(.66,1,_Input2),0,1));
				one = lerp(one,two,clamp(smoothstep(.33,.66,_Input2),0,1));
				// fallOff = outwards;
				fallOff = one;
				float shaftBloom = smoothstep(.9-fallOff*.1,1,thunderShaft)*.1*(1-1*(1-fallOff))+smoothstep(.5-fallOff*.3,1,thunderShaft2)*.1*(1-1*(1-fallOff))*.6;
				return (step(1-thunderShaft,.01)*(1-1*(1-fallOff))+(shaftBloom+_Input*shaftBloom)*color)*(fadeOut2+step(1-thunderShaft,.01))*Depth;

			}
			ENDCG
		}
	}
}
