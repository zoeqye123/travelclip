#!/bin/bash
set -euo pipefail

# ============================================================
# 旅行素材图片生成脚本 - 调用火山引擎 Ark API
# 用法:
#   ./generate_assets.sh "星际穿越..."                     # 单张生成
#   ./generate_assets.sh -f prompts.txt                     # 从文件批量生成
#   echo "prompt" | ./generate_assets.sh --pipe             # 从管道读取
#   ./generate_assets.sh --list                             # 列出广州预设 prompt
#   ./generate_assets.sh --batch guangzhou                  # 批量生成某城市预设
# ============================================================

# --- 默认配置 ---
MODEL="${ARK_MODEL:-ep-20260523135506-j7nc8}"
SIZE="${ARK_SIZE:-2K}"
ENDPOINT="https://ark.cn-beijing.volces.com/api/v3/images/generations"
OUTPUT_DIR="${ARK_OUTPUT:-./generated_assets}"
PROMPT_FILE=""
BATCH_KEY=""
PIPE_MODE=false
LIST_MODE=false
EXTRA_PROMPT_PREFIX="${ARK_PREFIX:-}"
EXTRA_PROMPT_SUFFIX="${ARK_SUFFIX:-}"
STICKER_MODE=false
STICKER_PREFIX="高清水彩贴纸插画，纯白背景，独立展示，无边框无文字，"
TAPE_MODE=false
TAPE_PREFIX="手帐和纸胶带纹理，水彩风格，水平长条构图宽高比10比1，纯白背景，无缝平铺，"
BGREMOVAL_SCRIPT="$(cd "$(dirname "$0")" && pwd)/remove_background.py"
RESIZE=""
STICKER_DEFAULT_RESIZE=300
TAPE_DEFAULT_RESIZE=800
MATERIAL_COUNTRY="${MATERIAL_COUNTRY:-global}"
MATERIAL_CITY="${MATERIAL_CITY:-global}"
MATERIAL_CATEGORY="${MATERIAL_CATEGORY:-general}"
MATERIAL_LAT="${MATERIAL_LAT:-}"
MATERIAL_LNG="${MATERIAL_LNG:-}"
MATERIAL_TAGS="${MATERIAL_TAGS:-sticker}"

# --- 预设 prompt 数据 (key,value 用 | 分隔) ---
declare -a PRESET_KEYS=()
declare -a PRESET_VALUES=()

add_preset() {
  PRESET_KEYS+=("$1")
  PRESET_VALUES+=("$2")
}

add_preset "gzzc" "广州塔/小蛮腰矗立珠江边，夜色中霓虹变幻，城市光影倒映江面，旅行插画风，扁平色块，暖黄与深蓝对比，细节丰富，干净构图，海报感，无文字"
add_preset "zjs" "珠江新城天际线，广州大剧院与花城广场，现代建筑群剪影，旅行明信片风格，柔和渐变天色，建筑玻璃反射夕阳，插画平涂风，浪漫质感"
add_preset "sxj" "上下九骑楼老街，岭南建筑连廊，熙熙攘攘的市井烟火，老字号招牌，旅行手账风，怀旧暖棕色调，线条速写感，生活气息浓厚"
add_preset "lyw" "荔湾湖公园岭南园林，镬耳墙与满洲窗，小桥流水，满洲窗彩色光影斑驳，静谧午后，中国风旅行插画，翠绿与朱红点缀，细腻笔触"
add_preset "bjl" "白云山全景俯瞰广州城，云台花园，山林层层叠叠，清晨薄雾，自然风光插画，青绿色调，留白构图，旅行杂志封面感"
add_preset "cshd" "珠江夜游花船，两岸灯光璀璨，岭南水乡与现代都市交融，水面波光粼粼，夜景旅行插画，深蓝与金色点缀，浪漫旅途氛围"
add_preset "cdf" "陈家祠岭南建筑细节，灰塑、砖雕、陶塑精美绝伦，庭院深深，中国传统文化插画，典雅暖色调，工笔细描感，艺术海报风"
add_preset "xms" "圣心大教堂双塔矗立，哥特式建筑在广州老街中格外醒目，午后阳光透过彩色玻璃，旅行速写风，浅米色与暗红对比，静谧神圣感"
add_preset "ydx" "越秀公园五羊雕塑，羊城标志，木棉花开，城市记忆，传统与现代融合，手绘旅行插画，明快色彩，亲切怀旧感"
add_preset "zgnl" "长隆度假区欢乐世界，游乐园摩天轮与过山车，热带植物环绕，快乐旅行插画，明亮鲜活的卡通质感，天蓝与翠绿，活力四射"
add_preset "gzms" "广州早茶点心蒸笼，虾饺烧卖凤爪，一盅两件，老茶楼氛围，美食旅行插画，暖色蒸汽缭绕，诱人质感，食物手账风"
add_preset "hec" "海心沙亚运公园，广州塔与花城广场中轴线，城市客厅，现代都市旅行插画，明亮蓝天白云，极简几何构图，展示城市活力"
add_preset "szdt" "深圳人才公园视角的华润大厦春笋与深圳湾天际线，科技感现代建筑群，夜景旅行插画，蓝紫色霓虹，赛博青春质感"
add_preset "szqj" "深圳世界之窗微缩景观，埃菲尔铁塔与凯旋门在中国城市背景中，趣味旅行手账风，明亮色彩，轻松活泼"
add_preset "sznz" "深圳湾公园海岸线与红树林，候鸟飞翔，夕阳剪影，城市与自然交融，旅行插画风，暖橘与深蓝渐变，诗意构图"
add_preset "szlg" "深圳大鹏古城，明清海防所城，石板小巷与城墙，岭南古村落，旅行速写风，岁月斑驳的肌理，怀旧棕调"

# --- 水彩贴纸系列 preset (sticker-friendly single-subject) ---
add_preset "st-gzt" "广州塔小蛮腰剪影，水彩晕染，单栋建筑，孤立在白色背景上"
add_preset "st-wy" "五羊石雕雕塑，水彩风格，淡雅色彩，独立展示，无背景"
add_preset "st-cj" "陈家祠岭南建筑一角，飞檐翘角，水彩淡彩，孤立展示"
add_preset "st-dxs" "圣心大教堂哥特式尖塔，水彩风格，浅米色与暗红，独立建筑"
add_preset "st-xgj" "上下九骑楼门面，水彩淡彩，复古色调，孤立展示"
add_preset "st-bys" "白云山山峰轮廓，水彩晕染，青绿色调，孤立展示，无背景"
add_preset "st-zy" "珠江游船，水彩淡彩，孤立展示"
add_preset "st-gzm" "广州早茶虾饺烧卖蒸笼，水彩食物插画，孤立展示，无背景"
add_preset "st-shy" "圣心大教堂彩色玻璃窗，水彩透明感，孤立展示"
add_preset "st-mgh" "木棉花盛开，广州市花，水彩风格，红色花卉独立展示"
add_preset "st-lws" "镬耳墙岭南建筑元素，水彩淡彩，孤立展示"
add_preset "st-lt" "广州塔顶端鸟瞰视角，水彩云朵环绕，孤立展示"
add_preset "st-bys2" "白云山峰顶剪影，水彩青绿渲染，孤立展示，无背景"
add_preset "st-zsjt" "中山纪念堂蓝色琉璃瓦八角屋顶，水彩建筑插画，孤立展示"
add_preset "st-smd" "沙面岛欧式建筑，复古西式洋楼，水彩淡彩，孤立展示"
add_preset "st-hpjc" "黄埔军校旧址大门，历史建筑，水彩淡彩，孤立展示"
add_preset "st-nyw" "南越王博物馆玉佩展品，西汉文物，水彩古风插画，孤立展示"
add_preset "st-szcg" "深圳春笋大厦剪影，水彩风格，现代建筑孤立展示"
add_preset "st-dpg" "大鹏古城城门，水彩淡彩，孤立展示"
add_preset "st-szhx" "深圳湾红树林水鸟，水彩插画，孤立展示"
add_preset "st-szrc" "深圳人才公园绿道，城市与自然交融，水彩插画，孤立展示"
add_preset "st-szcj" "深圳世界之窗微缩地标，水彩风格，趣味旅行插画，孤立展示"
add_preset "st-szlg" "深圳海上世界明华轮，水彩淡彩，孤立展示"
add_preset "st-szmz" "簕杜鹃深圳市花，水彩花卉插画，红色独立展示，无背景"
add_preset "st-szhz" "深圳华强北赛格广场，科技感建筑剪影，水彩风格，孤立展示"
add_preset "st-szmh" "深圳湾大桥海景，水彩淡彩，现代城市与海，孤立展示"

# --- 手帐胶带系列 preset (tape-friendly wide strip) ---
add_preset "tp-trvl" "旅行主题手帐胶带，飞机热气球指南针地图，水彩淡彩，水平长条构图，连续花纹"
add_preset "tp-ocn" "海洋主题手帐胶带，波浪贝壳海星船锚，水彩蓝白，水平长条构图，连续花纹"
add_preset "tp-flw" "花卉植物手帐胶带，水彩花草藤蔓叶子，淡彩柔和，水平长条构图，连续花纹"
add_preset "tp-sts" "星空主题和纸胶带，月亮星星星座云朵，水彩深蓝，水平长条构图，连续花纹"
add_preset "tp-fds" "夏日主题手帐胶带，冰淇淋水果饮料太阳伞，水彩明亮色彩，水平长条构图，连续花纹"
add_preset "tp-wtr" "冬日主题和纸胶带，雪花松树手套围巾，水彩淡蓝白色，水平长条构图，连续花纹"
add_preset "tp-cty" "城市剪影手帐胶带，建筑天际线剪影，水彩灰色系，水平长条构图，连续花纹"
add_preset "tp-rtr" "复古手帐胶带，邮票邮戳信封羽毛笔，水彩棕色调，水平长条构图，连续花纹"
add_preset "tp-ntr" "自然森林手帐胶带，松树蘑菇动物小鹿兔子，水彩绿棕，水平长条构图，连续花纹"
add_preset "tp-gyg" "地理学主题手帐胶带，等高线山脉等高线地形图，水彩，水平长条构图，连续花纹"
add_preset "tp-mnt" "登山主题手帐胶带，山峰徒步鞋背包帐篷，水彩自然色，水平长条构图，连续花纹"
add_preset "tp-jrn" "手帐日记主题胶带，日历线条纸张纹理，水彩暖色，水平长条构图，连续花纹"

# --- 通用旅行贴纸：水彩风格 (wc- 前缀, 10张) ---
add_preset "wc-cam" "复古相机，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-pln" "螺旋桨飞机，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-cmp" "指南针罗盘，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-bag" "复古旅行箱皮箱，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-ppt" "护照和登机牌，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-map" "折叠地图图钉，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-glb" "地球仪，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-bck" "登山背包，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-bnc" "双筒望远镜，水彩淡彩插画，孤立展示，无背景"
add_preset "wc-tkt" "火车票机票登机牌，水彩淡彩插画，孤立展示，无背景"

# --- 通用旅行贴纸：复古怀旧风格 (vt- 前缀, 10张) ---
add_preset "vt-cam" "复古胶片相机，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-pln" "老式双翼飞机，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-cmp" "古董航海罗盘，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-bag" "老式皮箱行李箱，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-ppt" "旧邮票护照邮戳，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-map" "藏宝图卷轴地图，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-glb" "古董地球仪，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-bck" "老式帆布背包，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-bnc" "黄铜望远镜，怀旧棕色调，版画风格，孤立展示，无背景"
add_preset "vt-tkt" "复古火车票明信片，怀旧棕色调，版画风格，孤立展示，无背景"

# --- 通用旅行贴纸：极简线条风格 (ln- 前缀, 10张) ---
add_preset "ln-cam" "相机极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-pln" "纸飞机极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-cmp" "罗盘极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-bag" "行李箱极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-ppt" "护照极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-map" "地图定位pin极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-glb" "地球仪极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-bck" "背包极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-bnc" "望远镜极简线条插画，黑白单色细线，孤立展示，无背景"
add_preset "ln-tkt" "登机牌极简线条插画，黑白单色细线，孤立展示，无背景"

# 按 key 查找 prompt
get_preset() {
  local key="$1"
  local i
  for ((i=0; i<${#PRESET_KEYS[@]}; i++)); do
    if [[ "${PRESET_KEYS[$i]}" == "$key" ]]; then
      echo "${PRESET_VALUES[$i]}"
      return 0
    fi
  done
  return 1
}

# --- 帮助信息 ---
usage() {
  cat <<EOF
旅行素材图片生成脚本 — 火山引擎 Ark Image API

用法:
  $0 "提示词"                         单张生成
  $0 -f prompts.txt                  从文件批量生成（每行一个提示词）
  $0 --pipe                          从标准输入读取（每行一个提示词）
  $0 --list                          列出所有预设提示词
  $0 --batch guangzhou               批量生成所有预设
  $0 --batch gzzc,lyw,zjs            生成指定几个预设

选项:
  -o DIR       输出目录 (默认: ./generated_assets)
  -m MODEL     模型名称 (默认: $MODEL)
  -s SIZE      尺寸: 2K/1K/4K (默认: $SIZE)
  -p PREFIX    附加到 prompt 前面的前缀
  -x SUFFIX    附加到 prompt 后面的后缀
  --sticker    贴纸模式：自动加水彩前缀 + 去除背景生成透明PNG
  --tape       胶带模式：自动加胶带前缀 + 去除背景 + 横向缩放(800px)
  --resize N   缩放到最大边长 N px（贴纸默认300，胶带默认800）
  --country C  material 文件名 country 字段 (默认: global)
  --city C     material 文件名 city 字段 (默认: global)
  --cat C      material 文件名 cat 字段 (默认: general)
  --lat N      material 文件名 lat 字段
  --lng N      material 文件名 lng 字段
  --tags T     material 文件名 tags 字段，多个 tag 用 - 连接
  --dry-run    不实际调用 API，仅打印将要发送的请求

环境变量:
  ARK_API_KEY  火山引擎 API Key (必需)
  ARK_MODEL    默认模型
  ARK_SIZE     默认尺寸
  ARK_OUTPUT   默认输出目录
  ARK_PREFIX   全局 prompt 前缀
  ARK_SUFFIX   全局 prompt 后缀
  MATERIAL_COUNTRY / MATERIAL_CITY / MATERIAL_CATEGORY / MATERIAL_LAT / MATERIAL_LNG / MATERIAL_TAGS
EOF
  exit 0
}

# --- 解析参数 ---
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    -f) PROMPT_FILE="$2"; shift 2 ;;
    --pipe) PIPE_MODE=true; shift ;;
    --list) LIST_MODE=true; shift ;;
    --batch) BATCH_KEY="$2"; shift 2 ;;
    --sticker) STICKER_MODE=true; shift ;;
    --tape) TAPE_MODE=true; shift ;;
    --resize) RESIZE="$2"; shift 2 ;;
    --country) MATERIAL_COUNTRY="$2"; shift 2 ;;
    --city) MATERIAL_CITY="$2"; shift 2 ;;
    --cat|--category) MATERIAL_CATEGORY="$2"; shift 2 ;;
    --lat) MATERIAL_LAT="$2"; shift 2 ;;
    --lng|--lon) MATERIAL_LNG="$2"; shift 2 ;;
    --tags) MATERIAL_TAGS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -o) OUTPUT_DIR="$2"; shift 2 ;;
    -m) MODEL="$2"; shift 2 ;;
    -s) SIZE="$2"; shift 2 ;;
    -p) EXTRA_PROMPT_PREFIX="$2"; shift 2 ;;
    -x) EXTRA_PROMPT_SUFFIX="$2"; shift 2 ;;
    --) shift; break ;;
    -*)
      echo "未知选项: $1"
      usage
      ;;
    *)
      break
      ;;
  esac
done

# --- 列出预设 ---
if $LIST_MODE; then
  echo "=== 所有预设场景 ==="
  for ((i=0; i<${#PRESET_KEYS[@]}; i++)); do
    printf "  %-6s  %-40s...\n" "${PRESET_KEYS[$i]}" "$(echo "${PRESET_VALUES[$i]}" | cut -c1-40)"
  done
  exit 0
fi

# --- 加载 Prompts 到列表 ---
declare -a PROMPTS=()

if [[ -n "$BATCH_KEY" ]]; then
  IFS=',' read -ra KEYS <<< "$BATCH_KEY"
  for key in "${KEYS[@]}"; do
    prompt=$(get_preset "$key")
    if [[ -z "$prompt" ]]; then
      echo "未知预设 key: $key" >&2
      exit 1
    fi
    PROMPTS+=("$prompt")
  done
elif $PIPE_MODE; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && PROMPTS+=("$line")
  done < /dev/stdin
elif [[ -n "$PROMPT_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    PROMPTS+=("$line")
  done < "$PROMPT_FILE"
elif [[ $# -gt 0 ]]; then
  PROMPTS+=("$*")
fi

if [[ ${#PROMPTS[@]} -eq 0 ]]; then
  echo "未提供任何提示词。使用 -h 查看帮助。" >&2
  exit 1
fi

# --- 检查依赖 ---
if [[ -z "${ARK_API_KEY:-}" ]]; then
  echo "请设置 ARK_API_KEY 环境变量" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "缺少依赖: curl" >&2; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "缺少依赖: python3" >&2; exit 1
fi

# --- 准备输出目录 ---
mkdir -p "$OUTPUT_DIR"

# --- 安全截断文件名 ---
sanitize_filename() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import re
import sys

value = sys.argv[1].strip().lower()
value = re.sub(r"[^0-9a-zA-Z_.\-\u4e00-\u9fff]+", "-", value)
value = re.sub(r"-+", "-", value).strip("-")
print((value or "material")[:40])
PY
}

material_filename() {
  local prompt="$1"
  local name
  name=$(sanitize_filename "$prompt")

  local country city category tags
  country=$(sanitize_filename "$MATERIAL_COUNTRY")
  city=$(sanitize_filename "$MATERIAL_CITY")
  category=$(sanitize_filename "$MATERIAL_CATEGORY")
  tags=$(sanitize_filename "$MATERIAL_TAGS")

  local stem="country-${country}__city-${city}__cat-${category}"
  if [[ -n "$MATERIAL_LAT" && -n "$MATERIAL_LNG" ]]; then
    stem="${stem}__lat-${MATERIAL_LAT}__lng-${MATERIAL_LNG}"
  fi
  stem="${stem}__name-${name}__tags-${tags}"
  echo "$stem"
}

# --- 生成单张图片 ---
generate_one() {
  local prompt="$1"
  local idx="$2"
  local total="$3"

  local full_prompt="${EXTRA_PROMPT_PREFIX}${prompt}${EXTRA_PROMPT_SUFFIX}"
  if $TAPE_MODE; then
    full_prompt="${TAPE_PREFIX}${full_prompt}"
  elif $STICKER_MODE; then
    full_prompt="${STICKER_PREFIX}${full_prompt}"
  fi

  echo ""
  echo "===================================================="
  echo "[$idx/$total] 生成中..."
  echo "Prompt: ${full_prompt:0:120}..."
  echo "===================================================="

  if $DRY_RUN; then
    echo "  (dry-run) POST $ENDPOINT"
    echo "  (dry-run) model=$MODEL size=$SIZE"
    if $STICKER_MODE; then
      echo "  (dry-run) output=${OUTPUT_DIR}/$(material_filename "$prompt").png"
    fi
    return 0
  fi

  local resp_file
  resp_file=$(mktemp)

  local http_code
  http_code=$(curl -s -w "%{http_code}" -o "$resp_file" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ARK_API_KEY" \
    -d "$(python3 -c "
import json, sys
data = {
    'model': '$MODEL',
    'prompt': sys.argv[1],
    'sequential_image_generation': 'disabled',
    'response_format': 'url',
    'size': '$SIZE',
    'stream': False,
    'watermark': True
}
print(json.dumps(data, ensure_ascii=False))
" "$full_prompt")")

  if [[ "$http_code" != "200" ]]; then
    echo "✗ 请求失败 [HTTP $http_code]:"
    cat "$resp_file" 2>/dev/null || true
    rm -f "$resp_file"
    return 1
  fi

  local image_url
  image_url=$(python3 -c "import json; d=json.load(open('$resp_file')); print(d['data'][0]['url'])" 2>/dev/null) || true

  if [[ -z "$image_url" ]]; then
    echo "✗ 响应中未找到图片 URL:"
    cat "$resp_file" 2>/dev/null || true
    rm -f "$resp_file"
    return 1
  fi

  rm -f "$resp_file"

  local ts
  ts=$(date +%s)
  local safe_name
  if $STICKER_MODE; then
    safe_name=$(material_filename "$prompt")
  else
    safe_name="$(ts)_$(sanitize_filename "$prompt")"
  fi
  local ext="png"
  local out_file="${OUTPUT_DIR}/${safe_name}.${ext}"

  echo "  下载: ${image_url:0:80}..."
  curl -s -o "$out_file" "$image_url"

  if [[ -f "$out_file" ]]; then
    local filesize
    filesize=$(stat -f%z "$out_file" 2>/dev/null || stat -c%s "$out_file" 2>/dev/null || echo 0)
    local size_display
    if [[ "$filesize" -gt 1048576 ]]; then
      size_display="$(echo "scale=1; $filesize/1048576" | bc 2>/dev/null || echo '?') MB"
    else
      size_display="$(echo "scale=0; $filesize/1024" | bc 2>/dev/null || echo '?') KB"
    fi
    echo "✓ 保存到: $out_file ($size_display)"

    # 贴纸/胶带模式：背景透明化 + 缩放
    if $STICKER_MODE || $TAPE_MODE; then
      local orig_dir="${OUTPUT_DIR}/original"
      mkdir -p "$orig_dir"
      local orig_file="${orig_dir}/$(basename "$out_file")"
      mv "$out_file" "$orig_file"

      local transparent_file="${out_file}"
      local resize_target
      local resize_mode  # "longest" for sticker, "width" for tape
      if $TAPE_MODE; then
        resize_target="${RESIZE:-$TAPE_DEFAULT_RESIZE}"
        resize_mode="width"
        echo "  胶带处理..."
      else
        resize_target="${RESIZE:-$STICKER_DEFAULT_RESIZE}"
        resize_mode="longest"
        echo "  透明化处理..."
      fi
      if python3 -c "
from PIL import Image
img = Image.open('$orig_file').convert('RGBA')
w, h = img.size

# 背景去除 (白色转为透明)
bg_color = (255, 255, 255)
tolerance = 80
pixels = img.load()
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a < 50:
            pixels[x, y] = (0, 0, 0, 0)
            continue
        dist = ((r-bg_color[0])**2 + (g-bg_color[1])**2 + (b-bg_color[2])**2) ** 0.5
        if dist <= tolerance:
            pixels[x, y] = (r, g, b, 0)
        elif dist < tolerance + 20:
            fade = int(255 * (dist - tolerance) / 20)
            pixels[x, y] = (r, g, b, min(a, fade))

# 裁剪到非透明区域
bbox = img.getbbox()
if bbox:
    img = img.crop(bbox)

# 缩放
target = $resize_target
mode = '$resize_mode'
if mode == 'width':
    if img.size[0] > target:
        ratio = target / img.size[0]
        new_size = (target, int(img.size[1] * ratio))
        img = img.resize(new_size, Image.LANCZOS)
else:
    longest = max(img.size[0], img.size[1])
    if longest > target:
        ratio = target / longest
        new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
        img = img.resize(new_size, Image.LANCZOS)

img.save('$transparent_file', 'PNG', optimize=True)
" 2>&1; then
        local tsize
        tsize=$(stat -f%z "$transparent_file" 2>/dev/null || stat -c%s "$transparent_file" 2>/dev/null || echo 0)
        local tsize_display
        if [[ "$tsize" -gt 1048576 ]]; then
          tsize_display="$(echo "scale=1; $tsize/1048576" | bc 2>/dev/null || echo '?') MB"
        else
          tsize_display="$(echo "scale=0; $tsize/1024" | bc 2>/dev/null || echo '?') KB"
        fi
        if $TAPE_MODE; then
          echo "✓ 胶带: $transparent_file ($tsize_display)"
        else
          echo "✓ 透明贴纸: $transparent_file ($tsize_display)"
        fi
      else
        echo "⚠ 处理失败，保留原始图片"
        mv "$orig_file" "$out_file"
      fi
    fi
  else
    echo "✗ 下载失败"
    return 1
  fi
}

# --- 执行生成 ---
TOTAL=${#PROMPTS[@]}
echo "=== 旅行素材生成器 ==="
echo "模型: $MODEL"
echo "尺寸: $SIZE"
echo "数量: $TOTAL"
echo "输出: $OUTPUT_DIR"
echo ""

FAILED=0
for i in "${!PROMPTS[@]}"; do
  if ! generate_one "${PROMPTS[$i]}" "$((i+1))" "$TOTAL"; then
    FAILED=$((FAILED+1))
  fi
  [[ $((i+1)) -lt $TOTAL ]] && sleep 0.5
done

echo ""
echo "=== 完成 ==="
echo "成功: $((TOTAL - FAILED)) / 失败: $FAILED"
echo "文件目录: $OUTPUT_DIR"
if $TAPE_MODE; then
  echo "胶带素材: $OUTPUT_DIR/*.png"
  echo "原始文件: $OUTPUT_DIR/original/"
elif $STICKER_MODE; then
  echo "透明贴纸: $OUTPUT_DIR/*.png"
  echo "原始文件: $OUTPUT_DIR/original/"
fi
