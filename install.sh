#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# md-editor 一行命令安装脚本
# curl -fsSL https://raw.githubusercontent.com/cxiaohuan2011/MD-editor/main/install.sh | bash
#
# 目的：curl 下载的文件不带 com.apple.quarantine 隔离标记，绕开 Gatekeeper 对
# 未公证 app 的拦截，让没花 $99 做 Apple 公证的免费闭源 app 也能一行命令装上。
# ---------------------------------------------------------------------------

# 可覆盖的环境变量。这两行是纯粹的默认值读取，不产生任何副作用，
# 即使 curl | bash 中途被截断在这里，也只是脚本语法不完整报错退出，不会有任何命令被执行。
APP_DST="${APP_DST:-/Applications/md-editor.app}"
MD_DMG="${MD_DMG:-}"

# 所有会执行的逻辑都塞进 main()，最后一行才调用它。
# 原因：bash 要读到 main() 的收尾 "}" 才算解析出一条完整命令。
# 如果网络中断导致 curl | bash 的输出在 main 函数体中间被截断，
# bash 会因为函数没闭合而报语法错直接退出，绝不会去执行截断处之前的半条命令。
main() {
  echo "正在安装 md-editor ..."

  # 状态变量先置空，trap 里用 ${var:-} 兜底，避免 set -u 下 cleanup 自己炸掉。
  tmp_dir=""
  mount_point=""
  new_app_dst=""

  cleanup() {
    # 进门先存下真实退出码，出门原样透传：否则最后一个 if 的返回值会顶掉它，
    # 崩溃了退出码却是 0。EXIT trap 里的 exit 不会重触发 trap，安全。
    local rc=$?
    if [ -n "${mount_point:-}" ]; then
      hdiutil detach "$mount_point" -quiet -force 2>/dev/null || true
    fi
    if [ -n "${tmp_dir:-}" ] && [ -d "${tmp_dir:-}" ]; then
      rm -rf "$tmp_dir"
    fi
    if [ -n "${new_app_dst:-}" ] && [ -d "${new_app_dst:-}" ]; then
      rm -rf "$new_app_dst"
    fi
    exit "$rc"
  }
  trap cleanup EXIT INT TERM

  local dmg_path

  if [ -n "$MD_DMG" ]; then
    # 测试口子：指定本地 dmg，跳过 GitHub API 查询和下载。
    echo "检测到 MD_DMG，使用本地安装包：$MD_DMG"
    if [ ! -f "$MD_DMG" ]; then
      echo "错误：MD_DMG 指定的文件不存在：$MD_DMG" >&2
      exit 1
    fi
    dmg_path="$MD_DMG"
  else
    echo "正在获取最新版本信息..."
    tmp_dir=$(mktemp -d)
    local release_json="$tmp_dir/release.json"
    local http_code
    # curl 失败（连不上网）不能让 set -e 直接把脚本干掉，兜底成 000 交给下面分支统一报错。
    http_code=$(curl -s -o "$release_json" -w '%{http_code}' \
      https://api.github.com/repos/cxiaohuan2011/MD-editor/releases/latest) || http_code="000"

    case "$http_code" in
      200) ;;
      403)
        echo "错误：请求过于频繁（GitHub 匿名限流），请稍后重试，或到 https://github.com/cxiaohuan2011/MD-editor/releases 手动下载。" >&2
        exit 1
        ;;
      404)
        echo "错误：找不到发布版本，仓库可能暂不可访问，请到 https://github.com/cxiaohuan2011/MD-editor/releases 手动确认。" >&2
        exit 1
        ;;
      *)
        echo "错误：获取版本信息失败（状态码 ${http_code}），像是网络异常，请检查网络后重试。" >&2
        exit 1
        ;;
    esac

    # 先抓出含 browser_download_url 且以 .dmg 结尾的那一段，再从里面截出真正的 URL。
    local dmg_url
    dmg_url=$(grep -o '"browser_download_url": *"[^"]*\.dmg"' "$release_json" \
      | head -n1 | grep -o 'https://[^"]*') || true
    if [ -z "$dmg_url" ]; then
      echo "错误：没能在版本信息里找到 dmg 安装包地址，请到 https://github.com/cxiaohuan2011/MD-editor/releases 手动下载。" >&2
      exit 1
    fi

    echo "正在下载安装包..."
    dmg_path="$tmp_dir/md-editor.dmg"
    if ! curl -fL --progress-bar -o "$dmg_path" "$dmg_url"; then
      echo "错误：下载失败，请检查网络连接后重试。" >&2
      exit 1
    fi
  fi

  echo "正在准备安装文件..."
  local attach_output
  if ! attach_output=$(hdiutil attach "$dmg_path" -nobrowse -readonly 2>&1); then
    echo "错误：挂载安装包失败，dmg 文件可能已损坏，请重新下载后重试。" >&2
    echo "$attach_output" >&2
    exit 1
  fi

  # 不能用 -quiet，否则拿不到挂载点。真实输出前面还有几行 Checksumming/verified 干扰，
  # 只认含 /Volumes/ 的那一行；卷名可能带空格，取该行最后一个 tab 字段而不是用 grep 截 /Volumes/xxx。
  mount_point=$(printf '%s\n' "$attach_output" | awk -F'\t' '$NF ~ /\/Volumes\// {print $NF; exit}')
  mount_point=$(printf '%s' "$mount_point" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  if [ -z "$mount_point" ]; then
    echo "错误：无法识别安装包的挂载路径，请重新运行脚本，或双击下载好的 dmg 手动安装。" >&2
    exit 1
  fi

  local app_src
  app_src=$(find "$mount_point" -maxdepth 1 -name '*.app' | head -n1)
  if [ -z "$app_src" ]; then
    echo "错误：安装包里没有找到 .app，安装包可能已损坏，请重新下载。" >&2
    exit 1
  fi

  echo "正在安装..."
  new_app_dst="${APP_DST}.new.$$"
  # 用 ditto 而不是 cp -R：ditto 才会完整保留 app bundle 的扩展属性和签名结构，cp -R 会悄悄破坏签名。
  if ! ditto "$app_src" "$new_app_dst"; then
    echo "错误：安装失败，可能是权限不足。" >&2
    echo "你可以在终端手动执行（需要管理员密码）：" >&2
    echo "  sudo ditto \"$app_src\" \"$APP_DST\"" >&2
    exit 1
  fi

  # 安全覆盖：先把新版本装好，再挪走旧版本，最后才把新版本改名到位，任何一步失败都不会丢旧版本。
  if [ -e "$APP_DST" ]; then
    mv "$APP_DST" "${APP_DST}.old.$$"
  fi
  mv "$new_app_dst" "$APP_DST"
  new_app_dst=""
  rm -rf "${APP_DST}.old.$$" 2>/dev/null || true

  # curl/ditto 走完一般不会再带隔离标记，这里只是兜底再清一次。
  xattr -cr "$APP_DST" 2>/dev/null || true

  echo "正在启动..."
  open "$APP_DST"

  # 注意：$变量 后面紧跟中文/全角标点时必须写成 ${变量}，
  # macOS 自带 bash 3.2 会把多字节字符的首字节误吞进变量名，set -u 下报 unbound variable。
  echo "安装完成！md-editor 已经装到 ${APP_DST}，以后直接在「访达」或 Launchpad 里双击打开就行。"
}

main "$@"
