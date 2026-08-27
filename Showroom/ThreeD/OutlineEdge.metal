#include <metal_stdlib>
using namespace metal;

// Derinlik tabanlı kenar algılama: komşu piksellerin derinlik farkı eşiği aşarsa
// piksel kontur rengine boyanır. İç profil çizgilerini ve köşeleri vurgular.
kernel void edgeOutline(texture2d<float, access::read> source [[texture(0)]],
                        depth2d<float, access::read> depthTex [[texture(1)]],
                        texture2d<float, access::write> target [[texture(2)]],
                        constant float4 &lineColor [[buffer(0)]],
                        constant float &threshold [[buffer(1)]],
                        uint2 gid [[thread_position_in_grid]])
{
    uint width = target.get_width();
    uint height = target.get_height();
    if (gid.x >= width || gid.y >= height) {
        return;
    }

    float4 color = source.read(gid);

    uint2 xPlus = uint2(min(gid.x + 1, width - 1), gid.y);
    uint2 xMinus = uint2(gid.x > 0 ? gid.x - 1 : 0, gid.y);
    uint2 yPlus = uint2(gid.x, min(gid.y + 1, height - 1));
    uint2 yMinus = uint2(gid.x, gid.y > 0 ? gid.y - 1 : 0);

    float centerDepth = depthTex.read(gid);
    // İkinci türev (Laplacian): düz yüzeylerde eğim ne olursa olsun sıfırdır,
    // yalnızca gerçek kırıklarda (profil kenarı, köşe, basamak) değer üretir.
    // Böylece model eğilince yüzeyin tamamı "kenar" sanılmaz.
    float lapX = fabs(depthTex.read(xPlus) + depthTex.read(xMinus) - 2.0 * centerDepth);
    float lapY = fabs(depthTex.read(yPlus) + depthTex.read(yMinus) - 2.0 * centerDepth);
    float relativeEdge = (lapX + lapY) / max(centerDepth, 1e-5);

    if (relativeEdge > threshold) {
        color = float4(lineColor.rgb, 1.0);
    }
    target.write(color, gid);
}
