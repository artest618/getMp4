#!/bin/sh

# 定义 JSON 文件路径
JSON_FILE="./curl.json"

# 检查 JSON 文件是否存在
if [ ! -f "$JSON_FILE" ]; then
  echo "文件 $JSON_FILE 不存在"
  exit 1
fi

# 读取 JSON 文件中的每个对象
jq -c '.[]' "$JSON_FILE" | while IFS= read -r item; do
  # 解析 JSON 对象
  title=$(echo "$item" | jq -r '.title')
  file=$(echo "$item" | jq -r '.file')
  url=$(echo "$item" | jq -r '.url')
  out=$(echo "$item" | jq -r '.out')

  # 检查输出目录是否存在，如果不存在则创建
  mkdir -p "$out"

  # 构建输出文件路径
  output_mp4="${out}/${file}"

  # 执行 ffmpeg 命令
  ffmpeg -i "$url" -c copy "$output_mp4"
  if [ $? -ne 0 ]; then
    echo "转换 $url 到 $output_mp4 失败"
    continue
  fi

  echo "成功转换 $url 到 $output_mp4"
done

echo "所有任务完成"