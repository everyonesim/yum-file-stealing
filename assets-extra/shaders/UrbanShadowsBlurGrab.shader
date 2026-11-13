Shader "Futile/UrbanShadowsBlurGrab"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Blend One One
        ZWrite Off
        Lighting Off
        Cull Off 
        GrabPass {"_UrbanShadowsBlurGrab"}
        UsePass "Futile/RippleGrab/Clear"
    }
}
