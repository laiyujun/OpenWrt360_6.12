#!/bin/bash

package_toolchain() {
  # 打包toolchain目录
  if [[ "$REBUILD_TOOLCHAIN" = 'true' ]]; then
      cd "$OPENWRT_PATH" || exit
      sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
      if [[ -d ".ccache" && $(du -s .ccache | cut -f1) -gt 0 ]]; then
          echo "🔍 缓存目录大小:"
          du -h --max-depth=1 .ccache
          ccache_dir=".ccache"
      fi
      echo "📦 工具链目录大小:"
      du -h --max-depth=1 staging_dir
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

# 下载部署toolchain缓存
download_toolchain() {
    local cache_xa cache_xc
    if [[ "$TOOLCHAIN" = 'true' ]]; then
        cache_xa=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        cache_xc=$(curl -sL "https://api.github.com/repos/haiibo/toolchain-cache/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        if [[ "$cache_xa" || "$cache_xc" ]]; then
            wget -qc -t=3 "${cache_xa:-$cache_xc}"
            if [ -e *.tzst ]; then
                tar -I unzstd -xf *.tzst || tar -xf *.tzst
                [ "$cache_xa" ] || (cp *.tzst "$GITHUB_WORKSPACE"/output && echo "OUTPUT_RELEASE=true" >> "$GITHUB_ENV")
                [ -d staging_dir ] && sed -i 's/ $(tool.*\/stamp-compile)//' Makefile
            fi
        else
            echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
            echo "⚠️ 未找到最新工具链"
            return 99
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
        return 99
    fi
}

main() {
  if [[ "$1" == "make" ]]; then
    package_toolchain
  else
    download_toolchain
  fi
}

# 创建toolchain缓存保存目录
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

main "$@"
