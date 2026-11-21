#!/bin/bash

package_toolchain() {
  # 打包toolchain目录
  if [[ "$REBUILD_TOOLCHAIN" = 'true' ]]; then
      sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
      if [[ -d ".ccache" && $(du -s .ccache | cut -f1) -gt 0 ]]; then
          echo "🔍 缓存目录大小:"
          du -h --max-depth=1 .ccache
          ccache_dir=".ccache"
      fi
      echo "📦 工具链目录大小:"
      du -h --max-depth=1 staging_dir

      # 在打包脚本中添加验证
      echo "🔍 检查要打包的文件..."
      if [[ -f staging_dir/host/bin/ccache ]]; then
          echo "✅ ccache 存在，大小: $(stat -c%s staging_dir/host/bin/ccache) 字节"
      else
          echo "❌ 警告：ccache 不存在！"
          echo "staging_dir/host/bin 内容:"
          ls -la staging_dir/host/bin/ 2>/dev/null || echo "目录不存在"
      fi

      # 记录打包内容
      echo "📦 打包内容:"
      tar -I zstdmt -cf "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" staging_dir/host* staging_dir/tool* $ccache_dir

      echo "📁 输出目录内容:"
      ls -lh "$GITHUB_WORKSPACE/output"
      if [[ ! -e "$GITHUB_WORKSPACE/output/$CACHE_NAME.tzst" ]]; then
          echo "❌ 工具链打包失败!"
          exit 1
      fi

      echo "✅ 工具链打包完成"
      exit 0
  fi
}

# 缓存资产按固定 tag（toolchain-cache）+ 本地可推导的 CACHE_NAME.tzst 发布，
# 下载直接用 release 直链，不再查询 /releases API：
#   命中 = HTTP 200 下载成功；未命中 = 404（由 wget 退出码 / 空文件判定）。
# 这样从根上消除 JSON 单行/多行解析差异，也不消耗 API 配额。

# 下载并部署一份缓存；成功返回 0，任何环节失败返回 1（由调用方决定回退或重建）
fetch_and_deploy_toolchain() {
    local url="$1" from_backup="$2"
    local tzst="$CACHE_NAME.tzst"

    rm -f "$tzst"
    wget -q --tries=3 --timeout=30 -O "$tzst" "$url"
    if [[ $? -ne 0 || ! -s "$tzst" ]]; then
        echo "    ⚠️ 缓存下载失败：$url" >&2
        rm -f "$tzst"
        return 1
    fi

    # 记录解压前的状态
    echo "🔄 解压前目录状态:"
    pwd
    ls -la staging_dir/host/bin/ 2>/dev/null || echo "staging_dir/host/bin 不存在"

    # 解压（zstd 失败回退普通 tar）
    if ! tar -I unzstd -xf "$tzst"; then
        echo "⚠️ zstd 解压失败，回退普通 tar" >&2
        if ! tar -xf "$tzst"; then
            echo "    ⚠️ 缓存解压失败" >&2
            rm -f "$tzst"
            return 1
        fi
    fi

    # 保持原行为：仅备用库命中时回传主用 release
    [[ "$from_backup" = 'true' ]] && (cp "$tzst" "$GITHUB_WORKSPACE"/output && echo "OUTPUT_RELEASE=true" >> "$GITHUB_ENV")
    # 保持原行为：去掉 tool stamp，避免后续 make 重复编译工具链
    [ -d staging_dir ] && sed -i 's/ $(tool.*\/stamp-compile)//' Makefile

    # 详细检查解压结果
    echo "📁 解压后目录结构:"
    ls -lah staging_dir

    # 特别检查 ccache
    echo "🔍 检查 ccache:"
    if [[ -f staging_dir/host/bin/ccache ]]; then
        echo "✅ ccache 文件存在"
        ls -la staging_dir/host/bin/ccache
        chmod +x staging_dir/host/bin/ccache
        echo "权限设置: $(stat -c "%a %n" staging_dir/host/bin/ccache)"

        # 测试 ccache 是否可执行
        if staging_dir/host/bin/ccache --version >/dev/null 2>&1; then
            echo "✅ ccache 可执行"
        else
            echo "❌ ccache 无法执行，尝试修复..."
            # 尝试从系统安装 ccache
            if command -v ccache >/dev/null 2>&1; then
                echo "从系统复制 ccache..."
                cp $(command -v ccache) staging_dir/host/bin/ccache
                chmod +x staging_dir/host/bin/ccache
            fi
        fi
    else
        echo "❌ ccache 文件不存在！"
        echo "搜索所有 ccache 文件:"
        find . -name "ccache" -type f 2>/dev/null

        # 尝试从备份恢复
    fi

    # 检查工具链
    echo "🔧 检查工具链:"
    if compgen -G "staging_dir/toolchain-*/bin/*-gcc" > /dev/null; then
        echo "✅ 找到交叉编译器"
        ls staging_dir/toolchain-*/bin/*-gcc | head -5
    else
        echo "❌ 未找到交叉编译器"
    fi

    echo "✅ 工具链下载完成"
    return 0
}

# 下载部署toolchain缓存
download_toolchain() {
    local url_a url_c

    if [[ "$TOOLCHAIN_CACHE" != 'true' ]]; then
        echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
        echo "⚠️ TOOLCHAIN_CACHE=$TOOLCHAIN_CACHE 重新编译最新工具链"
        return 99
    fi

    # 固定 tag + 可推导文件名直接拼直链，无需 API 查询：
    #   主用 = 当前仓库，备用 = laiyujun/toolchain-cache
    url_a="https://github.com/$GITHUB_REPOSITORY/releases/download/toolchain-cache/$CACHE_NAME.tzst"
    url_c="https://github.com/laiyujun/toolchain-cache/releases/download/toolchain-cache/$CACHE_NAME.tzst"

    # 主用优先；主用下载/解压失败时真回退备用
    echo "    ⏳ 尝试主用缓存：$url_a"
    if fetch_and_deploy_toolchain "$url_a" false; then
        echo "    ✅ 工具链缓存部署完成（主用）"
        return 0
    fi
    echo "    ⚠️ 主用缓存不可用，尝试备用仓库" >&2

    echo "    ⏳ 尝试备用缓存：$url_c"
    if fetch_and_deploy_toolchain "$url_c" true; then
        echo "    ✅ 工具链缓存部署完成（备用）"
        return 0
    fi
    echo "    ⚠️ 备用缓存不可用" >&2

    # 安全兜底：任何未成功部署的路径都必须显式触发编译。
    echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
    echo "⚠️ 未找到可用工具链缓存，将执行完整工具链编译"
    return 99
}

main() {
    download_toolchain
    package_toolchain
}

# 创建toolchain缓存保存目录
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

main "$@"
