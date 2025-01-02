#!/bin/sh

# 定义变量
M3U8_FILE="1.m3u8"
OUTPUT_FILE="output.mp4"
TS_FILES_DIR="ts_files"
FILELIST="filelist.txt"
CURRENT_DIR=$(pwd)
ENCRYPTION_KEY="f698808fdd64d8fd"  # 替换为实际的密钥
IV="0x37626431646661643431333839356236"
MAX_RETRIES=3

# 创建目录
mkdir -p "$TS_FILES_DIR"

# 读取 m3u8 文件并下载每个 .ts 文件
while IFS= read -r line; do
  if [[ $line == http* ]]; then
    # 提取文件名并去除查询参数
    filename=$(basename "$line" | cut -d'?' -f1)
    local_path="$TS_FILES_DIR/$filename"
    retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
      curl -o "$local_path" "$line"
      if [ $? -ne 0 ]; then
        echo "下载 $line 失败，重试中 ($((retries + 1))/$MAX_RETRIES)"
        ((retries++))
        continue
      fi

      # 检查文件是否下载成功
      if [ ! -f "$local_path" ]; then
        echo "文件 $local_path 下载失败"
        exit 1
      fi

      # 检查文件大小
      file_size=$(stat -f "%z" "$local_path")
      if [ "$file_size" -eq 0 ]; then
        echo "文件 $local_path 下载为空，重试中 ($((retries + 1))/$MAX_RETRIES)"
        ((retries++))
        continue
      fi

      # 确保文件具有读取权限
      chmod +r "$local_path"

      # 使用 ffprobe 检查文件是否有效
      ffprobe "$local_path" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "文件 $local_path 无效或损坏，重试中 ($((retries + 1))/$MAX_RETRIES)"
        ((retries++))
        continue
      fi

      # 使用绝对路径记录文件
      echo "file '$CURRENT_DIR/$local_path'" >> "$FILELIST"
      break
    done

    if [ $retries -ge $MAX_RETRIES ]; then
      echo "文件 $local_path 下载多次失败，放弃"
      exit 1
    fi
  fi
done < "$M3U8_FILE"

# 打印文件列表，确保路径正确
cat "$FILELIST"

# 使用 ffmpeg 合并 .ts 文件，并指定密钥和 IV
ffmpeg -f concat -safe 0 -i "$FILELIST" -c copy -encryption_key "$ENCRYPTION_KEY" -encryption_iv "$IV" "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "合并 .ts 文件失败"
  exit 1
fi

# 清理临时文件
rm -rf "$TS_FILES_DIR" "$FILELIST"

echo "视频合并完成，输出文件为: $OUTPUT_FILE"