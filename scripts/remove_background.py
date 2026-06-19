#!/usr/bin/env python3
"""
水彩贴纸背景透明化处理脚本
通过检测边缘颜色自动去除背景，适合水彩/插画风格的贴纸素材。
"""
import sys
import os
from PIL import Image
import colorsys

def remove_background(
    input_path: str,
    output_path: str = None,
    edge_threshold: float = 0.92,  # 边缘颜色相似度阈值 (0-1)
    tolerance: int = 60,            # 颜色距离容差 (0-255)
    smooth_edge: int = 3,           # 边缘羽化像素数
    mode: str = "auto"              # auto / white / auto_edge
):
    """
    智能背景去除：
    - auto: 采样四边颜色，取最常见色作为背景色
    - white: 白色背景去除
    - auto_edge: 只用边缘像素判断
    """
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size

    def color_distance(c1, c2):
        """RGB 空间欧氏距离"""
        return ((c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2) ** 0.5

    def sample_edge_colors():
        """采样边缘像素颜色"""
        pixels = []
        # 上下边
        for x in range(0, w, max(1, w//100)):
            r, g, b, a = img.getpixel((x, 0))
            if a > 200:
                pixels.append((r,g,b))
            _, _, _, a2 = img.getpixel((x, h-1))
            if a2 > 200:
                r2, g2, b2, _ = img.getpixel((x, h-1))
                pixels.append((r2,g2,b2))
        # 左右边
        for y in range(0, h, max(1, h//100)):
            r, g, b, a = img.getpixel((0, y))
            if a > 200:
                pixels.append((r,g,b))
            r2, g2, b2, a2 = img.getpixel((w-1, y))
            if a2 > 200:
                pixels.append((r2,g2,b2))
        return pixels

    def find_dominant_color(colors):
        """找到最常出现的颜色（聚类简化版）"""
        if not colors:
            return (255, 255, 255)  # 默认白色

        # 将颜色量化到分组
        step = 32
        bins = {}
        for c in colors:
            key = (c[0]//step*step, c[1]//step*step, c[2]//step*step)
            bins[key] = bins.get(key, 0) + 1

        # 取出现最多的组
        dominant = max(bins, key=bins.get)
        return dominant

    if mode == "white":
        bg_color = (255, 255, 255)
        tolerance = tolerance
    else:
        edge_colors = sample_edge_colors()
        bg_color = find_dominant_color(edge_colors)
        # 如果是浅色/白色边缘，增加容差
        brightness = (bg_color[0] + bg_color[1] + bg_color[2]) / 3
        if brightness > 220:
            tolerance += 30
        elif brightness > 180:
            tolerance += 15

    print(f"  检测到背景色: RGB{bg_color}, 容差: {tolerance}")

    # 背景色相似度判断
    def is_background(r, g, b, a):
        if a < 50:  # 已经是透明的
            return True
        if color_distance((r,g,b), bg_color) <= tolerance:
            return True
        return False

    # 创建新图像
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            r, g, b, a = img.getpixel((x, y))
            if is_background(r, g, b, a):
                continue  # 保持透明

            # 边缘羽化：靠近背景色的像素降低不透明度
            if smooth_edge > 0:
                dist = color_distance((r,g,b), bg_color)
                if dist < tolerance + 15:
                    fade = max(0, min(255, int(255 * (dist - tolerance) / 15)))
                    result.putpixel((x, y), (r, g, b, fade))
                else:
                    result.putpixel((x, y), (r, g, b, a))
            else:
                result.putpixel((x, y), (r, g, b, a))

    result.save(output_path, "PNG")
    print(f"  已保存透明背景: {os.path.basename(output_path)}")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="水彩贴纸背景透明化")
    parser.add_argument("input", help="输入图片路径或目录")
    parser.add_argument("-o", "--output", default=None, help="输出路径")
    parser.add_argument("-t", "--tolerance", type=int, default=60, help="颜色容差 (0-255)")
    parser.add_argument("-s", "--smooth", type=int, default=3, help="边缘羽化像素")
    parser.add_argument("-m", "--mode", default="auto",
                        choices=["auto", "white", "auto_edge"],
                        help="背景检测模式")
    args = parser.parse_args()

    if os.path.isdir(args.input):
        out_dir = args.output or os.path.join(args.input, "transparent")
        os.makedirs(out_dir, exist_ok=True)
        files = sorted([
            f for f in os.listdir(args.input)
            if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
        ])
        if not files:
            print(f"目录中没有图片: {args.input}")
            return
        print(f"处理 {len(files)} 张图片 -> {out_dir}")
        for f in files:
            print(f"\n  {f}:")
            in_path = os.path.join(args.input, f)
            out_path = os.path.join(out_dir, os.path.splitext(f)[0] + ".png")
            remove_background(in_path, out_path, tolerance=args.tolerance,
                            smooth_edge=args.smooth, mode=args.mode)
        print(f"\n完成！透明版本在: {out_dir}")
    else:
        out_path = args.output or (os.path.splitext(args.input)[0] + "_transparent.png")
        remove_background(args.input, out_path, tolerance=args.tolerance,
                        smooth_edge=args.smooth, mode=args.mode)


if __name__ == "__main__":
    main()
