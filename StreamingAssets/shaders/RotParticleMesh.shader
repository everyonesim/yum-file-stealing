Shader "Futile/RotParticleMesh"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Cull Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #define PI 3.14159265359

            // Output from compute shader
            struct Particle
            {
	            float2 position;
	            float2 previousPosition;

	            float rotation;
	            float previousRotation;

	            float yRotation;
	            float previousYRotation;

	            int lifetime;
            };

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint id : SV_VertexID;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            StructuredBuffer<Particle> _particleMap;
            float _timeStacker;
            int _rotParticleMeshHideBeforeIndex;
            float4 _Color;

            v2f vert (appdata v)
            {
                v2f o;

                Particle particle = _particleMap[v.id / 4]; //_particleMap.Load(v.id / 4);

                float2 centerPos = lerp(particle.previousPosition, particle.position, _timeStacker);
                float lifetime = (particle.lifetime + _timeStacker) / 200.0;
                float xRot = lerp(particle.previousRotation, particle.rotation, _timeStacker);
                float yRot = lerp(particle.previousYRotation, particle.yRotation, _timeStacker);
                float scaleMultiplier = 4.0 * (lifetime - lifetime * lifetime);
                if (v.id / 4 < _rotParticleMeshHideBeforeIndex) { scaleMultiplier = 0.0; }
                float xRotCos = cos(xRot);
                float xRotSin = sin(xRot);

                float2 pos = v.vertex.xy;

                // Apply scale and Y rotation
                pos.x *= 0.5 * scaleMultiplier;
                pos.y *= 0.35 * cos(yRot) * scaleMultiplier;

                // Apply normal rotation
                pos = float2(
                    pos.x * xRotCos + pos.y * xRotSin,
                    pos.y * xRotCos - pos.x * xRotSin
                );

                // Apply per-particle offset
                pos += centerPos;

                // Apply camera offset
                o.vertex = UnityObjectToClipPos(float4(pos, 0, 1));
                o.uv = TRANSFORM_TEX (v.uv, _MainTex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return tex2D(_MainTex, i.uv) * _Color;
            }
            ENDCG
        }
    }
}
