![IMG_0414](https://github.com/user-attachments/assets/39d1c96a-1fc3-4497-9f5b-386c79586fc1)# Claude Code 环境部署脚本

## 简介
这是一个用于配置 Claude Code 开发环境的脚本，支持官方 API 和代理 API 模式的快速切换，并允许用户自定义代理 API URL。脚本提供了灵活的配置选项，适合需要在不同 API 环境间切换的开发者使用。

## 功能特点
- 支持官方 API 和代理 API 模式切换
- 允许用户自定义代理 API URL
- 提供预设密钥功能，方便快速切换环境
- 自动配置环境变量
- 配置验证和错误处理
- 支持跳过 JSON 配置更新
- 显示当前使用的 API URL

## 使用方法
### 基本用法
```bash
# 克隆仓库
git clone <仓库URL>
cd prj05-juzi

# 给脚本添加执行权限
chmod +x claudecodeswitcher.sh

# 运行脚本
./claudecodeswitcher.sh <api-key>
```

### 不同模式示例
#### 1. 官方 API 模式
```bash
# 使用官方 API
./claudecodeswitcher.sh <api-key> --official
```

#### 2. 代理 API 模式（使用默认代理 URL）
```bash
# 使用代理 API
./claudecodeswitcher.sh <api-key> --proxy
```

#### 3. 自定义代理 API URL
```bash
# 使用自定义代理 URL
./claudecodeswitcher.sh <api-key> --proxy --proxy-url <your-proxy-url>
```

#### 4. 使用预设密钥
```bash
# 使用官方预设密钥
./claudecodeswitcher.sh --official-preset

# 使用代理预设密钥
./claudecodeswitcher.sh --proxy-preset
```

## 参数说明
- `<api-key>`: 手动指定 Anthropic API 密钥
- `--official`: 使用官方 API 模式
- `--proxy`: 使用代理 API 模式
- `--proxy-url <url>`: 自定义代理 API URL（仅在代理模式下有效）
- `--official-preset`: 使用内置官方 API 密钥
- `--proxy-preset`: 使用内置代理 API 密钥
- `--skip-json`: 跳过更新 settings.local.json 文件
- `-h`, `--help`: 显示帮助信息

## 注意事项
1. 首次使用前请确保脚本具有执行权限：`chmod +x claudecodeswitcher.sh`
2. 预设密钥功能仅供参考，请根据实际情况更新脚本中的预设密钥
3. 使用自定义代理 URL 时，请确保该 URL 是有效的
4. 脚本会修改环境变量，建议在专用终端或使用 `source` 命令执行以避免影响全局环境
5. 默认代理 URL 为 `default`，使用时请根据实际情况配置

## 配置文件
脚本会读取和修改以下配置文件：
- `~/.claude/settings.local.json`: Claude 配置文件

## 环境变量
脚本会设置或修改以下环境变量：
- `ANTHROPIC_API_KEY`: Anthropic API 密钥
- `ANTHROPIC_API_URL` 或 `ANTHROPIC_BASE_URL`: API 端点 URL

## 许可证
[MIT License](LICENSE)

## 作者
X-@oops073111

## 有没有稳定可靠不封号安全不魔改的claude code 服务(独立运营）
请大家加地球号 oops0731111 了解


![IMG_2967](https://github.com/user-attachments/assets/51981761-c7fc-4f95-b53d-794dddf55e4f)

<img width="930" height="678" alt="好评1" src="https://github.com/user-attachments/assets/5780d9d2-57e3-4355-a8ce-0b434c558c6d" />
<img width="915" height="514" alt="好评2" src="https://github.com/user-attachments/assets/3d6f63ac-ff43-4e14-a7f0-a31f57dd2310" />
<img width="863" height="576" alt="好评3" src="https://github.com/user-attachments/assets/4c449c97-0275-4f76-b76b-af8bc82c9cce" />
