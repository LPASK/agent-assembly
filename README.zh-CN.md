# agent-assembly

[![CI](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml/badge.svg)](https://github.com/LPASK/agent-assembly/actions/workflows/ci.yml)

你的 agent 应该认识你——在每一个项目里。

## 问题

不同项目需要你的不同面。写代码的项目需要你的技术背景，做研究的项目需要你的阅读兴趣和认知模式。但你的 agent 每次启动都是一个陌生人——除非你到处复制粘贴同一份上下文。

与此同时，有些东西属于*你*，不属于任何项目。目标、成长轨迹、定期复盘——这些横跨所有仓库。它们要么无处安放，要么到处重复。

## 工作原理

```
                        agent-assembly
                       ┌──────────────┐
                       │   modules/   │
                       │  ┌────────┐  │
                       │  │ 画像    │  │
                       │  │ 目标    │  │
                       │  │ 记忆    │  │
                       │  │ 钩子    │  │
                       │  └────────┘  │
                       └──────┬───────┘
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
          项目 A          项目 B          项目 C
         (全部模块)      (仅画像)      (画像+目标)
```

- **模块化画像。** 把自己拆成组件——技术背景、目标、认知模式、行为准则。每个项目只组装它需要的部分。
- **Launcher 即配置。** 每个项目一个短 bash 脚本。它选模块、跑流水线、启动 agent。不需要 YAML，没有中心化配置。
- **共享记忆层。** 一个 `memory/` 目录，任何 session 都能访问。个人反思和跨项目上下文在这里积累。

## 开始使用

```bash
git clone https://github.com/LPASK/agent-assembly.git ~/agent-assembly
cd ~/agent-assembly
```

然后在这个目录启动你的 agent CLI，让它帮你搞定一切：

```bash
claude   # 或你用的其他 agent CLI
```

> 帮我设置 agent-assembly。先读 CLAUDE.md 和 SPEC.md 理解这个系统，
> 然后引导我编写模块、创建第一个 launcher。

Agent 会读文档、了解你的背景，然后帮你生成所有配置。你只需要回答它的问题。

### Agent 设置指南

如果你是正在帮用户设置这个项目的 agent，按以下顺序操作：

1. **读文档。** 读 `CLAUDE.md` 和 `SPEC.md`，理解完整系统。
2. **重写模块。** `modules/` 下的文件是假数据示例。采访用户的背景、目标和偏好，然后用真实信息重写每个模块。
3. **创建 launcher。** 复制 `launchers/example-mac-claude.sh` 为新文件，以用户的第一个项目命名。设置 `TARGET` 为项目路径，选择所需模块。各函数的作用见下方流水线章节。
4. **测试。** 运行 `bash tests/run.sh` 验证一切正常。
5. **启动。** 运行新建的 launcher 脚本，开始一个完整的 assembled session。

---

*遇到问题？* [提 issue。](https://github.com/LPASK/agent-assembly/issues)
*觉得好用？* [给个 star](https://github.com/LPASK/agent-assembly)——帮更多人发现它。

---

## 参考手册

以下是给开发者和 agent 的详细参考。

### 流水线

每个 launcher 执行同一条流水线：

```
assemble_modules → assemble_hooks → assemble_skills → ensure_gitignore → launch
```

| 步骤 | 做什么 | 产出 |
|------|--------|------|
| `assemble_modules` | 把选中的模块拼接成一个文件 | `TARGET/CLAUDE.local.md` |
| `assemble_hooks` | 从脚本生成 hook 配置 | `TARGET/.claude/settings.local.json` |
| `assemble_skills` | 把 skill 符号链接到目标项目 | `TARGET/.claude/skills/*` |
| `ensure_gitignore` | 确保生成的文件被 gitignore | 追加到 `TARGET/.gitignore` |
| `launch` | 在目标目录启动 CLI | — |

所有生成的文件在目标项目中都被 gitignore。目标项目自己的 `CLAUDE.md` 不受影响。

### 设计决策

**Launcher 即配置。** 不需要 YAML 配置文件。每个 launcher 是一个短 bash 脚本，调用流水线函数并传入所需模块。新增项目 = 复制一个 launcher，改目标路径和模块列表。

**模块是唯一事实来源。** 你的画像、目标、行为准则都在 `modules/` 里。它们在启动时被组装成 `CLAUDE.local.md`。生成的文件每次启动都会被覆盖——永远不要手动编辑它。

**跨项目记忆是可选的。** Launcher 可以传 `--add-dir ~/agent-assembly/memory` 让 agent 读写共享记忆目录。项目级记忆留在项目里；个人/跨项目记忆放在这里。

**Hook 是确定性守卫。** 自带的 `prompt-guard.sh` 在每次用户输入时触发，注入目标对齐检查和记忆过期提醒。你可以为其他生命周期事件编写自己的 hook。

**生成物是临时的。** 目标项目中的 `CLAUDE.local.md`、`.claude/settings.local.json`、`.claude/skills/` 都是生成的、被 gitignore 的、每次启动覆盖的。

### 扩展

**新模块**：创建 `modules/my-module.md`，在 launcher 的 `assemble_modules` 调用中加上文件名。

**新 hook**：创建 `hooks/my-hook.sh`（从 stdin 接收 JSON，向 stdout 输出 JSON），在 launcher 的 `assemble_hooks` 调用中加上文件名。

**新项目**：复制一个 launcher，改 `TARGET` 和模块列表。

**新 skill**：创建 `.claude/skills/my-skill/SKILL.md`，在 launcher 的 `assemble_skills` 调用中加上。

完整规范见 [SPEC.md](SPEC.md)。

### 目录结构

```
agent-assembly/
├── launchers/           # 各项目的启动脚本
│   ├── lib.sh           # 流水线库（5 个函数）
│   └── example-mac-claude.sh
├── modules/             # 画像组件（事实来源）
├── hooks/               # 注入到 session 的 hook 脚本
│   └── prompt-guard.sh  # 行动检查 + 记忆提醒
├── memory/              # 跨项目 session 日志
├── tests/               # 回归测试
├── SPEC.md              # 系统规范
└── CLAUDE.md            # Agent 入口
```

### 测试

```bash
bash tests/run.sh
```

21 个测试，覆盖模块组装、hook 生成、gitignore 管理、hook 行为和文档一致性。CI 在 Ubuntu 和 macOS 上运行。

### 环境要求

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 或兼容的 agent CLI
- bash、jq
- macOS 或 Linux

## 许可证

MIT
