Shader "Futile/GameplayRippleGrab"
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
        GrabPass {"_GameplayRippleMask"}
        UsePass "Futile/RippleGrab/Clear"
    }
}
