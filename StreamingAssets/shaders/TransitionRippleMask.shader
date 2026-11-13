Shader "Futile/TransitionRippleMask"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
        _Openness ("Openness", Float) = 0.0
        _RingsToSpirals ("RingsToSpirals", Float) = 0.0
    }

	SubShader
	{
        Tags { "Queue" = "Geometry"}
		Blend SrcAlpha OneMinusSrcAlpha 
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
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD1;
				float4 clr : COLOR;
                float2 texCoord : TEXCOORD5;
                fixed4 flags : TEXCOORD6;
			};
			float _RAIN;
			sampler2D _NoiseTex;
            uniform float2 _screenOffset;
			sampler2D _RippleLevelTex;
			sampler2D _LevelTex;
            sampler2D _RippleMaskSaved;
			float2 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float2 _screenSize;
			float4 _spriteRect;
            float _Openness;
            float _RingsToSpirals;

            float annoyingRings(float2 uv, float scale, float t){
                uv*=4*scale;
                t*=.1;
                float len = length(uv);
                float circle = length(uv+circularMotion(t+(len-fmod(len+_RAIN,.31415))*t)*.06);
                float rings = abs(sin((circle+_RAIN)*10));
                rings = smoothstep(0.6,1.,rings);
                return rings;
            }

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex)*2-1;
                o.scrPos = ComputeScreenPos(o.pos);
                float2 offset =_spriteRect.xy*fixed2(_screenSize.x/_screenSize.y,1); 
                float2 cuv = o.scrPos*fixed2(_screenSize.x/_screenSize.y,1);
                cuv-=offset;
				o.clr = v.color;
                o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos.xy);
                int a = o.clr.y*255;
                o.flags = fixed4((a&1)>0,(a&2)>0,(a&4)>0,0);
				return o;
			}

            float sineSmooth(float v){
                return saturate(-v*v*(2*v-3));
            }

			fixed4 frag (v2f i) : SV_Target
            {
                float t = fmod(_RAIN,1);
                _Openness = saturate(_Openness*(1.5-_RingsToSpirals*.5f));
                _RingsToSpirals = saturate(_RingsToSpirals);
                fixed intensity = i.clr.x;
                fixed inverted = i.flags.x;
                fixed fallOff = i.clr.z;
                float dist =length(i.uv); 

                float angle = (atan2(i.uv.x,i.uv.y));
                float noise = tex2D(_NoiseTex,float2(angle*0.3183098862-_RAIN*4,dist*40+_RAIN+angle*0.3183098862*2)*.25)*(1-pulse(abs(angle),PI,0.9));
                float ringsScale = saturate(_Openness*4);
                float aRings1 = annoyingRings(i.uv,(4-2*ringsScale)+sin(_RAIN)*.1,-_RAIN*2);
                float aRings2 = annoyingRings(i.uv,(4-3*ringsScale),_RAIN*1);
                float aRings3 = annoyingRings(i.uv,(5.5-2*ringsScale)+sin(_RAIN)*.3,-_RAIN*2.5);
                float expandingSine = sin(dist*99-_RAIN*19);

                float spiralTime = _RAIN-_Openness*5;
                float rings = 1-aRings1*.5+aRings2*.5+aRings3*.3+(expandingSine*.5+.5);
                float spiral1 = sin((dist*20+angle-spiralTime)*3)*.5+.5;
                float spiral2 = sin((dist*37+angle-spiralTime*2.1)*2)*.5+.5;
                float spiral3 = sin((dist*93+angle+spiralTime*3.7)*2)*.5+.5;
                float spirals = (spiral2+spiral1+spiral3*.4)+noise;
                rings +=noise*saturate(1-fallOff*2);

                float closeCircle = smoothstep(0.03+0.1*_Openness,.0,length(i.uv));
                float shape = lerp(rings,spirals,(1-closeCircle)*.5+_RingsToSpirals*.5);
                shape = lerp(shape,1,smoothstep(0.03+0.1*_Openness,.0,length(i.uv)));

                float result = iLerp(fallOff*.3,-.01-shape*(.1+fallOff*0.9)*(1-_Openness)*.1,dist-_Openness)*.3;
                result *= intensity;
                result = smoothstep(0,1,result);

                inverted = 1-inverted;

                return fixed4(inverted,1,inverted*i.flags.z*.5,result);
			}
			ENDCG
		}
	}
}
