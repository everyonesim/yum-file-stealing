Shader "Futile/DustWave"
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
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
                float2 data[5] : TEXCOORD2;
			};
			float EaseOutQuad(float t) {return -1.0 * t * (t - 2.0);}
			float EaseInCubic(float t) {return t * t * t;}
			float EaseInQuad(float t) {return t * t;}
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
			sampler2D _CloudsTex;

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
			float _DustWaveProgress;
			uniform half4 _AboveCloudsAtmosphereColor;

			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*float2(5,1);
				o.clr = v.color;
				float2 yTime = float2(-_RAIN*.1,-_RAIN*2)*(1-o.clr.z)*3;
				o.scrPos = ComputeScreenPos(o.pos);

				float2 uv = o.uv*fixed2(1,1.7)*2+float2(o.clr.x,o.clr.y);

				float2 textCoord = float2(floor(o.scrPos.x*_screenSize.x)/_screenSize.x, floor(o.scrPos.y*_screenSize.y)/_screenSize.y);
				textCoord.x -= _spriteRect.x;
				textCoord.y -= _spriteRect.y;

				textCoord.x /= _spriteRect.z - _spriteRect.x;
				textCoord.y /= _spriteRect.w - _spriteRect.y;

				o.data[0] = uv*.8+yTime;
                o.data[1] = uv*(.5+o.clr.z)*2*1.9134+yTime*2.3;
                o.data[2] = uv*(.5+o.clr.z)*2*2.3513+yTime*4;
				o.data[3] = textCoord;
				o.data[4] = half2(o.scrPos.x, o.scrPos.y);
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// return i.clr.z;

				///////////////////////////////////////////////////////
				// sample the texture
				
				
				
				half4 lvlCol = tex2D(_LevelTex, i.data[3]);
if(lvlCol.x != 1 && lvlCol.y != 1 && lvlCol.z != 1) return half4(0,0,0,0);
//return half4(tex2D(_PalTex, half2(30.0*i.clr.x/32.0, 6.5/8.0)).xyz, 1);
				half4 grabTexCol = tex2D(_GrabTexture, i.data[4]);
				if (grabTexCol.x > 1.0/255.0 || grabTexCol.y != 0.0 || grabTexCol.z != 0.0) return half4(0,0,0,0);


				
				fixed col = tex2D(_CloudsTex, i.data[0]);
                fixed col2 = tex2D(_CloudsTex, i.data[1]);
                fixed col3 = tex2D(_CloudsTex, i.data[2]);
				fixed circle = smoothstep(i.clr.z*.8,1,i.uv.x-(_DustWaveProgress*4-EaseInQuad(i.clr.z)*2)-EaseOutQuad(i.uv.y))*EaseOutQuad(1-i.uv.y)*smoothstep(0,.01,i.uv.y);                
				fixed noiseMix = smoothstep(0,2,(col+(col2+col3)*.4));
				if (col+circle<1) return 0;
				// fixed result = lerp(0,fixed4((fixed3)noiseMix+circle*1.5,1),smoothstep(.5,1,noiseMix+circle) );
				fixed result = noiseMix+circle*1.5;
				return lerp(clamp(result,0,1)*_AboveCloudsAtmosphereColor,result*fixed4(.44*.3,.36*.3,.37*.3,1),1-i.clr.z*.9);
			}
			ENDCG
		}
	}
}
