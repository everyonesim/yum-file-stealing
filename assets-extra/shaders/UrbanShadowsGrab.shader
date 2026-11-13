Shader "Futile/UrbanShadowsGrab"
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
        GrabPass {"_UrbanShadowsGrab"}
        UsePass "Futile/RippleGrab/Clear"
    }
}
