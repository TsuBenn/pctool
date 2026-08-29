@tool
extends Control

@export var target_theme: Theme = ThemeDB.get_project_theme()
@export var theme_texture: Texture2D:
	set(new):
		theme_texture = new
		theme_texture_img = theme_texture.get_image()
		apply_texture()

@export var bake_colors: bool:
	set(new):
		theme_texture_img = theme_texture.get_image()
		apply_texture()

var theme_texture_img: Image

enum {
		LABEL_COLOR = 16*0,
		LABEL_EMPHASIS_COLOR,
		LABEL_SUBTLE_COLOR,
		LABEL_DIM_COLOR,
		LABEL_ACCENT_COLOR,

		BUTTON_COLOR = 16*1,
		BUTTON_COLOR_INVERT,
		BUTTON_COLOR_DISABLED,

		MENU_BUTTON_COLOR = 16*2,
		MENU_BUTTON_COLOR_INVERT,

		TEXT_EDIT_CARET_COLOR = 16*3,
		TEXT_EDIT_CLEAR_BUTTON_COLOR,
		TEXT_EDIT_CLEAR_BUTTON_PRESSED_COLOR,
		TEXT_EDIT_FONT_COLOR,
		TEXT_EDIT_PLACEHOLDER_COLOR,
		TEXT_EDIT_SELECTED_COLOR,
		TEXT_EDIT_UNEDITABLED_COLOR,
		TEXT_EDIT_SELECTION_COLOR,

		SPIN_BOX_MODULATE = 16*4,
		SPIN_BOX_DISABLED_MODULATE,

		PROGRESS_BAR_COLOR = 16*5,
		PROGRESS_BAR_OUTLINE_COLOR,

		TAB_SELECTED_COLOR = 16*6,
		TAB_UNSELECTED_COLOR,
		TAB_DISABLED_COLOR,

		WINDOW_COLOR = 16*7,

		POPUP_COLOR = 16*8,
		POPUP_HOVER_COLOR,
		POPUP_DISABLED_COLOR,
		POPUP_SEPARATOR_COLOR,
		POPUP_LINE_SEPARATOR_COLOR,

		FOLDABLE_COLOR = 16*9,
		FOLDABLE_COLLAPSED_COLOR,
		FOLDABLE_HOVER_COLOR,

		SEPARATOR_COLOR = 16*10,
}

enum Flat {
	MENU_BUTTON_HOVER = 16*11,
	MENU_BUTTON_PRESSED,

	POPUP_MENU_HOVER = 16*12,

	SPIN_BOX_HOVER_PRESSED = 16*13,

	PANEL_HIGHLIGHTED = 16*14,
	PANEL_SELECTED,
}

func apply_texture():

	# ProjectSettings.set_setting("application/boot_splash/bg_color", get_color(Flat.BOOT_SPLASH_BG))

	target_theme.get_stylebox("hover", "MenuButton").bg_color = get_color(Flat.MENU_BUTTON_HOVER)
	target_theme.get_stylebox("hover_pressed", "MenuButton").bg_color = get_color(Flat.MENU_BUTTON_PRESSED)
	target_theme.get_stylebox("pressed", "MenuButton").bg_color = get_color(Flat.MENU_BUTTON_PRESSED)

	target_theme.get_stylebox("hover", "PopupMenu").bg_color = get_color(Flat.POPUP_MENU_HOVER)

	target_theme.get_stylebox("panel", "HighlightedPanel").bg_color = get_color(Flat.PANEL_HIGHLIGHTED)
	target_theme.get_stylebox("panel", "HighlightedPanelContainer").bg_color = get_color(Flat.PANEL_HIGHLIGHTED)

	target_theme.get_stylebox("panel", "SelectedPanel").bg_color = get_color(Flat.PANEL_SELECTED)
	target_theme.get_stylebox("panel", "SelectedPanelContainer").bg_color = get_color(Flat.PANEL_SELECTED)

	target_theme.get_stylebox("down_background_hovered", "SpinBox").bg_color = get_color(Flat.SPIN_BOX_HOVER_PRESSED)
	target_theme.get_stylebox("down_background_pressed", "SpinBox").bg_color = get_color(Flat.SPIN_BOX_HOVER_PRESSED)
	target_theme.get_stylebox("up_background_hovered", "SpinBox").bg_color = get_color(Flat.SPIN_BOX_HOVER_PRESSED)
	target_theme.get_stylebox("up_background_pressed", "SpinBox").bg_color = get_color(Flat.SPIN_BOX_HOVER_PRESSED)
	target_theme.get_stylebox("button_highlight", "TabBar").bg_color = get_color(Flat.SPIN_BOX_HOVER_PRESSED)

	target_theme.set_color("font_color", "Label", get_color(LABEL_COLOR))
	target_theme.set_color("font_color", "EmphasisLabel", get_color(LABEL_EMPHASIS_COLOR))
	target_theme.set_color("font_color", "SubtleLabel", get_color(LABEL_SUBTLE_COLOR))
	target_theme.set_color("font_color", "DimLabel", get_color(LABEL_DIM_COLOR))
	target_theme.set_color("font_color", "AccentLabel", get_color(LABEL_ACCENT_COLOR))


	target_theme.set_color("font_color", "Button", get_color(BUTTON_COLOR))
	target_theme.set_color("font_focus_color", "Button", get_color(BUTTON_COLOR))
	target_theme.set_color("font_hover_color", "Button", get_color(BUTTON_COLOR))

	target_theme.set_color("font_hover_pressed_color", "Button", get_color(BUTTON_COLOR_INVERT))
	target_theme.set_color("font_pressed_color", "Button", get_color(BUTTON_COLOR_INVERT))

	target_theme.set_color("font_disabled_color", "Button", get_color(BUTTON_COLOR_DISABLED))

	target_theme.set_color("icon_normal_color", "Button", get_color(BUTTON_COLOR))
	target_theme.set_color("icon_focus_color", "Button", get_color(BUTTON_COLOR))
	target_theme.set_color("icon_hover_color", "Button", get_color(BUTTON_COLOR))

	target_theme.set_color("icon_hover_pressed_color", "Button", get_color(BUTTON_COLOR_INVERT))
	target_theme.set_color("icon_pressed_color", "Button", get_color(BUTTON_COLOR_INVERT))

	target_theme.set_color("icon_disabled_color", "Button", get_color(BUTTON_COLOR_DISABLED))



	target_theme.set_color("font_color", "MenuButton", get_color(MENU_BUTTON_COLOR))
	target_theme.set_color("font_focus_color", "MenuButton", get_color(MENU_BUTTON_COLOR))
	target_theme.set_color("font_hover_color", "MenuButton", get_color(MENU_BUTTON_COLOR))

	target_theme.set_color("font_hover_pressed_color", "MenuButton", get_color(MENU_BUTTON_COLOR_INVERT))
	target_theme.set_color("font_pressed_color", "MenuButton", get_color(MENU_BUTTON_COLOR_INVERT))

	target_theme.set_color("icon_normal_color", "MenuButton", get_color(MENU_BUTTON_COLOR))
	target_theme.set_color("icon_focus_color", "MenuButton", get_color(MENU_BUTTON_COLOR))
	target_theme.set_color("icon_hover_color", "MenuButton", get_color(MENU_BUTTON_COLOR))

	target_theme.set_color("icon_hover_pressed_color", "MenuButton", get_color(MENU_BUTTON_COLOR_INVERT))
	target_theme.set_color("icon_pressed_color", "MenuButton", get_color(MENU_BUTTON_COLOR_INVERT))



	target_theme.set_color("caret_color", "LineEdit", get_color(TEXT_EDIT_CARET_COLOR))
	target_theme.set_color("clear_button_color", "LineEdit", get_color(TEXT_EDIT_CLEAR_BUTTON_COLOR))
	target_theme.set_color("clear_button_color_pressed", "LineEdit", get_color(TEXT_EDIT_CLEAR_BUTTON_PRESSED_COLOR))
	target_theme.set_color("font_color", "LineEdit", get_color(TEXT_EDIT_FONT_COLOR))
	target_theme.set_color("font_placeholder_color", "LineEdit", get_color(TEXT_EDIT_PLACEHOLDER_COLOR))
	target_theme.set_color("font_selected_color", "LineEdit", get_color(TEXT_EDIT_SELECTED_COLOR))
	target_theme.set_color("font_uneditable_color", "LineEdit", get_color(TEXT_EDIT_UNEDITABLED_COLOR))
	target_theme.set_color("selection_color", "LineEdit", get_color(TEXT_EDIT_SELECTION_COLOR))



	target_theme.set_color("caret_color", "TextEdit", get_color(TEXT_EDIT_CARET_COLOR))
	target_theme.set_color("font_color", "TextEdit", get_color(TEXT_EDIT_FONT_COLOR))
	target_theme.set_color("font_placeholder_color", "TextEdit", get_color(TEXT_EDIT_PLACEHOLDER_COLOR))
	target_theme.set_color("font_selected_color", "TextEdit", get_color(TEXT_EDIT_SELECTED_COLOR))
	target_theme.set_color("font_readonly_color", "TextEdit", get_color(TEXT_EDIT_UNEDITABLED_COLOR))
	target_theme.set_color("selection_color", "TextEdit", get_color(TEXT_EDIT_SELECTION_COLOR))



	target_theme.set_color("down_disabled_icon_modulate", "SpinBox", get_color(SPIN_BOX_DISABLED_MODULATE))
	target_theme.set_color("down_hover_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))
	target_theme.set_color("down_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))
	target_theme.set_color("down_pressed_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))

	target_theme.set_color("up_disabled_icon_modulate", "SpinBox", get_color(SPIN_BOX_DISABLED_MODULATE))
	target_theme.set_color("up_hover_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))
	target_theme.set_color("up_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))
	target_theme.set_color("up_pressed_icon_modulate", "SpinBox", get_color(SPIN_BOX_MODULATE))



	target_theme.set_color("font_color", "ProgressBar", get_color(PROGRESS_BAR_COLOR))
	target_theme.set_color("font_outline_color", "ProgressBar", get_color(PROGRESS_BAR_OUTLINE_COLOR))



	target_theme.set_color("font_selected_color", "TabBar", get_color(TAB_SELECTED_COLOR))
	target_theme.set_color("font_selected_color", "TabContainer", get_color(TAB_SELECTED_COLOR))
	target_theme.set_color("font_unselected_color", "TabBar", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("font_unselected_color", "TabContainer", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("font_hovered_color", "TabBar", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("font_hovered_color", "TabContainer", get_color(TAB_UNSELECTED_COLOR))

	target_theme.set_color("icon_selected_color", "TabBar", get_color(TAB_SELECTED_COLOR))
	target_theme.set_color("icon_selected_color", "TabContainer", get_color(TAB_SELECTED_COLOR))
	target_theme.set_color("icon_unselected_color", "TabBar", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("icon_unselected_color", "TabContainer", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("icon_hovered_color", "TabBar", get_color(TAB_UNSELECTED_COLOR))
	target_theme.set_color("icon_hovered_color", "TabContainer", get_color(TAB_UNSELECTED_COLOR))



	target_theme.set_color("title_color", "Window", get_color(WINDOW_COLOR))

	target_theme.set_color("font_color", "PopupMenu", get_color(POPUP_COLOR))
	target_theme.set_color("font_disabled_color", "PopupMenu", get_color(POPUP_DISABLED_COLOR))
	target_theme.set_color("font_hover_color", "PopupMenu", get_color(POPUP_HOVER_COLOR))
	target_theme.set_color("font_separator_color", "PopupMenu", get_color(POPUP_SEPARATOR_COLOR))
	target_theme.get_stylebox("separator", "PopupMenu").color = get_color(POPUP_LINE_SEPARATOR_COLOR)

	target_theme.set_color("font_color", "FoldableContainer", get_color(FOLDABLE_COLOR))
	target_theme.set_color("collapsed_font_color", "FoldableContainer", get_color(FOLDABLE_COLLAPSED_COLOR))
	target_theme.set_color("hover_font_color", "FoldableContainer", get_color(FOLDABLE_HOVER_COLOR))



	target_theme.get_stylebox("separator", "HSeparator").color = get_color(SEPARATOR_COLOR)
	target_theme.get_stylebox("separator", "VSeparator").color = get_color(SEPARATOR_COLOR)



	target_theme.emit_changed()

func get_color(index: int):
	return theme_texture_img.get_pixel((index%16)*2, floor(index/16.0)*2)
