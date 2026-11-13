Shader "Futile/BlizzardReduction"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_firstPass ("_firstPass", Range(0,1)) = 1
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


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;

				float2 sampleCoord[10] : TEXCOORD1;
				float2 quadUV : TEXCOORD11;

			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float2 _MainTex_TexelSize;
			sampler2D _WindTexRendered;
			float2 _WindTexRendered_TexelSize;
			float2 _PlayerPos;
			float _firstPass;


			float easeQuadIn(float t) {
			return t * t;
			}

			 float2 remapUV(float2 st,float2 orgTS,float2 newTS,float2 pos,float scale)
			{
				newTS*=easeQuadIn(1.+scale*0.05+easeQuadIn(scale*0.11));
				float2 ratio = orgTS/newTS;
				st=st-.5;
				st = st*ratio;
				st=st+pos;
				return st;
			}

			v2f vert (appdata_full v)
			{
				v2f o;
				o.quadUV = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.pos = UnityObjectToClipPos (v.vertex);
				sampler2D _WindTex = _WindTexRendered;
				// float2 offset = 1/_MainTex_TexelSize;
				// if (_firstPass > 0.5)
				// {
				// offset = _WindTexRendered_TexelSize*offset;
				// o.uv = float2(lerp(_PlayerPos.x-offset.x,o.uv.x+offset.x,o.uv.x),lerp(_PlayerPos.y-offset.y,o.uv.y+offset.y,o.uv.y));
				// o.uv = o.uv+float2(_WindTexRendered_TexelSize.x*.5,_WindTexRendered_TexelSize.y*.5);
				// o.sampleCoord[0] = o.uv-float2(_WindTexRendered_TexelSize.x*.5,0);
				// o.sampleCoord[1] = o.uv-float2(0,_WindTexRendered_TexelSize.y*.5);
				// }
				// else
				// {
				// o.uv = o.uv+float2(_MainTex_TexelSize.x*.5,_MainTex_TexelSize.y*.5);
				// 	o.sampleCoord[0] = o.uv-float2(_MainTex_TexelSize.x*.5,0);
				//     o.sampleCoord[1] = o.uv-float2(0,_MainTex_TexelSize.y*.5);
				// }
				float2 offset = 1/_MainTex_TexelSize;

				if (_firstPass > 0.5)
				{
				offset = _WindTexRendered_TexelSize*offset;
				o.uv = float2(lerp(_PlayerPos.x-offset.x,_PlayerPos.x+offset.x,o.quadUV.x),lerp(_PlayerPos.y-offset.y,_PlayerPos.y+offset.y,o.quadUV.y));
				o.uv = o.uv+float2(_WindTexRendered_TexelSize.x*.5,_WindTexRendered_TexelSize.y*.5);
				// o.sampleCoord[0] = o.uv-float2(_WindTexRendered_TexelSize.x,0);
				// o.sampleCoord[1] = o.uv-float2(0,_WindTexRendered_TexelSize.y);
				// o.sampleCoord[2] = o.uv-_WindTexRendered_TexelSize;
				// o.sampleCoord[3] = o.uv+float2(_WindTexRendered_TexelSize.x,0);
				// o.sampleCoord[4] = o.uv+float2(0,_WindTexRendered_TexelSize.y);
				 for(int k = 0;k<10;k++)
					{
					o.sampleCoord[k]=remapUV(o.quadUV,_WindTexRendered_TexelSize,_MainTex_TexelSize,_PlayerPos,k);
					}
				}
				else
				{
				o.uv = o.quadUV+float2(_MainTex_TexelSize.x*.5,_MainTex_TexelSize.y*.5);
					o.sampleCoord[0] = o.uv-float2(_MainTex_TexelSize.x,0);
				    o.sampleCoord[1] = o.uv-float2(0,_MainTex_TexelSize.y);
				    o.sampleCoord[2] = o.uv-_MainTex_TexelSize;
				    o.sampleCoord[3] = 0;
				    o.sampleCoord[4] = 0;
				    o.sampleCoord[5] = 0;
				    o.sampleCoord[6] = 0;
				    o.sampleCoord[7] = 0;
				    o.sampleCoord[8] = 0;
				    o.sampleCoord[9] = 0;
				}
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				sampler2D _WindTex = _WindTexRendered;

				// fixed2 col = tex2D(_MainTex,i.uv).xy;
				// fixed2 colL = tex2D(_MainTex,i.sampleCoord[0]).xy;
				// fixed2 colU = tex2D(_MainTex,i.sampleCoord[1]).xy;
				// col = fixed2(max(max(col.x,colL.x),colU.x),max(max(col.y,colL.y),colU.y));
				// fixed2 retCol = col;
				// if (_firstPass > 0.5)
				// {
				// fixed dist = clamp(1-distance(_PlayerPos,i.uv),0,1);
				// col = tex2D(_WindTex,i.uv).xy;
				// colL = tex2D(_WindTex,i.sampleCoord[0]).xy;
				// colU = tex2D(_WindTex,i.sampleCoord[1]).xy;
				// col = fixed2(max(max(col.x,colL.x),colU.x),max(max(col.y,colL.y),colU.y))*dist;
				// retCol = (col.y,0);
				// if (i.uv.x>_PlayerPos.x)
				// {
				// 	retCol = (0,col.y);
				// }
				// }
				// col = retCol;

				
				// return fixed4(col.x,col.y,0,1);
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed4 colL = tex2D(_MainTex, i.sampleCoord[0]);
				fixed4 colU = tex2D(_MainTex, i.sampleCoord[1]);
				fixed4 colLU = tex2D(_MainTex, i.sampleCoord[2]);
				col = max(max(max(col,colL),colU),colLU);
				fixed dist = 0;
				if (_firstPass > .5)
				{
					// dist = clamp(smoothstep(.5,1,1-distance(i.quadUV,.5)),0,1);
					// col = tex2D(_WindTex, i.uv);
					// colL = tex2D(_WindTex, i.sampleCoord[0]);
					// colU = tex2D(_WindTex, i.sampleCoord[1]);
					// colLU = tex2D(_WindTex, i.sampleCoord[2]);
					// fixed4 colR = tex2D(_WindTex, i.sampleCoord[3]);
					// fixed4 colD = tex2D(_WindTex, i.sampleCoord[4]);

					// float range = 1;
					// float div = clamp(smoothstep(_PlayerPos.x+_WindTexRendered_TexelSize.x*range,_PlayerPos.x-_WindTexRendered_TexelSize.x*range,i.uv.x),0,1);
					// fixed obstruct = (colL.x+colU.x+colR.x+colD.x)*0.25;
					// obstruct=obstruct*obstruct*obstruct;
					// col = max(max(max(col,colL),colU),colLU)*dist*obstruct;
					// col = fixed4(col.y*div,col.y*(1-div),col.z,1);

					col = tex2D(_WindTexRendered, i.sampleCoord[0]);
					float occlusion = 1;
					dist = clamp(smoothstep(-.5,1,1-distance(i.quadUV,.5)),0,1);
					 for(int k = 0;k<10;k++)
					{
					occlusion*=tex2D(_WindTexRendered,i.sampleCoord[k]).x;	
					}
					occlusion = step(.5,occlusion);				
					col = col*occlusion;
					float range = 5;
					_PlayerPos+=_WindTexRendered_TexelSize.x*.6;
					float div1 = clamp(smoothstep(_PlayerPos.x,_PlayerPos.x-_WindTexRendered_TexelSize.x*range,i.uv.x),0,1);
					float div2 = clamp(smoothstep(_PlayerPos.x+_WindTexRendered_TexelSize.x*range,_PlayerPos.x,i.uv.x),0,1);
					col = fixed4(col.y*div2,col.y*(1-div1),0,1);
					
				}
				return fixed4(col.xyz,1);
			}
			ENDCG
		}
	}
}
