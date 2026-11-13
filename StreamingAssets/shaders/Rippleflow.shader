Shader "Futile/RippleFlow"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Tags { "Queue" = "Geometry"}
		Blend SrcAlpha OneMinusSrcAlpha 
		// Blend One One 
		ZWrite Off
		//Alphatest Greater 0
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
            #include "_Functions.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
                float2 texCoord : TEXCOORD2;
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
			};
			float _RAIN;
			sampler2D _NoiseTex;
			sampler2D _CloudsTex;
            uniform float2 _screenOffset;
			sampler2D _RippleLevelTex;
			sampler2D _LevelTex;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float2 _screenSize;
			float4 _spriteRect;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
                o.scrPos = ComputeScreenPos(o.pos);
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
				o.clr = v.color;
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
            {
                fixed sDepth = get_depth01_sat(tex2D(_LevelTex,i.texCoord).x);
                fixed speed = i.clr.x*2-1;
                fixed speed_scale = abs(speed);
                fixed n1 = tex2D(_CloudsTex,i.uv*((.65432+speed_scale*.3))+circularMotion(+_RAIN)*.25+float2(_RAIN*5*speed,i.uv.x*-.377*speed_scale+_RAIN*speed));
                n1 = saturate(n1*1.5-.6);
                fixed n2 = tex2D(_NoiseTex,i.uv*((.3111+speed_scale*.73),.9)+float2(_RAIN*6*speed,0));
                fixed n3 = tex2D(_NoiseTex,i.uv*((.111+speed_scale*1.13))+float2(_RAIN*4*speed,i.uv.x*.5*speed_scale+_RAIN*speed*5));
                fixed s = sin(i.uv.x*10+_RAIN*40*speed);
                fixed n = n1+n2+n3+smoothstep(.5,0,abs(i.uv.y))*.5;
                sDepth=(1-sDepth)*abs(i.clr.z*2-1); 
                i.uv.y+=s*.1;
                i.clr.y= saturate(i.clr.y-sDepth);
                float edge = saturate(smoothstep(.95,.80,abs(i.uv.y)));
                return fixed4(edge,0,0,smoothstep(1.,0.3,abs(i.uv.x))*.25*n*smoothstep(1,0.5+n2*.3,abs(i.uv.y))*i.clr.y);
			}
			ENDCG
		}
	}
}
