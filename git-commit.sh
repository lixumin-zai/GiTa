#!/bin/bash

# ==============================================================================
# GiTa 结构化 Git 提交交互辅助工具 (Git Commit Helper Skill)
# ==============================================================================
# 支持终端交互式引导（供用户使用）与命令行参数（供 AI 助手高效调用）
# 确保每一次提交记录都有极高的可读性、一致性与详细深度。
# ==============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 默认参数
TYPE=""
SCOPE=""
SUBJECT=""
DESC=""
REASON=""
IMPACT=""
AUTO_ADD=false
NON_INTERACTIVE=false

# 帮助信息
show_help() {
    echo -e "${CYAN}用法:${NC}"
    echo "  $0 [选项]"
    echo ""
    echo -e "${CYAN}可选项:${NC}"
    echo "  -t, --type <type>        提交类型 (feat, fix, docs, style, refactor, perf, test, chore等)"
    echo "  -s, --scope <scope>      影响范围 (e.g. Fretboard, Strumming, Network, Audio, UI)"
    echo "  -m, --subject <msg>      简短摘要"
    echo "  -d, --desc <desc>        详细改动说明 (What)"
    echo "  -r, --reason <reason>    修改原因 (Why)"
    echo "  -i, --impact <impact>    影响范围与兼容性说明 (Impact)"
    echo "  -a, --all                自动执行 git add . 暂存所有修改"
    echo "  -n, --non-interactive    非交互模式（若缺少参数将直接生成报错，而不是提示输入）"
    echo "  -h, --help               显示帮助信息"
    exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type) TYPE="$2"; shift 2 ;;
        -s|--scope) SCOPE="$2"; shift 2 ;;
        -m|--subject) SUBJECT="$2"; shift 2 ;;
        -d|--desc) DESC="$2"; shift 2 ;;
        -r|--reason) REASON="$2"; shift 2 ;;
        -i|--impact) IMPACT="$2"; shift 2 ;;
        -a|--all) AUTO_ADD=true; shift ;;
        -n|--non-interactive) NON_INTERACTIVE=true; shift ;;
        -h|--help) show_help ;;
        *) echo -e "${RED}未知参数: $1${NC}"; show_help ;;
    esac
done

# 检查当前 git 仓库状态
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}❌ 错误: 当前目录不是一个有效的 Git 仓库。${NC}"
    exit 1
fi

# 检查是否有未暂存的修改
UNSTAGED=$(git status --porcelain | grep -v '^[AMDRD]' || true)
STAGED=$(git status --porcelain | grep '^[AMDRD]' || true)

if [ -z "$STAGED" ] && [ -z "$UNSTAGED" ]; then
    echo -e "${YELLOW}ℹ️  暂无可提交的修改。${NC}"
    exit 0
fi

# 交互模式下的暂存提示
if [ "$NON_INTERACTIVE" = false ] && [ -n "$UNSTAGED" ]; then
    if [ "$AUTO_ADD" = true ]; then
        echo -e "${CYAN}🚀 正在自动暂存所有修改 (git add .)...${NC}"
        git add .
    else
        echo -e "${YELLOW}⚠️  检测到有未暂存的修改。${NC}"
        git status -s
        echo ""
        read -p "是否暂存所有修改并继续？(y/N): " choice
        case "$choice" in 
            y|Y|yes|YES) 
                git add .
                echo -e "${GREEN}✅ 已成功暂存所有修改！${NC}"
                ;;
            *) 
                echo -e "${YELLOW}⚠️  已跳过自动暂存。请确保你想提交的文件已被 git add 暂存后再运行此脚本。${NC}"
                if [ -z "$STAGED" ]; then
                    echo -e "${RED}❌ 错误: 没有已暂存的文件，无法提交。${NC}"
                    exit 1
                fi
                ;;
        esac
    fi
elif [ "$NON_INTERACTIVE" = true ] && [ "$AUTO_ADD" = true ]; then
    git add .
fi

# 交互引导输入
if [ "$NON_INTERACTIVE" = false ]; then
    echo -e "${BLUE}🎸 ======================================================= 🎸${NC}"
    echo -e "${GREEN}          GiTa 高标准结构化 Commit 生成工具${NC}"
    echo -e "${BLUE}🎸 ======================================================= 🎸${NC}"

    # 1. 确认类型
    if [ -z "$TYPE" ]; then
        echo -e "${CYAN}请选择本次提交的类型:${NC}"
        echo "  1) feat     - 新功能 (feature)"
        echo "  2) fix      - 修复 Bug"
        echo "  3) refactor - 代码重构 (非功能新增且非 Bug 修复)"
        echo "  4) perf     - 性能、内存或 DSP 算法优化"
        echo "  5) UI/style - UI 界面微调、间距布局修改、样式美化"
        echo "  6) docs     - 文档编写、README 或注释更新"
        echo "  7) chore    - 构建脚本、部署工具、辅助配置更新 (如 deploy.sh)"
        echo "  8) test     - 单元测试或自动化集成测试"
        
        while true; do
            read -p "请输入序号 (1-8): " type_idx
            case $type_idx in
                1) TYPE="feat"; break ;;
                2) TYPE="fix"; break ;;
                3) TYPE="refactor"; break ;;
                4) TYPE="perf"; break ;;
                5) TYPE="style"; break ;;
                6) TYPE="docs"; break ;;
                7) TYPE="chore"; break ;;
                8) TYPE="test"; break ;;
                *) echo -e "${RED}无效输入，请输入 1 到 8 之间的数字。${NC}" ;;
            esac
        done
    fi

    # 2. 确认范围
    if [ -z "$SCOPE" ]; then
        echo -e "\n${CYAN}请输入影响的模块范围 (例如: Network, Audio, UI, Fretboard, Strumming):${NC}"
        read -p "影响范围 [留空表示全局/不细分]: " SCOPE
    fi

    # 3. 简短摘要
    if [ -z "$SUBJECT" ]; then
        echo -e "\n${CYAN}请输入简短的修改摘要 (建议中文，简洁明了):${NC}"
        while true; do
            read -p "摘要说明: " SUBJECT
            if [ -z "$SUBJECT" ]; then
                echo -e "${RED}摘要说明不能为空！${NC}"
            else
                break
            fi
        done
    fi

    # 4. 详细改动
    if [ -z "$DESC" ]; then
        echo -e "\n${CYAN}请输入详细的代码改动说明 (What - 做了什么改动，多行可以逗号/空格分隔，直接按回车结束):${NC}"
        read -p "核心变动: " DESC
    fi

    # 5. 修改原因
    if [ -z "$REASON" ]; then
        echo -e "\n${CYAN}请输入进行本次修改的原因 (Why - 为什么要改，解决了什么 Bug/卡顿/时序错乱):${NC}"
        read -p "变更原因: " REASON
    fi

    # 6. 影响范围
    if [ -z "$IMPACT" ]; then
        echo -e "\n${CYAN}请输入改动带来的影响范围与验证方案 (Impact - 影响哪些模块，怎么验证的):${NC}"
        read -p "影响范围: " IMPACT
    fi
fi

# 非交互模式下的基本参数检查
if [ "$NON_INTERACTIVE" = true ]; then
    if [ -z "$TYPE" ] || [ -z "$SUBJECT" ]; then
        echo -e "${RED}❌ 错误: 非交互模式下，--type (-t) 和 --subject (-m) 必须提供！${NC}"
        exit 1
    fi
fi

# 构建结构化提交日志
COMMIT_HEADER=""
if [ -n "$SCOPE" ]; then
    COMMIT_HEADER="${TYPE}(${SCOPE}): ${SUBJECT}"
else
    COMMIT_HEADER="${TYPE}: ${SUBJECT}"
fi

# 拼接 Body
COMMIT_BODY=""

if [ -n "$DESC" ]; then
    COMMIT_BODY="${COMMIT_BODY}
- 核心变动 (What): ${DESC}"
fi

if [ -n "$REASON" ]; then
    COMMIT_BODY="${COMMIT_BODY}
- 变更原因 (Why): ${REASON}"
fi

if [ -n "$IMPACT" ]; then
    COMMIT_BODY="${COMMIT_BODY}
- 影响范围 (Impact): ${IMPACT}"
fi

# 写入临时文件作为 Commit Message
TEMP_MSG_FILE=$(mktemp)
echo "${COMMIT_HEADER}" > "$TEMP_MSG_FILE"
if [ -n "$COMMIT_BODY" ]; then
    echo "" >> "$TEMP_MSG_FILE"
    echo -e "${COMMIT_BODY}" >> "$TEMP_MSG_FILE"
fi

# 显示最终预览
echo -e "\n${GREEN}📝 准备生成的 Git 提交信息预览：${NC}"
echo -e "${BLUE}-------------------------------------------------------${NC}"
cat "$TEMP_MSG_FILE"
echo -e "${BLUE}-------------------------------------------------------${NC}"

# 提交确认
if [ "$NON_INTERACTIVE" = false ]; then
    read -p "确认以该模板提交？(Y/n): " confirm
    case "$confirm" in 
        n|N|no|NO) 
            echo -e "${YELLOW}❌ 已取消提交。${NC}"
            rm -f "$TEMP_MSG_FILE"
            exit 0
            ;;
        *) ;;
    esac
fi

# 执行提交
echo -e "${CYAN}🚀 正在执行提交 (git commit)...${NC}"
git commit -F "$TEMP_MSG_FILE"
echo -e "${GREEN}🎉 提交成功！${NC}"

# 清理临时文件
rm -f "$TEMP_MSG_FILE"
