# 旅行素材生成指南

## 概述

travelclip 的 material 素材不再依赖 JSON 索引。素材添加、删除、移动都只看实际图片文件，必要信息写在文件名里。这样频繁增删素材时不需要同步维护 manifest。

胶带素材可以继续使用 `TapeGroups` 下已有的胶带清单；本文件只约束 `Resources/MaterialGroups` 的贴纸/图片素材。

## 目录结构

```
travelclip/Resources/MaterialGroups/
├── china/
│   ├── guangzhou/
│   │   ├── country-china__city-guangzhou__cat-landmark__lat-23.1097__lng-113.3190__name-canton-tower__tags-广州塔-landmark-sticker.png
│   │   └── ...
│   └── shenzhen/
│       ├── country-china__city-shenzhen__cat-landmark__lat-22.5431__lng-114.0579__name-spring-bamboo-tower__tags-春笋-building-sticker.png
│       └── ...
└── global/
    └── travel-icons/
        ├── country-global__city-global__cat-icons__name-camera__tags-camera-travel-sticker.png
        └── ...
```

## 文件名格式

固定格式：

```text
country-{country}__city-{city}__cat-{category}__lat-{latitude}__lng-{longitude}__name-{name}__tags-{tag1}-{tag2}-{tag3}.png
```

字段说明：

| 字段 | 必填 | 说明 |
|------|------|------|
| `country` | 建议 | 英文小写国家或 `global` |
| `city` | 建议 | 英文小写城市；通用素材用 `global` |
| `cat` | 建议 | 分类，如 `landmark`、`food`、`flower`、`icons`、`tape` |
| `lat` | 位置素材必填 | 纬度，小数；通用素材可省略 |
| `lng` | 位置素材必填 | 经度，小数；通用素材可省略 |
| `name` | 必填 | 英文短名，用 `-` 连接 |
| `tags` | 建议 | 中英文搜索词，用 `-` 连接 |

示例：

```text
country-china__city-shenzhen__cat-flower__lat-22.5431__lng-114.0579__name-bougainvillea__tags-簕杜鹃-flower-shenzhen-sticker.png
country-china__city-guangzhou__cat-food__lat-23.1291__lng-113.2644__name-dim-sum__tags-早茶-dimsum-food-sticker.png
country-global__city-global__cat-icons__name-passport__tags-passport-travel-sticker.png
```

兼容规则：

- 删除图片不需要改任何 JSON。
- 文件名缺字段不会报错，app 会从目录和普通文件名推导标题、国家、城市和 tags。
- 有 `lat/lng` 的素材会带位置信息，可用于附近推荐。
- 文件名请尽量只用字母、数字、`-`、`_` 和中文 tags；不要使用空格。

## 生成素材

环境准备：

```bash
export ARK_API_KEY="你的火山引擎API Key"
source ~/.zshrc
```

贴纸示例：

```bash
./scripts/generate_assets.sh --sticker \
  --country china \
  --city shenzhen \
  --cat landmark \
  --lat 22.5431 \
  --lng 114.0579 \
  --tags 深圳-地标-sticker \
  --batch st-szcg
```

通用贴纸示例：

```bash
./scripts/generate_assets.sh --sticker \
  --country global \
  --city global \
  --cat icons \
  --tags travel-icon-sticker \
  --batch wc-cam,wc-pln,wc-cmp
```

胶带示例：

```bash
./scripts/generate_assets.sh --tape --batch tp-trvl,tp-ocn,tp-flw
```

## 添加新素材 Checklist

1. 运行 `scripts/generate_assets.sh` 生成图片，或手动准备 PNG/JPG/WebP。
2. 按固定文件名格式重命名，位置素材写入 `lat/lng`。
3. 放入 `travelclip/Resources/MaterialGroups/{country}/{city}/` 或合适分类目录。
4. 删除旧素材时直接删图片即可，不需要维护 JSON。
5. 构建 app，打开 Store/Materials 检查素材是否出现。
