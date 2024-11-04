Shader "Refiaa/Laser"
{
    Properties
    {
        [HDR] _CoreColor ("Core Color", Color) = (1, 1, 1, 1)
        [HDR] _GlowColor ("Glow Color", Color) = (0.5, 0.5, 0.5, 1)

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

        _DistanceScale ("Distance Scale", Range(0.1, 10)) = 1
        _MinVisibility ("Minimum Visibility", Range(0, 1)) = 0.2
        _FadeDistance ("Fade Distance", Range(0.1, 10)) = 5
        _ForceVisible ("Force Visible", Range(0, 1)) = 1
        
        [Toggle] _UseWorldScale ("Use World Scale", Float) = 1
    }
    
    SubShader
    {
        Tags { 
            "Queue"="Transparent+100" 
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
            "VRCFallback"="Hidden"
        }
        
        Pass
        {
            ZWrite On
            ColorMask 0
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
            };
            
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                return 0;
            }
            ENDCG
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
            #pragma multi_compile_fog
            #pragma target 3.0
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 noiseUV : TEXCOORD1;
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float4 worldPos : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 normalDir : TEXCOORD4;
                UNITY_FOG_COORDS(5)
            };

            sampler2D _MainTex, _NoiseTexture;
            float4 _MainTex_ST, _NoiseTexture_ST;
            float4 _CoreColor, _GlowColor;
            float _CoreIntensity, _GlowIntensity;
            float _CoreThickness, _GlowThickness;
            float _NoiseSpeed, _NoiseStrength;
            float _FlickerSpeed, _FlickerIntensity;
            float _DistanceScale, _MinVisibility;
            float _FadeDistance, _ForceVisible;
            float _UseWorldScale;

            v2f vert(appdata v)
            {
                v2f o;
                
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                float3 worldScale = float3(
                    length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
                    length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
                    length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))
                );
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = worldPos;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos.xyz);
                
                float scaleEffect = _UseWorldScale ? length(worldScale.xy) : 1;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex) / max(scaleEffect, 0.01);
                
                float dist = length(_WorldSpaceCameraPos - worldPos.xyz);
                float distanceScale = saturate(dist / _FadeDistance);
                o.uv.x *= lerp(1, 2, distanceScale);
                
                o.noiseUV = v.uv * _NoiseTexture_ST.xy + _Time.x * _NoiseSpeed;
                o.color = v.color;
                
                UNITY_TRANSFER_FOG(o, o.vertex);
                return o;
            }

            float3 rgb2hsv(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 hsv2rgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            half4 frag(v2f i) : SV_Target
            {
                float NdotV = abs(dot(i.normalDir, i.viewDir));
                
                float dist = length(_WorldSpaceCameraPos - i.worldPos.xyz);
                float distanceFactor = saturate(dist / _FadeDistance);
                
                float visibilityFactor = lerp(_MinVisibility, 1.0, distanceFactor);
                visibilityFactor = max(visibilityFactor, _ForceVisible);
                
                float2 noiseOffset = (tex2D(_NoiseTexture, i.noiseUV).rg * 2 - 1) * _NoiseStrength;
                float2 distortedUV = i.uv + noiseOffset * visibilityFactor;
                
                float baseTexture = tex2D(_MainTex, distortedUV).r;
                
                float timeValue = _Time.y * _FlickerSpeed;
                float flicker = 1 + sin(timeValue) * cos(timeValue * 0.5) * _FlickerIntensity;
                flicker = lerp(1, flicker, visibilityFactor);
                
                float adjustedCoreThickness = lerp(_CoreThickness * 1.2, _CoreThickness, distanceFactor);
                float adjustedGlowThickness = lerp(_GlowThickness * 1.2, _GlowThickness, distanceFactor);
                
                float core = smoothstep(adjustedCoreThickness - 0.1, adjustedCoreThickness, baseTexture);
                float glow = smoothstep(adjustedGlowThickness - 0.2, adjustedGlowThickness, baseTexture);
                
                float viewFactor = pow(1 - NdotV, 0.5);
                core *= lerp(0.5, 1.0, viewFactor);
                glow *= lerp(0.3, 1.0, viewFactor);
                
                half4 coreColor = _CoreColor * _CoreIntensity * core * flicker;
                half4 glowColor = _GlowColor * _GlowIntensity * glow * flicker;
                
                float3 hsv = rgb2hsv(coreColor.rgb);
                hsv.y = saturate(hsv.y * 1.2);
                hsv.z = saturate(hsv.z * 1.3);
                coreColor.rgb = hsv2rgb(hsv);
                
                half4 finalColor = (coreColor + glowColor) * i.color;
                finalColor *= visibilityFactor;
                
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                
                return finalColor;
            }
            ENDCG
        }
    }
    
    Fallback "Hidden/InternalErrorShader"
}