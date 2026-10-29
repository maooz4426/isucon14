.PHONY: server/start-session benchmarker/start-session server/deploy

# 使い方: make server/start-session INSTANCE_ID=i-xxxxxxxx [AWS_PROFILE=xxx]
INSTANCE_ID ?= i-0b217db44e076dd04
# 使い方: make benchmarker/start-session BENCH_INSTANCE_ID=i-xxxxxxxx [AWS_PROFILE=xxx]
BENCH_INSTANCE_ID ?= i-010ad0d8f1a47f2cf

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

# 使い方: make server/deploy [BRANCH=feature/xxx]
BRANCH ?= main
REPO_DIR ?= /home/isucon/webapp
DEPLOY_CMD = cd $(REPO_DIR) && git fetch origin && git checkout $(BRANCH) && git pull --ff-only origin $(BRANCH) && cd rust && /home/isucon/.x cargo build --release --locked && sudo systemctl restart isuride-rust

server/deploy:
	@test -n "$(INSTANCE_ID)" || (echo "INSTANCE_ID を指定してください" && exit 1)
	aws ssm start-session \
		--target $(INSTANCE_ID) \
		--document-name AWS-StartInteractiveCommand \
		--parameters '{"command":["sudo -i -u isucon bash -c \"$(DEPLOY_CMD)\""]}'
