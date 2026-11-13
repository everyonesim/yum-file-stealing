Shader "Futile/SpinToy"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
		ZWrite Off
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
			#include "_RippleClip.cginc"
            #pragma multi_compile_local _ glyph

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float2 scrPos : TEXCOORD1;
                float4 clr : COLOR0;
			};
			sampler2D _MainTex;
            sampler2D _PalTex;
			float4 _spriteRect;
			float4 _MainTex_ST;
			float2 _MainTex_TexelSize;
            float _RAIN;

			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos (v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.scrPos = ComputeScreenPos(o.pos).xy;
				o.clr = v.color;
				return o;
			}

            fixed Square(float2 uv, float size){
                return step(abs(uv.x),size)*step(abs(uv.y),size);
            }

			fixed4 frag (v2f i) : SV_Target
            {
                rippleClip(i.scrPos);
                float tilt =i.clr.x*2-1;

                if (tilt == 0)
                    tilt = 0.00001;
                fixed3 light = tex2D(_PalTex,float2(20/32.0, 5/8.0) );
                float3 color = lerp(tex2D(_PalTex,float2(1.5/32.0, 7.5/8.0) ),0.5,.5);
                fixed3 highlight = color+light*0.3*-sign(tilt);
                float2 centeredUv = i.uv*2-1;
                centeredUv*=2;
                float2 topCoord=centeredUv;
                topCoord.y+=(1-abs(tilt))*sign(tilt)*0.76;
                topCoord.y*=1/tilt;
                float time = i.clr.w;
                float circleTime = time*PI;
                float2x2 rotation = rotate2d(-circleTime);
                topCoord = mul(topCoord,rotation);
                topCoord = abs(topCoord);
                topCoord*=1.4;
                fixed square = step(topCoord.x,1)*step(topCoord.y,1);
                fixed p1 = sin((time+1)*PI+PI*1.25);
                fixed p2 = sin((time+0.5)*PI+PI*1.25);
                fixed p3 = sin((time+0)*PI+PI*1.25);
                fixed p4 = sin((time-0.5)*PI+PI*1.25);
                fixed plane1 = (p2<p1)*step(centeredUv.x,p1)*step(p2,centeredUv.x);
                fixed plane2 = (p3<p2)*step(centeredUv.x,p2)*step(p3,centeredUv.x);
                fixed plane3 = (p4<p3)*step(centeredUv.x,p3)*step(p4,centeredUv.x);
                fixed l1 = saturate(iLerp(p1,p2,centeredUv.x));
                fixed l2 = saturate(iLerp(p2,p3,centeredUv.x));
                fixed l3 = saturate(iLerp(p3,p4,centeredUv.x));
                fixed h1 = lerp (p4,p1,l1);
                fixed h2 = lerp (p1,p2,l2);
                fixed h3 = lerp (p2,p3,l3);
                float coord = centeredUv.y;
                coord+=(1-abs(tilt))*sign(tilt)*0.76;
                coord*=1/tilt;
                plane1 *= step(h1,coord);
                plane2 *= step(h2,coord);
                plane3 *= step(h3,coord);
                float a = (1/abs(tilt))*1.518 - abs(tilt)*1.0;
                plane1 *= step(coord,h1+a);
                plane2 *= step(coord,h2+a);
                plane3 *= step(coord,h3+a);

#if glyph
                float2 glyphCoord = centeredUv;
                circleTime = (time*1.05-.025+.5)*PI;
                float sct=sin(circleTime);
                float cct=cos(circleTime)*0.7*tilt;
                glyphCoord+= fixed2(sct,cct)*.7;
                glyphCoord.y-=.300*3*tilt;
                glyphCoord.y-=(1-h2)*-tilt*PI*.25;
                float squish = sin((time)*PI);
                glyphCoord.x *=1.2/squish;
                glyphCoord.y *=1+abs(tilt)*.5;
                float2 size = _MainTex_TexelSize*15;
                glyphCoord = i.clr.yz+glyphCoord*size-size*.42;
                glyphCoord.x = clamp(glyphCoord.x,i.clr.y-size.x,i.clr.y+size.x*.01);
                glyphCoord.y = clamp(glyphCoord.y,i.clr.z-size.y,i.clr.z+size.y*.01);
                color *=.75;
#endif
                fixed mask = (square+plane1+plane2+plane3);
                mask = saturate(mask);
                fixed3 sides = color+light*0.4;
                fixed3 forward = color*0.7;
                fixed3 p1col = lerp(sides,forward,sin((time+.5)*PI));
                fixed3 p2col = lerp(sides,forward,sin(time*PI));
                fixed3 p3col = lerp(sides,forward,sin((time-.5)*PI));
#if glyph
                return fixed4(p2col*sides,tex2D(_MainTex,glyphCoord).w*plane2);
#endif
                fixed3 result = 0;
                result = lerp(result,p1col,plane1);
                result = lerp(result,p2col,plane2);
                result = lerp(result,p3col,plane3);
                result = lerp(result,highlight,square);

                return fixed4(result,mask);
			}
            ENDCG
		}
    }
}
