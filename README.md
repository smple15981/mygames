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
- 20 格背包，前 5 格直接作为快捷栏
- 数字键与鼠标滚轮切换快捷栏
- 树枝、碎石、工具、武器、种子、食物等首批物品数据
- 石斧、石镐、木剑和火把的随身制作界面
- 原子制作事务：材料不足或普通成品无处放置时不会错误扣除材料
- 左键按照当前快捷栏物品生成统一动作请求，为后续战斗、采集和种植提供稳定接口
- Python 仓库契约测试、Godot 无头玩法测试、资源导入和主场景烟雾测试
- 原创 SVG 仅在运行时图片损坏时作为最后降级资源

当前已完成**玩法基础、背包、快捷栏和随身制作阶段**。攻击伤害、闪避、敌人 AI、树木与矿石采集、实体掉落、种植、昼夜、存档和联机仍未接入实际玩法效果。

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
| 使用当前快捷栏物品 | 鼠标左键或 `J` |
| 切换快捷栏 | 数字键 `1–5` 或鼠标滚轮 |
| 打开或关闭背包与随身制作 | `Tab` |
| 交互预留 | `E` |
| 闪避预留 | 空格或 `K` |
| 暂停预留 | `Esc` |

背包或随身制作界面打开时，单人世界会暂停。当前左键只生成动作请求，尚不会真正伤害敌人、砍树、挖矿或耕地。

## 开源美术

主美术来源是 **Ninja Adventure Asset Pack**。项目把实际需要的地表、村庄道具、玩家、小动物和阴影图片以紧凑运行时图集放在：

```text
assets/third_party/ninja-adventure/
```

同时保留：

- Kenney CC0 粒子图片，用于拾取物和局部灯光
- Tabler Icons MIT 图标，用于 HUD
- `assets/original/` 下的原创紧急降级素材和原创物品图标

准确来源、固定提交、图集修改方式、实际消费路径和许可证记录见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 验证

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
```

GitHub Actions 使用普通 checkout，不拉取 submodule，并执行 Python 测试、仓库验证、官方 Godot 资源导入、无头玩法测试和主场景启动检查。

## 目录

```text
assets/
├── original/       原创降级素材和物品图标
└── third_party/    直接进入仓库的开源运行时素材
data/
├── items/          物品 Resource 配置
└── recipes/        制作配方 Resource 配置
scenes/
├── bootstrap/      程序入口
├── player/         玩家、镜头与组件节点
├── ui/             快捷栏和背包制作界面
└── world/          世界、灯光、水体和 HUD
scripts/
├── actions/        统一动作请求与结果协议
├── assets/         开源素材加载与降级逻辑
├── crafting/       配方与原子制作事务
├── inventory/      20 格背包和快捷栏模型
├── items/          物品定义与目录
├── player/         移动、图集动画和物品使用分发
├── ui/             快捷栏与背包制作界面
└── world/          地图、道具、水体和环境效果
tools/              仓库验证工具
tests/              Python 与 Godot 无头自动测试
```

## 设计与实施文档

- 纯 2D 架构：`docs/superpowers/specs/2026-08-04-hearthwild-pure-2d-design.md`
- 开源美术升级：`docs/superpowers/specs/2026-08-04-open-art-visual-polish-design.md`
- 核心玩法垂直切片设计：`docs/superpowers/specs/2026-08-04-core-gameplay-vertical-slice-design.md`
- 五阶段实施路线：`docs/superpowers/plans/2026-08-04-core-gameplay-vertical-slice-roadmap.md`
- 第一阶段计划：`docs/superpowers/plans/2026-08-04-gameplay-foundation-inventory-crafting.md`

历史 HD-2D 文档仅作为决策记录，不代表当前实现方向。
