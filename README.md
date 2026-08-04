# Hearthwild 2D

Hearthwild 2D 是一个使用 **Godot 4.x + GDScript** 开发的原创俯视角像素生活冒险游戏。项目已经放弃 3D/HD-2D 技术路线，改为更容易制作、维护和扩展的纯 2D 架构。

## 当前可用内容

- 640×360 像素基础视口，按整数倍放大
- `TileMapLayer` 运行时生成的 32×32 地面地图
- `CharacterBody2D` 玩家和八方向等速移动
- `AnimatedSprite2D` 朝向状态与 `Camera2D` 平滑跟随
- Y 排序的房屋、树木、岩石、作物、史莱姆和掉落物原型
- 纯 2D 碰撞体
- Kenney CC0 粒子图片与 Tabler MIT 的心形、剑形 HUD 图标
- Python 仓库结构、2D 场景契约和许可证自动检查

当前阶段仍是第一版可玩技术骨架。战斗、背包、制作、种植逻辑、敌人 AI、存档和联机尚未实现。

## 运行方式

1. 安装 Godot 4.3 或更高的 Godot 4.x 版本。
2. 在 Godot 项目管理器中导入仓库根目录的 `project.godot`。
3. 运行主场景。

## 操作

| 操作 | 键位 |
|---|---|
| 移动 | `WASD` 或方向键 |
| 交互预留 | `E` |
| 攻击预留 | 鼠标左键或 `J` |
| 闪避预留 | 空格或 `K` |
| 暂停预留 | `Esc` |

## 验证

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
```

验证会检查纯 2D 组件、640×360 视口、TileMapLayer、Camera2D、场景引用、禁止遗留的 3D 节点，以及第三方素材登记。

## 目录

```text
assets/
├── original/       原创像素占位美术
└── third_party/    经过许可证核验的开源素材
scenes/
├── bootstrap/      程序入口
├── player/         纯 2D 玩家场景
└── world/          TileMapLayer 世界场景
scripts/
├── player/         移动和朝向
└── world/          运行时瓦片地图构建
tools/              仓库验证工具
tests/              Python 自动测试
```

## 设计规格

纯 2D 重构规格位于：

`docs/superpowers/specs/2026-08-04-hearthwild-pure-2d-design.md`

它取代此前的 HD-2D 方向。历史设计文档仅作决策记录。

## 素材和许可证

所有第三方素材必须拥有明确的开放许可证，并按仓库内准确路径登记在 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
