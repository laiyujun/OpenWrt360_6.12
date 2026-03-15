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

# 下载部署toolchain缓存
download_toolchain() {
    local cache_xa cache_xc
    if [[ "$TOOLCHAIN_CACHE" = 'true' ]]; then
        cache_xa=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        cache_xc=$(curl -sL "https://api.github.com/repos/laiyujun/toolchain-cache/releases" | awk -F '"' '/download_url/{print $4}' | grep "$CACHE_NAME")
        echo "cache_xa=$cache_xa"
        echo "cache_xc=$cache_xc"
        if [[ "$cache_xa" || "$cache_xc" ]]; then
            wget -qc -t=3 "${cache_xa:-$cache_xc}"
            if [ -e *.tzst ]; then
                # 记录解压前的状态
                echo "🔄 解压前目录状态:"
                pwd
                ls -la staging_dir/host/bin/ 2>/dev/null || echo "staging_dir/host/bin 不存在"

                # 解压
                tar -I unzstd -xf *.tzst || tar -xf *.tzst

                [ "$cache_xa" ] || (cp *.tzst "$GITHUB_WORKSPACE"/output && echo "OUTPUT_RELEASE=true" >> "$GITHUB_ENV")
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
            else
              echo "⚠️ 未下载到最新工具链"
              return 99
            fi
        else
            echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
            echo "⚠️ 未找到最新工具链"
            return 99
        fi
    else
        echo "REBUILD_TOOLCHAIN=true" >> "$GITHUB_ENV"
        echo "⚠️ TOOLCHAIN_CACHE=$TOOLCHAIN_CACHE 重新编译最新工具链"
        return 99
    fi
}

main() {
    download_toolchain
    package_toolchain
}

# 创建toolchain缓存保存目录
[ -d "$GITHUB_WORKSPACE/output" ] || mkdir "$GITHUB_WORKSPACE/output"

main "$@"
