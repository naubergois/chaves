APP_NAME    := Chaves
BUNDLE_ID   := com.naubergois.chaves
VERSION     := 1.0.0
BUILD_DIR   := .build/release
DIST        := dist
APP_BUNDLE  := $(DIST)/$(APP_NAME).app
PYTHON      := python3

.PHONY: help build run test app install clean mcp mcp-config mcp-install-cursor python-test

help:
	@echo "make build              - compila em release"
	@echo "make run                - abre a janela (debug)"
	@echo "make test               - testes Swift + Python"
	@echo "make app                - gera $(APP_BUNDLE)"
	@echo "make install            - copia o .app para /Applications"
	@echo "make mcp                - inicia o servidor MCP em stdio"
	@echo "make mcp-config         - imprime o JSON de configuracao do MCP"
	@echo "make mcp-install-cursor - registra o servidor em ~/.cursor/mcp.json"

build:
	swift build -c release

run:
	swift run $(APP_NAME)

python-test:
	PYTHONPATH=python $(PYTHON) -m unittest discover -s python/tests -p 'test_*.py' -v

test: python-test
	swift test

app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	sed -e 's/__APP_NAME__/$(APP_NAME)/g' \
	    -e 's/__BUNDLE_ID__/$(BUNDLE_ID)/g' \
	    -e 's/__VERSION__/$(VERSION)/g' \
	    Resources/Info.plist.in > $(APP_BUNDLE)/Contents/Info.plist
	cp -R python $(APP_BUNDLE)/Contents/Resources/python
	codesign --force --deep --sign - $(APP_BUNDLE) 2>/dev/null || true
	@echo "OK -> $(APP_BUNDLE)"

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Instalado em /Applications/$(APP_NAME).app"

mcp:
	swift run $(APP_NAME) --mcp

mcp-config:
	@./scripts/install-mcp.sh print

mcp-install-cursor: app
	./scripts/install-mcp.sh cursor

clean:
	swift package clean
	rm -rf $(DIST) .build
