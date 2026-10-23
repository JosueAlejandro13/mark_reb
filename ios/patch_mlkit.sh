#!/bin/sh
# patch_mlkit.sh
# Permite compilar Google MLKit tanto en Dispositivo Real (iOS) como en Simulador (Apple Silicon)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="${PODS_ROOT:-$SCRIPT_DIR/Pods}"

if [ ! -d "$PODS_DIR" ]; then
  exit 0
fi

# Detectar plataforma de destino (por defecto iphoneos si no está definida)
TARGET_PLATFORM="${PLATFORM_NAME:-iphoneos}"

echo "[MLKit Patch] Preparando frameworks para: $TARGET_PLATFORM"

if [ "$TARGET_PLATFORM" = "iphoneos" ]; then
  # Cambiar platform 7 (simulator) -> platform 2 (device)
  ruby -e '
    sim_bytes = [0x32, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00].pack("C*")
    dev_bytes = [0x32, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00].pack("C*")
    pods_dir = ARGV[0]
    Dir.glob(File.join(pods_dir, "**", "ML*.framework", "*")).each do |bin|
      next unless File.file?(bin) && !bin.end_with?(".plist", ".h", ".device_bak", ".sh")
      c = File.binread(bin)
      if c.include?(sim_bytes)
        File.binwrite(bin, c.gsub(sim_bytes, dev_bytes))
        puts "[MLKit Patch] Ajustado a DISPOSITIVO REAL (iOS): #{File.basename(bin)}"
      end
    end
  ' "$PODS_DIR"
else
  # Cambiar platform 2 (device) -> platform 7 (simulator)
  ruby -e '
    dev_bytes = [0x32, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00].pack("C*")
    sim_bytes = [0x32, 0x00, 0x00, 0x00, 0x18, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00].pack("C*")
    pods_dir = ARGV[0]
    Dir.glob(File.join(pods_dir, "**", "ML*.framework", "*")).each do |bin|
      next unless File.file?(bin) && !bin.end_with?(".plist", ".h", ".device_bak", ".sh")
      c = File.binread(bin)
      if c.include?(dev_bytes)
        File.binwrite(bin, c.gsub(dev_bytes, sim_bytes))
        puts "[MLKit Patch] Ajustado a SIMULADOR (iOS-simulator): #{File.basename(bin)}"
      end
    end
  ' "$PODS_DIR"
fi
