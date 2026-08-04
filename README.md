# Hearthwild HD-2D

Hearthwild HD-2D 是一个使用 **Godot 4.x + GDScript** 开发的原创俯视角生活冒险游戏原型。当前版本验证“3D 环境 + 2D Sprite3D 角色与特效”的混合 HD-2D 技术路线。

## 当前可用内容

- 固定正交俯视斜角摄像机
- 960×540 基础视口与近邻采样
- 由 3D 基础几何体组成的农场、道路、河流和森林场景
- 使用 `CharacterBody3D` 的 2D billboard 玩家
- 八方向输入、等速斜向移动、碰撞与重力
- 一个已登记许可证的 Kenney CC0 粒子素材，用于场景中的发光标记
- Python 项目结构、场景引用与第三方许可证检查

当前阶段是第一版可玩技术骨架，还没有加入战斗、背包、制作、种植、敌人、存档或联机。

## 运行方式

1. 安装 Godot 4.3 或更高的 Godot 4.x 版本。
2. 在 Godot 项目管理器中导入仓库根目录的 `project.godot`。
3. 打开项目后运行主场景。

由于自动化执行环境没有 Godot 编辑器，本次提交完成了静态项目验证，但仍需要在装有 Godot 的电脑上进行首次导入和运行确认。

## 操作

| 操作 | 键位 |
|---|---|
| 移动 | `WASD` 或方向键 |
| 交互预留 | `E` |
| 攻击预留 | 鼠标左键或 `J` |
| 闪避预留 | 空格或 `K` |
| 暂停预留 | `Esc` |

只有移动在当前版本中实现；其他输入已经登记，供后续系统使用。

## 验证

不安装 Godot 也可以执行仓库级检查：

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
```

验证内容包括必需文件、主场景、基础视口、玩家组件契约、场景外部资源和第三方素材登记。

## 目录

```text
assets/
├── original/       项目原创占位美术
└── third_party/    经过许可证核验的第三方素材
scenes/
├── bootstrap/      程序入口
├── player/         玩家场景
└── world/          世界场景
scripts/player/     移动与朝向逻辑
tools/              独立于 Godot 的仓库验证工具
tests/              Python 自动测试
```

## 素材和许可证

所有第三方素材必须拥有明确的开放许可证，并按准确仓库路径登记在 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。当前导入的 Kenney 粒子素材位于独立目录中，并保留本地来源与许可证说明。

项目正式发布许可证将在垂直切片形成后确定。第三方内容继续使用其各自许可证。
