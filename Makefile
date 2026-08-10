.PHONY: help gpg import repo publish all clean

help:
	@echo "apt-repo — APT 包管理与 GitHub Pages 分发"
	@echo ""
	@echo "  make gpg       初始化 / 检查签名密钥"
	@echo "  make import    导入 incoming/<套件>/*.deb"
	@echo "  make repo      生成 dists/ 索引并签名"
	@echo "  make publish   同步到 public/"
	@echo "  make all       import + repo + publish"
	@echo "  make clean     清理生成产物"
	@echo ""
	@echo "编包请到私有仓 apt-repo-toolchain，再用 make sync-publish 推过来。"

gpg:
	./scripts/init-gpg.sh

import:
	./scripts/import-incoming.sh

repo:
	./scripts/generate-repo.sh

publish:
	./scripts/publish.sh

all: import
	./scripts/generate-repo.sh
	./scripts/publish.sh

clean:
	rm -rf repo/pool repo/dists repo/.meta repo/.cache public/dists public/pool
