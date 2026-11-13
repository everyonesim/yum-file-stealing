Shader "Futile/PearlReaderGrab"
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
        GrabPass {"_PearlReaderGrab"}
        UsePass "Futile/RippleGrab/Clear"
    }
}
