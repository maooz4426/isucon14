.PHONY: server/start-session benchmarker/start-session deploy reset-logs

# 使い方: make server/start-session INSTANCE_ID=i-xxxxxxxx [AWS_PROFILE=xxx]
INSTANCE_ID ?= i-0b217db44e076dd04
# 使い方: make benchmarker/start-session BENCH_INSTANCE_ID=i-xxxxxxxx [AWS_PROFILE=xxx]
BENCH_INSTANCE_ID ?= i-0afbb9a22c4bc2db4

server/start-session:
	@test -n "$(INSTANCE_ID)" || (echo "INSTANCE_ID を指定してください" && exit 1)
	aws ssm start-session \
		--target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters '{"command":["sudo -i -u isucon"]}'

benchmarker/start-session:
	@test -n "$(BENCH_INSTANCE_ID)" || (echo "BENCH_INSTANCE_ID を指定してください" && exit 1)
	aws ssm start-session \
		--target $(BENCH_INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters '{"command":["sudo -i -u isucon"]}'

# サーバー上で実行する: make deploy [BRANCH=feature/xxx]
BRANCH ?= master
REPO_DIR ?= /home/isucon/webapp

deploy:
	cd $(REPO_DIR) && git fetch origin && git checkout $(BRANCH) && git pull --ff-only origin $(BRANCH)
	cd $(REPO_DIR)/rust && /home/isucon/.x cargo build --release --locked
	sudo systemctl restart isuride-rust

# サーバー上で実行する: make reset-logs [MYSQL_SLOW_LOG=/path] [NGINX_ACCESS_LOG=/path] [NGINX_ERROR_LOG=/path]
# ファイルを削除せず truncate する。MySQL と nginx は開いたファイルを保持し続けるため。
MYSQL_SLOW_LOG ?= /var/log/mysql/mysql-slow.log
NGINX_ACCESS_LOG ?= /var/log/nginx/access.log
NGINX_ERROR_LOG ?= /var/log/nginx/error.log

reset-logs:
	sudo truncate -s 0 $(MYSQL_SLOW_LOG) $(NGINX_ACCESS_LOG) $(NGINX_ERROR_LOG)
