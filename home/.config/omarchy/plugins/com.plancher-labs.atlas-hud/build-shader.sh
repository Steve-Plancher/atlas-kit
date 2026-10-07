#!/bin/bash
# Bakes wordmark.frag into the .qsb the ShaderEffect loads. Run after editing the shader.
set -e
cd "$(dirname "$(readlink -f "$0")")"
/usr/lib/qt6/bin/qsb --glsl 100es,120,150 --hlsl 50 --msl 12 -o build/wordmark.frag.qsb wordmark.frag
echo "baked build/wordmark.frag.qsb"
