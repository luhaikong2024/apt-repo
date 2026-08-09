# 常用入口（官方 dists/ + pool/ 仓库）

.PHONY: help gpg bootstrap toolchain package all repo publish clean

help:
	@echo "目标:"
	@echo "  make gpg          初始化 GPG 签名密钥"
	@echo "  make bootstrap    生成 packaging/<包名>/debian"
	@echo "  make toolchain S=jammy A=amd64|arm64"
	@echo "  make package   S=jammy A=amd64|arm64"
	@echo "  make all          构建全部套件×架构并发布到 public/"
	@echo "  make repo         生成官方 dists 路径（含 amd64/arm64）并签名"
	@echo "  make publish      同步到 public/"
	@echo "  make clean        清理产物（不删源码与密钥）"

gpg:
	./scripts/init-gpg.sh

bootstrap:
	./scripts/bootstrap-packaging.sh

toolchain:
	./scripts/build-toolchain.sh "$(S)" "$(or $(A),amd64)"

package:
	./scripts/build-package.sh "$(S)" "$(or $(A),amd64)"

all:
	./scripts/build-all.sh

repo:
	./scripts/generate-repo.sh

publish:
	./scripts/publish.sh

clean:
	rm -rf artifacts build public/dists public/pool repo/pool repo/dists repo/.meta repo/.cache
