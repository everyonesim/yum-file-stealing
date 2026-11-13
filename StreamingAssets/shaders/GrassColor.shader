Shader "Futile/GrassColor"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="False" "RenderType"="Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha 
        // Blend SrcAlpha One
		ZWrite Off
		Lighting Off
		Cull Off 
		BindChannels 
		{
			Bind "Vertex", vertex
			Bind "texcoord", texcoord 
			Bind "Color", color 
		}
        GrabPass{"_PreGrassGrab"}
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
#include "_DynamicLevelElementFunctions.cginc"
#include "SlopedTerrain/TerrainCommon.cginc"
#include "_TerrainMask.cginc"

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
    float2 texCoord : texcoord2;
    float3 terrainCol: COLOR1;
    float3 darkGoo: COLOR2;
};

sampler2D _MainTex;
sampler2D _PreLevelColorGrab;
sampler2D _PreGrassGrab;
float4 _MainTex_ST;
float2 _MainTex_TexelSize;

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    float2 rippleParams = 0;

    float dpth = .9-o.clr.x*1.08;
    half4 ambientColor = PaletteSurfaceColor(.3, dpth, 1, rippleParams);
    o.darkGoo = LevelPalette(0.5 / 32.0, 0.5 / 8.0, rippleParams).xyz;
    o.terrainCol = ambientColor.xyz*.93;;
    return o;
}

float2 QuantizeToPixels(float2 coord){
    float2 pixel = 1/_screenSize;
    return coord - fmod(coord, pixel);
}

fixed4 frag (v2f i) : SV_Target
{
    fixed4 levelTex = tex2D(_LevelTex, i.texCoord);
    if (distance(i.clr.y,levelTex.z)>0.004 || levelTex.z == 1) discard;
    fixed4 creatures =  tex2D(_PreLevelColorGrab,i.scrPos);
    fixed creatureMask = creatures != 0 ;
    if (i.clr.x < creatureMask * (1-0.0333333333*6)) discard;
    fixed4 grab = tex2D(_PreGrassGrab,i.scrPos);
    grab = lerp(i.terrainCol.xyzz,grab,saturate(i.uv.y*.5-i.clr.z*.25));
    grab = lerp(grab, lightness(grab).xxxx*1.4 * i.terrainCol.xyzz,i.uv.y);
    if (i.clr.x>1-0.072)
        grab.xyz = lerp(grab.xyz,i.darkGoo,smoothstep(.7,.1,i.uv.y));
    grab.w = 1;
    smoothRippleClip(grab,i.scrPos);
    return fixed4(grab);
}
ENDCG
		}
    }
}
