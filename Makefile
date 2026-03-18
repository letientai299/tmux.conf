.PHONY: install

install:
	@rm -f ~/.tmux.conf
	@ln -sfn "$(CURDIR)" ~/.config/tmux
	@echo "Linked ~/.config/tmux → $(CURDIR)"
