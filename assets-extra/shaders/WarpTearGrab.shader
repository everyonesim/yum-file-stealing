Shader "Futile/WarpTearGrab"
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
        GrabPass {"_WarpTearGrab"}
        UsePass "Futile/RippleGrab/Clear"
    }
}
