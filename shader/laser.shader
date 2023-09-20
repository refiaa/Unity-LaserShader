Shader "Refiaa/Laser"
{
    Properties
    {
        _TintColor ("Tint Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _MainTex ("Particle Texture", 2D) = "white" {}
        _Speed ("Horizontal Movement Speed", Range(0, 1)) = 0.1 
        _FlickerProbability ("Flicker Probability", Range(0, 1)) = 0.1 
        _Threshold ("Alpha Threshold", Range(0, 1)) = 0.5 
    }
    
    SubShader
    {
        Tags { "Queue"="Transparent" } 
        LOD 200
        
        Pass
        {
            Cull Off 
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _TintColor;
            float _Speed;
            float _FlickerProbability;
            float _Threshold;

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                float randomOffset = _Speed * (frac(sin(dot(_Time.yx, v.vertex.xy)) * 43758.5453));
                o.uv = v.uv + float2(randomOffset, 0);
                
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {               
                half randomOffset = frac(sin(dot(i.uv, _Time.yx)) * 43758.5453);
                half flicker = step(_FlickerProbability, frac(_Time.y * 10.0 + randomOffset));
                
                half4 texColor = tex2D(_MainTex, i.uv);
                half alpha = texColor.r * flicker; 
                
                if (alpha < _Threshold)
                    discard;
                    
                half4 finalColor = texColor * _TintColor;
                finalColor.a = alpha; 

                return finalColor;
            }
            ENDCG
        }
    }
}
