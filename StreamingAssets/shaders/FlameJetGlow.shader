Shader "Futile/FlameJetGlow" 
{
	Properties 
	{
		_MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}
	}
	
	Category 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
		ZWrite Off
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
            GrabPass{}
				Pass 
			{
            Blend SrcAlpha OneMinusSrcAlpha 
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"
#include "_ShaderFix.cginc"
#include "_RippleClip.cginc"
#include "_Functions.cginc"
#include "_FlameJet.cginc"

v2f vert (appdata_full v)
{
    v2f o;
    o.pos = UnityObjectToClipPos (v.vertex);
    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
    o.scrPos = ComputeScreenPos(o.pos);
    o.texCoord = iLerp(_spriteRect.xy,_spriteRect.zw,o.scrPos);
    o.clr = v.color;
    return o;
}

half4 frag (v2f i) : SV_Target
{
    rippleClip(i.scrPos);
    fixed4 grab = tex2D(_GrabTexture,i.scrPos);
    fixed4 flame = flameJet(i);
    return fixed4(grab.xyz+flame.xyz,smoothstep(0,.1,flame.w));
}

ENDCG
}

		} 
	}
}
