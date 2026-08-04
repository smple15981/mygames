# Hearthwild 2D

Hearthwild 2D 是一个使用 **Godot 4.x + GDScript** 开发的原创俯视角像素生活冒险游戏。项目采用纯 2D 架构，并使用许可证明确的开源像素素材建立统一美术风格。

## 当前画面与玩法基础

- 640×360 像素基础视口，放大到 1280×720 时保持清晰像素边缘
- 16×16 开源地表图集按 2 倍显示，对应 32×32 逻辑地图格
- `CharacterBody2D` 玩家和八方向等速移动
- Ninja Adventure 4×7 角色图集与四方向移动动画
- `Camera2D` 平滑跟随、Y 排序和纯 2D 碰撞
- 统一风格的房屋、树群、岩石、围栏和小动物
- 动态像素水面、环境粒子、局部暖光与拾取物冷光
- 紧凑的生命值、区域名和操作提示 HUD
- 原创 SVG 仅在运行时图片损坏时作为最后降级资源

当前阶段重点是移动和画面表现。战斗、背包、制作、种植逻辑、敌人 AI、存档和联机尚未实现。

## 获取项目

运行时使用的开源图片已经直接打包进主仓库，**无需初始化 submodule**。GitHub ZIP、普通克隆和普通拉取都应显示真实像素美术：

```bash
git clone https://github.com/smple15981/mygames.git
cd mygames
```

然后：

1. 安装 Godot 4.3 或更新的 Godot 4.x。
2. 在 Godot 项目管理器中导入仓库根目录的 `project.godot`。
3. 运行主场景。

从旧版本更新后，建议关闭 Godot，删除项目根目录下的 `.godot` 缓存目录，再重新导入项目，确保旧占位纹理不会留在导入缓存中。

## 操作

| 操作 | 键位 |
|---|---|
| 移动 | `WASD` 或方向键 |
| 交互预留 | `E` |
| 攻击预留 | 鼠标左键或 `J` |
| 闪避预留 | 空格或 `K` |
| 暂停预留 | `Esc` |

## 开源美术

主美术来源是 **Ninja Adventure Asset Pack**。项目把实际需要的地表、村庄道具、玩家、小动物和阴影图片以紧凑运行时图集放在：

```text
assets/third_party/ninja-adventure/
```

同时保留：

- Kenney CC0 粒子图片，用于拾取物和局部灯光
- Tabler Icons MIT 图标，用于 HUD
- `assets/original/` 下的原创紧急降级素材

准确来源、固定提交、图集修改方式、实际消费路径和许可证记录见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 验证

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
```

GitHub Actions 使用普通 checkout，不拉取 submodule，并继续执行官方 Godot 无头导入和主场景启动检查。这用于证明普通下载本身就包含所需美术。

## 目录

```text
assets/
├── original/       原创紧急降级素材
└── third_party/    直接进入仓库的开源运行时素材
scenes/
├── bootstrap/      程序入口
├── player/         玩家、镜头与图集显示
└── world/          世界、灯光、水体和 HUD
scripts/
├── assets/         开源素材加载与降级逻辑
├── player/         移动和角色图集动画
└── world/          地图、道具、水体和环境效果
tools/              仓库验证工具
tests/              Python 自动测试
```

## 设计文档

- 纯 2D 架构：`docs/superpowers/specs/2026-08-04-hearthwild-pure-2d-design.md`
- 开源美术升级：`docs/superpowers/specs/2026-08-04-open-art-visual-polish-design.md`

历史 HD-2D 文档仅作为决策记录，不代表当前实现方向。
