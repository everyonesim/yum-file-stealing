// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

	
// Upgrade NOTE: replaced 'samplerRECT' with 'sampler2D'

//from http://forum.unity3d.com/threads/68402-Making-a-2D-game-for-iPhone-iPad-and-need-better-performance

Shader "Futile/EnergySwirl" //Unlit Transparent Vertex Colored Additive 
{
Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
		
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		ZWrite Off
		//Alphatest Greater 0
		Blend One One
		Fog { Color(0,0,0,0) }
		Lighting Off
		Cull Off //we can turn backface culling off because we know nothing will be facing backwards

		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}

		SubShader   
		{
			//GrabPass { }
				Pass 
			{
				//SetTexture [_MainTex] 
				//{
				//	Combine texture * primary
				//}
				
				
				
CGPROGRAM
#pragma target 4.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"

//#pragma profileoption NumTemps=64
//#pragma profileoption NumInstructionSlots=2048

//float4 _Color;


#if defined(SHADER_API_PSSL)
sampler2D _GrabTexture;
#else
sampler2D _GrabTexture : register(s0);
#endif
sampler2D _MainTex;
sampler2D _NoiseTex;
sampler2D _NoiseTex2;
sampler2D _LevelTex;
sampler2D _EnergySwirl;
float2 _EnergySwirl_TexelSize;
float2 _LevelTex_TexelSize;
uniform float2 _screenSize;
uniform float4 _spriteRect;
uniform float _RAIN;


struct v2f {
    float4  pos : SV_POSITION;
    float2  uv : TEXCOORD0;
    float4 scrPos : TEXCOORD1;
    float4 clr : COLOR;
	float2 data[2] : TEXCOORD2;
};

float4 _MainTex_ST;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.clr = v.color;
	o.data[0]=float2(floor(o.scrPos.x*_screenSize.x)/_screenSize.x, floor(o.scrPos.y*_screenSize.y)/_screenSize.y);
	o.data[1]=o.data[0];
	o.data[1].x -= _spriteRect.x;
	o.data[1].y -= _spriteRect.y;

	o.data[1].x /= _spriteRect.z - _spriteRect.x;
	o.data[1].y /= _spriteRect.w - _spriteRect.y;
	
    return o;
}

float rand (float2 seed)
{
   float rnd = tex2D(_NoiseTex, seed- float2(0,_RAIN*0.1)).x;
   return rnd*3;
}

//                                                                      RGB 2 HSV
float3 rgb2hsv(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
//                                                                      HSV  2  RGB
float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

//																						 INVERT
float invert(float col){
			col = col*-1+1;
			return col;
}
//																						 GET DEPTH
float getDepth(float level){
				level = round(level*255);
				float sky = invert(step(level,254))*31;
				float shadows = invert(step(level,90))*90;
				float flat = level-shadows;
				float depth = (int(flat-1) % 30)+sky;
			return depth;
}

//																					 FRAGMENT SHADER
half4 frag (v2f i) : SV_Target
{

	
	int sDepth = trunc(i.clr.w*30);
	float bS = 8;
	float2 textCoord = float2(floor(i.scrPos.x*_screenSize.x)/_screenSize.x, floor(i.scrPos.y*_screenSize.y)/_screenSize.y);

	half h = 0.0;
	half sn = 0.0;
		for(int j = 0; j < 4; j++)
		{
		h += tex2D(_NoiseTex, half2(i.data[0].x*0.25, i.data[0].y*0.125 + _RAIN*0.5) + normalize(half2(0.5, 0.5) - i.uv) * 0.2*j).x;
		sn  += tex2D(_NoiseTex2, half2(i.data[0].x*0.25, i.data[0].y*0.125 + _RAIN*0.5) + normalize(half2(0.5, 0.5) - i.uv+rand(i.data[0])) * 0.1*j).x;
		}
		 h/=4.0;
		 sn /=4.0;
		 
		 h = lerp(-1,1, h);
		 sn  = lerp(-1,1, sn );
	
	textCoord.x -= _spriteRect.x;
	textCoord.y -= _spriteRect.y;

	textCoord.x /= _spriteRect.z - _spriteRect.x;
	textCoord.y /= _spriteRect.w - _spriteRect.y;
	
		
	
	float frames = 25;
	int t = trunc((_Time*20+rand(i.data[1]))*1000);
	float time = trunc(((t % 1000)/1000.0f)*frames)/frames;
	int tD = trunc(_Time*1000*20);
	float timeUndistorted = trunc(((tD % 1000)/1000.0f)*frames)/frames;
	float2 sTexCoord = float2(i.uv.x+h*.05,(i.uv.y/frames+time)+h*0.002);
	float2 sTexCoordUndistorted = float2(i.uv.x,(i.uv.y/frames+time));
	float tex = tex2D(_EnergySwirl,sTexCoord).x;
	float level = tex2D(_LevelTex, i.data[1]).x;
	float Depth = getDepth(level);






	half2 grabPos = half2(i.scrPos.x, i.scrPos.y);
	grabPos.x = (floor(grabPos.x*_screenSize.x)+0.5)/_screenSize.x;
	grabPos.y = (floor(grabPos.y*_screenSize.y)+0.5)/_screenSize.y;
	//half4 grabPass = tex2D(_GrabTexture, grabPos);
	float depth = getDepth(level);
	float bDepth = 0;
	float bSprite = 0;
//                                       BLUR THE DEPTH
		int2 pxOffset = int2(-1,1);
					for (int b = 0; b< bS; b++){
						for (int j = 0; j < 2; j++){
							for (int k = 0; k <2; k++) {
								 bDepth += getDepth(tex2D(_LevelTex, float2(i.data[1].x+_LevelTex_TexelSize.x*b*pxOffset[j],i.data[1].y+_LevelTex_TexelSize.y*b*pxOffset[k])).x);
							}
						}
					}
//                                       BLUR THE SPRITE					
		for (int b = 0; b< bS*.5; b++){
						for (int j = 0; j < 2; j++){
							for (int k = 0; k <2; k++) {
								  bSprite += tex2D(_EnergySwirl, float2(sTexCoordUndistorted.x+_EnergySwirl_TexelSize.x*b*pxOffset[j],sTexCoordUndistorted.y+_EnergySwirl_TexelSize.y*b*pxOffset[k])).x;
							}
						}
					}
					float blendStep = 0.33;
					float blendOffset = 1.1;
		 bDepth  /=(4*bS);
		 bSprite  /=(4*bS*.5);

		half col = tex*invert(step(Depth,sDepth))+(bSprite*invert((step(bDepth,sDepth+blendOffset-blendStep)+step(bDepth,sDepth+blendOffset-blendStep*2)+step(bDepth,sDepth+blendOffset-blendStep*3)+step(bDepth,sDepth+blendOffset-blendStep*4))/4));
		// half col = tex*invert(step(Depth,sDepth));
		half3 color = rgb2hsv(i.clr.xyz);
		color+=sn *.1;
		color= hsv2rgb(color);
		//return 	float4(grabPass.x,grabPass.y,grabPass.z,col)+float4(color.xyz,1.0f)*col*.8;
		half4 grabColor = tex2D(_GrabTexture, half2(i.scrPos.x, i.scrPos.y));
					// return grabColor;
					if( grabColor.x > 1.0/255.0 || grabColor.y != 0.0 || grabColor.z != 0.0) 
					{
					return half4(0,0,0,0);
					}
		return 	float4(color.xyz,1.0f)*col*.8;
		//return i.clr.w;

	 

}
ENDCG
				
				
				
			}
		} 
	}
}