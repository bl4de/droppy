# os deps: node yarn git jq docker

JQUERY_FLAGS=-ajax,-css,-deprecated,-effects,-event/alias,-event/focusin,-event/trigger,-wrap,-core/ready,-deferred,-exports/amd,-sizzle,-offset,-dimensions,-serialize,-queue,-callbacks,-event/support,-event/ajax,-attributes/prop,-attributes/val,-attributes/attr,-attributes/support,-manipulation/setGlobalEval,-manipulation/support,-manipulation/var/rcheckableType,-manipulation/var/rscriptType

deps:
	yarn global add eslint@latest eslint-plugin-unicorn@latest stylelint@latest uglify-js@latest grunt@latest npm-check-updates@latest

test:
	$(MAKE) lint

lint:
	node_modules/.bin/eslint --color --ignore-pattern *.min.js --plugin unicorn --rule 'unicorn/catch-error-name: [2, {name: err}]' --rule 'unicorn/throw-new-error: 2' server client *.js
	node_modules/.bin/stylelint client/*.css
	node_modules/.bin/eclint check

build:
	touch client/client.js
	node droppy.js build

publish:
	if git ls-remote --exit-code origin &>/dev/null; then git push -u -f --tags origin master; fi
	if git ls-remote --exit-code git &>/dev/null; then git push -u -f --tags git master; fi
	npm publish

docker:
	$(eval IMAGE := silverwind/droppy)
	@echo Preparing docker image $(IMAGE)...
	docker pull alpine:latest
	docker rm -f "$$(docker ps -a -f='ancestor=$(IMAGE)' -q)" 2>/dev/null || true
	docker rmi "$$(docker images -qa $(IMAGE))" 2>/dev/null || true
	docker build --no-cache=true --squash -t $(IMAGE) .
	docker tag "$$(docker images -qa $(IMAGE):latest)" $(IMAGE):"$$(cat package.json | jq -r .version)"

docker-arm:
	$(eval IMAGE := silverwind/armhf-droppy)
	@echo Preparing docker image $(IMAGE)...
	docker pull arm32v6/alpine
	sed -i "s/^FROM.\+/FROM arm32v6\/alpine/g" Dockerfile
	docker rm -f "$$(docker ps -a -f='ancestor=$(IMAGE)' -q)" 2>/dev/null || true
	docker rmi "$$(docker images -qa $(IMAGE))" 2>/dev/null || true
	docker build --no-cache=true --squash -t $(IMAGE) .
	docker tag "$$(docker images -qa $(IMAGE):latest)" $(IMAGE):"$$(cat package.json | jq -r .version)"
	sed -i "s/^FROM.\+/FROM alpine/g" Dockerfile

docker-push:
	docker push silverwind/droppy:"$$(cat package.json | jq -r .version)"
	docker push silverwind/droppy:latest
	docker push silverwind/armhf-droppy:"$$(cat package.json | jq -r .version)"
	docker push silverwind/armhf-droppy:latest

update:
	node_modules/.bin/updates -u
	rm -rf node_modules
	yarn
	touch client/client.js

deploy:
	git commit --allow-empty --allow-empty-message -m ""
	if git ls-remote --exit-code demo &>/dev/null; then git push -f demo master; fi
	if git ls-remote --exit-code droppy &>/dev/null; then git push -f droppy master; fi
	git reset --hard HEAD~1

jquery:
	rm -rf /tmp/jquery
	git clone --depth 1 https://github.com/jquery/jquery /tmp/jquery
	cd /tmp/jquery; yarn; grunt; grunt custom:$(JQUERY_FLAGS); grunt remove_map_comment
	cat /tmp/jquery/dist/jquery.min.js | perl -pe 's|"3\..+?"|"3"|' > $(CURDIR)/client/jquery-custom.min.js
	rm -rf /tmp/jquery

version-patch:
	npm version patch

version-minor:
	npm version minor

version-major:
	npm version major

patch: test build version-patch deploy publish docker docker-arm docker-push
minor: test build version-minor deploy publish docker docker-arm docker-push
major: test build version-major deploy publish docker docker-arm docker-push

.PHONY: deps test lint publish docker docker-arm update deploy jquery version-patch version-minor version-major patch minor major
