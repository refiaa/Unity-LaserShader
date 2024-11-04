Shader "Refiaa/Laser_TestSet"
{
    Properties
    {
        _CoreColor ("Core Color", Color) = (1, 1, 1, 1)
        _GlowColor ("Glow Color", Color) = (0.5, 0.5, 0.5, 1)
        _CoreIntensity ("Core Intensity", Range(1, 10)) = 2
        _GlowIntensity ("Glow Intensity", Range(1, 10)) = 1.5
        _CoreThickness ("Core Thickness", Range(0, 1)) = 0.2
        _GlowThickness ("Glow Thickness", Range(0, 1)) = 0.5
        _MainTex ("Laser Texture", 2D) = "white" {}
        _NoiseTexture ("Noise Texture", 2D) = "white" {}
        _NoiseSpeed ("Noise Speed", Range(0, 10)) = 1
        _NoiseStrength ("Noise Strength", Range(0, 1)) = 0.1
        _FlickerSpeed ("Flicker Speed", Range(0, 10)) = 1
        _FlickerIntensity ("Flicker Intensity", Range(0, 1)) = 0.1
    }
    
    SubShader
    {
        Tags { 
            "Queue"="Transparent+100" 
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }
        
        Pass
        {
            ZWrite Off
            ZTest LEqual
            Blend One One
            Cull Off
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 noiseUV : TEXCOORD1;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
            };

            sampler2D _MainTex, _NoiseTexture;
            float4 _MainTex_ST, _NoiseTexture_ST;
            float4 _CoreColor, _GlowColor;
            float _CoreIntensity, _GlowIntensity;
            float _CoreThickness, _GlowThickness;
            float _NoiseSpeed, _NoiseStrength;
            float _FlickerSpeed, _FlickerIntensity;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                o.noiseUV = v.uv * _NoiseTexture_ST.xy + _Time.x * _NoiseSpeed;
                o.color = v.color;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                // noise sampling
                float2 noiseOffset = (tex2D(_NoiseTexture, i.noiseUV).rg * 2 - 1) * _NoiseStrength;
                float2 distortedUV = i.uv + noiseOffset;
                
                float baseTexture = tex2D(_MainTex, distortedUV).r;
                
                // flickering
                float flicker = 1 + sin(_Time.y * _FlickerSpeed) * _FlickerIntensity;
                
                float core = smoothstep(_CoreThickness - 0.1, _CoreThickness, baseTexture);
                float glow = smoothstep(_GlowThickness - 0.2, _GlowThickness, baseTexture);
                
                // final color calc.
                half4 finalColor = 0;
                finalColor += core * _CoreColor * _CoreIntensity * flicker;
                finalColor += glow * _GlowColor * _GlowIntensity * flicker;
                finalColor *= i.color;

                return finalColor;
            }
            ENDCG
        }
    }
}